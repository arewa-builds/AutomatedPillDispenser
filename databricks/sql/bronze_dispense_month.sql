-- One patient, thirty days, two doses a day (08:00 and 20:00).
-- Days 1–14 stay within a few minutes of the anchor. From day 15 the dose
-- slips later by about two minutes a day, which is the adherence signal.
-- About one dose in eleven is a miss. Re-running the INSERT does not duplicate rows.
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

CREATE OR REPLACE TABLE pill_dispenser.bronze_dispense_month AS
WITH days AS (
  SELECT explode(sequence(DATE '2026-08-31', DATE '2026-09-29', INTERVAL 1 DAY)) AS dose_day
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
    datediff(dose_day, DATE '2026-08-31') AS day_index,
    row_number() OVER (ORDER BY dose_day, anchor_hour) AS n
  FROM slots
)
SELECT
  dateadd(
    MINUTE,
    CASE
      WHEN day_index < 14 THEN 2 + (n % 4)
      ELSE 14 + (day_index - 14) * 2 + (n % 3)
    END,
    make_timestamp(year(dose_day), month(dose_day), day(dose_day), anchor_hour, 0, 0)
  ) AS event_ts,
  'patient_demo_001' AS patient_id,
  CASE
    WHEN n % 22 = 0 THEN 0.0
    WHEN n % 11 = 0 THEN 0.55
    ELSE round(0.82 + (n % 15) * 0.01, 4)
  END AS face_match_confidence,
  CASE WHEN n % 11 = 0 THEN 0 ELSE 1 END AS pills_detected,
  980 + (n % 8) * 70 AS dispense_latency_ms,
  CASE
    WHEN n % 11 = 0 THEN 'failure'
    WHEN n % 13 = 0 THEN 'retry'
    ELSE 'success'
  END AS event_status,
  'serial' AS hardware_source,
  CASE WHEN n % 11 = 0 OR n % 13 = 0 THEN 1 ELSE 0 END AS retry_count
FROM numbered;

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
WHERE NOT EXISTS (
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
  round(
    (
      unix_timestamp(event_ts) - unix_timestamp(
        make_timestamp(
          year(event_ts),
          month(event_ts),
          day(event_ts),
          CASE WHEN hour(event_ts) >= 5 AND hour(event_ts) < 17 THEN 8 ELSE 20 END,
          0,
          0
        )
      )
    ) / 60.0,
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
  round(sum(CASE WHEN is_success THEN 1 ELSE 0 END) / count(*), 4) AS adherence_rate_7d,
  round(avg(time_drift_minutes), 2) AS avg_time_drift_minutes,
  avg(time_drift_minutes) >= 15
    OR sum(CASE WHEN is_success THEN 1 ELSE 0 END) / count(*) < 0.85 AS high_adherence_risk
FROM pill_dispenser.silver_dispense_events
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

SELECT count(*) AS month_rows FROM pill_dispenser.bronze_dispense_month;

SELECT * FROM pill_dispenser.gold_adherence_7d WHERE patient_id = 'patient_demo_001';
