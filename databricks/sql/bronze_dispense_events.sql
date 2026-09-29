-- Run once in the Databricks SQL editor, on the same warehouse the edge sink uses.
-- The table is pill_dispenser.bronze_dispense_events in the warehouse's current
-- catalog. Leave DATABRICKS_CATALOG unset unless this schema is not in that catalog.

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
