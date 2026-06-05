/*
===============================================================================
Model       : staging_care_plan_activity
Layer       : Staging
Description :
  Staging model for care plan activity data. Cleans and standardizes
  raw records from the bronze layer while maintaining a 1:1 mapping
  with the source data.

Source:
  - {{ source('bronze_care_plan', 'RAW_CARE_PLAN_ACTIVITY') }}

Key Features:
  - Normalizes identifiers using TRIM + UPPER
  - Casts program_year to integer for analytical consistency
  - Preserves business attributes (activity_type)
  - Standardizes source metadata fields
  - Adds staging timestamp (stg_loaded_at) for lineage tracking

Notes:
  - No deduplication or aggregation performed at staging layer
  - Designed to feed silver models for trusted transformations

Materialization:
  - view (configured in schema.yml)

===============================================================================
*/

select

    -- ─────────────────────────────────────────────
    -- Keys (normalized identifiers)
    -- ─────────────────────────────────────────────
    trim(upper(care_plan_activity_id)) as care_plan_activity_id,
    trim(upper(participant_id))        as participant_id,

    -- ─────────────────────────────────────────────
    -- Business fields (standardized for downstream use)
    -- ─────────────────────────────────────────────
    cast(program_year as integer)      as program_year,
    trim(activity_type)                as activity_type,

    -- ─────────────────────────────────────────────
    -- Source metadata (for lineage and traceability)
    -- ─────────────────────────────────────────────
    upper(trim(source_system))         as source_system,
    _loaded_at                         as loaded_at,
    _source_file                       as source_file,

    -- ─────────────────────────────────────────────
    -- Audit / Processing timestamp
    -- ─────────────────────────────────────────────
    current_timestamp                  as stg_loaded_at

from {{ source('bronze_care_plan', 'RAW_CARE_PLAN_ACTIVITY') }}