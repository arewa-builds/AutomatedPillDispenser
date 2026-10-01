-- Rebuild Silver, Gold, and the dashboard tables from the Bronze rows already loaded.
-- The edge sink only inserts into pill_dispenser.bronze_dispense_events.
-- Paste this whole script after a demo dispense, then refresh the dashboard.
-- The 10 missed doses on 10–14 Aug stay in the adherence total.

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

CREATE OR REPLACE TABLE pill_dispenser.dashboard_daily AS
WITH bounds AS (
  SELECT greatest(
    DATE '2026-09-29',
    coalesce(max(CAST(event_ts AS DATE)), DATE '2026-09-29')
  ) AS last_day
  FROM pill_dispenser.bronze_dispense_events
  WHERE patient_id = 'patient_demo_001'
),
days AS (
  SELECT explode(sequence(DATE '2026-07-01', last_day, INTERVAL 1 DAY)) AS dose_date
  FROM bounds
),
taken AS (
  SELECT CAST(event_ts AS DATE) AS dose_date, count(*) AS event_count
  FROM pill_dispenser.bronze_dispense_events
  WHERE patient_id = 'patient_demo_001'
  GROUP BY CAST(event_ts AS DATE)
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

CREATE OR REPLACE TABLE pill_dispenser.dashboard_weekly AS
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

CREATE OR REPLACE TABLE pill_dispenser.dashboard_monthly AS
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
  event_ts_utc,
  event_status,
  pills_detected,
  time_drift_minutes
FROM pill_dispenser.silver_dispense_events
WHERE patient_id = 'patient_demo_001'
ORDER BY event_ts_utc DESC
LIMIT 5;

SELECT *
FROM pill_dispenser.gold_adherence_7d
WHERE patient_id = 'patient_demo_001';
