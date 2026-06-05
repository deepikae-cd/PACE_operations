/*
===============================================================================
Model       : staging_task_instance
Layer       : Staging
Description :
  Cleans and standardizes raw task instance data from the bronze layer.
  Converts string-based numeric and timestamp fields into proper types,
  normalizes identifiers, and preserves ingestion metadata.

Source:
  - {{ source('bronze_task', 'RAW_TASK_INSTANCE') }}

Key Features:
  - Normalizes IDs using TRIM + UPPER
  - Converts ACTUAL_DURATION_MINUTES to integer
  - Converts PERFORMED_AT to timestamp
  - Standardizes source metadata fields
  - Adds staging timestamp for lineage tracking

Notes:
  - No deduplication performed in staging
  - Invalid numeric/timestamp values safely handled as NULL

===============================================================================
*/

select

    -- ─────────────────────────────────────────────
    -- Keys (normalized identifiers)
    -- ─────────────────────────────────────────────
    trim(upper(task_instance_id))      as task_instance_id,
    trim(upper(care_plan_activity_id)) as care_plan_activity_id,
    trim(upper(task_template_id))      as task_template_id,

    -- ─────────────────────────────────────────────
    -- Business fields (safe type casting)
    -- ─────────────────────────────────────────────
    try_cast(actual_duration_minutes as integer) as actual_duration_minutes,

    try_cast(performed_at as timestamp)          as performed_at,

    -- ─────────────────────────────────────────────
    -- Source metadata
    -- ─────────────────────────────────────────────
    upper(trim(source_system))         as source_system,
    _loaded_at                         as loaded_at,
    _source_file                       as source_file,

    -- ─────────────────────────────────────────────
    -- Audit / processing timestamp
    -- ─────────────────────────────────────────────
    current_timestamp                  as stg_loaded_at

from {{ source('bronze_task', 'RAW_TASK_INSTANCE') }}