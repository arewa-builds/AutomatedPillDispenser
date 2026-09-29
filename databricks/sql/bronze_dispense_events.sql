-- Run once in the Databricks SQL editor, on the same warehouse the edge sink uses.
-- Defaults match DATABRICKS_CATALOG / DATABRICKS_SCHEMA / DATABRICKS_TABLE.

CREATE SCHEMA IF NOT EXISTS main.pill_dispenser;

CREATE TABLE IF NOT EXISTS main.pill_dispenser.bronze_dispense_events (
  event_ts TIMESTAMP,
  patient_id STRING,
  face_match_confidence DOUBLE,
  pills_detected INT,
  dispense_latency_ms INT,
  event_status STRING,
  hardware_source STRING,
  retry_count INT
);
