-- One patient, three months, two doses a day (08:00 and 20:00), 1 Jul–29 Sep 2026.
-- 182 scheduled doses. 172 are taken. 10 are missed: both doses on 10–14 Aug 2026.
-- Those 10 stay in bronze_dispense_month and are not copied into bronze_dispense_events,
-- so a count of events falls to 4 in the week of 10 Aug and to 52 in August.
-- A daily Count chart skips dates with no rows. dashboard_daily.event_count is 0 on
-- 10–14 Aug, and missed_count is 2 on each of those days (10 misses).
-- Most taken doses land 1–6 minutes after the anchor. A few are later, and a few are retries.
-- The DELETE removes the previous synthetic rows for this patient, then the INSERT
-- loads the taken set. Live rows that are not in bronze_dispense_month stay put.
--
-- Paste the whole script into the Databricks SQL editor.
-- Published dashboard:
-- https://dbc-841e48ce-abec.cloud.databricks.com/dashboardsv3/01f1bc66f608184bb87e728ccb7f308e/published?o=7474657233579766

CREATE SCHEMA IF NOT EXISTS pill_dispenser;

CREATE TABLE IF NOT EXISTS pill_dispenser.bronze_dispense_events (
  event_ts TIMESTAMP,
  patient_id STRING,
  face_match_confidence DOUBLE,
  pills_detected INT,
  dispense_latency_ms INT,
  event_status STRING,
  hardware_source STRING,
  retry_count INT
);

DELETE FROM pill_dispenser.bronze_dispense_events
WHERE patient_id = 'patient_demo_001'
  AND event_ts IN (SELECT event_ts FROM pill_dispenser.bronze_dispense_month);

CREATE OR REPLACE TABLE pill_dispenser.bronze_dispense_month AS
WITH days AS (
  SELECT explode(sequence(DATE '2026-07-01', DATE '2026-09-29', INTERVAL 1 DAY)) AS dose_day
),
slots AS (
  SELECT dose_day, 8 AS anchor_hour FROM days
  UNION ALL
  SELECT dose_day, 20 AS anchor_hour FROM days
),
numbered AS (
  SELECT
    dose_day,
    anchor_hour,
    datediff(dose_day, DATE '2026-07-01') AS day_index,
    row_number() OVER (ORDER BY dose_day, anchor_hour) AS n
  FROM slots
),
flagged AS (
  SELECT
    dose_day,
    anchor_hour,
    day_index,
    n,
    dose_day BETWEEN DATE '2026-08-10' AND DATE '2026-08-14' AS missed
  FROM numbered
)
SELECT
  dateadd(
    MINUTE,
    CASE
      WHEN day_index % 17 = 0 THEN 18 + (n % 12)
      WHEN day_index >= 75 THEN 6 + (n % 8)
      ELSE 1 + (n % 6)
    END,
    make_timestamp(year(dose_day), month(dose_day), day(dose_day), anchor_hour, 0, 0)
  ) AS event_ts,
  'patient_demo_001' AS patient_id,
  CASE
    WHEN missed AND n % 2 = 0 THEN 0.0
    WHEN missed THEN 0.55
    ELSE round(0.82 + (n % 15) * 0.01, 4)
  END AS face_match_confidence,
  CASE WHEN missed THEN 0 ELSE 1 END AS pills_detected,
  980 + (n % 8) * 70 AS dispense_latency_ms,
  CASE
    WHEN missed THEN 'failure'
    WHEN n % 17 = 0 THEN 'retry'
    ELSE 'success'
  END AS event_status,
  'serial' AS hardware_source,
  CASE WHEN missed OR n % 17 = 0 THEN 1 ELSE 0 END AS retry_count
FROM flagged;

INSERT INTO pill_dispenser.bronze_dispense_events (
  event_ts,
  patient_id,
  face_match_confidence,
  pills_detected,
  dispense_latency_ms,
  event_status,
  hardware_source,
  retry_count
)
SELECT
  event_ts,
  patient_id,
  face_match_confidence,
  pills_detected,
  dispense_latency_ms,
  event_status,
  hardware_source,
  retry_count
FROM pill_dispenser.bronze_dispense_month AS month_rows
WHERE month_rows.event_status <> 'failure'
  AND NOT EXISTS (
  SELECT 1
  FROM pill_dispenser.bronze_dispense_events AS existing
  WHERE existing.patient_id = month_rows.patient_id
    AND existing.event_ts = month_rows.event_ts
);

CREATE OR REPLACE TABLE pill_dispenser.silver_dispense_events AS
SELECT
  event_ts AS event_ts_utc,
  patient_id,
  face_match_confidence,
  pills_detected,
  dispense_latency_ms,
  event_status,
  hardware_source,
  retry_count,
  event_status IN ('success', 'retry') AND pills_detected >= 1 AS is_success,
  CASE
    WHEN hour(event_ts) >= 5 AND hour(event_ts) < 11 THEN 'morning'
    WHEN hour(event_ts) >= 11 AND hour(event_ts) < 17 THEN 'midday'
    WHEN hour(event_ts) >= 17 AND hour(event_ts) < 23 THEN 'evening'
    ELSE 'night'
  END AS scheduled_window,
  -- Minutes from the 08:00 or 20:00 anchor. Late and early are both a positive drift.
  round(
    abs(
      timestampdiff(
        MINUTE,
        make_timestamp(
          year(event_ts),
          month(event_ts),
          day(event_ts),
          CASE WHEN hour(event_ts) >= 5 AND hour(event_ts) < 17 THEN 8 ELSE 20 END,
          0,
          0
        ),
        event_ts
      )
    ),
    2
  ) AS time_drift_minutes
FROM (
  SELECT *
  FROM pill_dispenser.bronze_dispense_events
  QUALIFY row_number() OVER (
    PARTITION BY patient_id, event_ts, pills_detected
    ORDER BY event_ts
  ) = 1
);

CREATE OR REPLACE TABLE pill_dispenser.gold_adherence_7d AS
SELECT
  patient_id,
  count(*) AS events,
  sum(CASE WHEN is_success THEN 1 ELSE 0 END) AS success_events,
  count(*) - sum(CASE WHEN is_success THEN 1 ELSE 0 END) AS missed_events,
  round(sum(CASE WHEN is_success THEN 1 ELSE 0 END) / count(*), 4) AS adherence_rate_7d,
  round(avg(time_drift_minutes), 2) AS avg_time_drift_minutes,
  avg(time_drift_minutes) >= 15
    OR sum(CASE WHEN is_success THEN 1 ELSE 0 END) / count(*) < 0.85 AS high_adherence_risk
FROM (
  SELECT patient_id, is_success, time_drift_minutes
  FROM pill_dispenser.silver_dispense_events
  UNION ALL
  SELECT patient_id, false AS is_success, CAST(NULL AS DOUBLE) AS time_drift_minutes
  FROM pill_dispenser.bronze_dispense_month
  WHERE event_status = 'failure'
)
GROUP BY patient_id;

CREATE OR REPLACE VIEW pill_dispenser.dashboard_doses AS
SELECT
  patient_id,
  event_ts_utc,
  CAST(event_ts_utc AS DATE) AS dose_date,
  scheduled_window,
  face_match_confidence,
  pills_detected,
  event_status,
  is_success,
  time_drift_minutes,
  dispense_latency_ms
FROM pill_dispenser.silver_dispense_events
WHERE patient_id = 'patient_demo_001';

-- One row per calendar day, including the five days with no dispense.
-- Plot Sum of event_count (0 on 10–14 Aug) or Sum of missed_count (2 on those days).
CREATE OR REPLACE VIEW pill_dispenser.dashboard_daily AS
WITH days AS (
  SELECT explode(sequence(DATE '2026-07-01', DATE '2026-09-29', INTERVAL 1 DAY)) AS dose_date
),
taken AS (
  SELECT dose_date, count(*) AS event_count
  FROM pill_dispenser.dashboard_doses
  GROUP BY dose_date
),
missed AS (
  SELECT CAST(event_ts AS DATE) AS dose_date, count(*) AS missed_count
  FROM pill_dispenser.bronze_dispense_month
  WHERE event_status = 'failure'
  GROUP BY CAST(event_ts AS DATE)
)
SELECT
  d.dose_date,
  coalesce(taken.event_count, 0) AS event_count,
  coalesce(missed.missed_count, 0) AS missed_count
FROM days AS d
LEFT JOIN taken ON taken.dose_date = d.dose_date
LEFT JOIN missed ON missed.dose_date = d.dose_date;

CREATE OR REPLACE VIEW pill_dispenser.dashboard_weekly AS
SELECT
  week_start,
  sum(event_count) AS event_count,
  sum(missed_count) AS missed_count
FROM (
  SELECT
    CAST(date_trunc('WEEK', dose_date) AS DATE) AS week_start,
    event_count,
    missed_count
  FROM pill_dispenser.dashboard_daily
)
GROUP BY week_start;

CREATE OR REPLACE VIEW pill_dispenser.dashboard_monthly AS
SELECT
  month_start,
  sum(event_count) AS event_count,
  sum(missed_count) AS missed_count
FROM (
  SELECT
    CAST(date_trunc('MONTH', dose_date) AS DATE) AS month_start,
    event_count,
    missed_count
  FROM pill_dispenser.dashboard_daily
)
GROUP BY month_start;

SELECT
  count(*) AS scheduled_rows,
  sum(CASE WHEN event_status = 'failure' THEN 1 ELSE 0 END) AS missed_rows
FROM pill_dispenser.bronze_dispense_month;

SELECT week_start, event_count, missed_count
FROM pill_dispenser.dashboard_weekly
WHERE missed_count > 0;

SELECT * FROM pill_dispenser.gold_adherence_7d WHERE patient_id = 'patient_demo_001';
