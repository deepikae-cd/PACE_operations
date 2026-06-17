/*
===============================================================================
Model       : enterprise_silver_pace_center
Layer       : Silver
Description :
  Trusted PACE center dimension providing standardized center details.
  Used for joining operational data (tasks, care plans, etc.) to site-level
  analytics.

Grain:
  One row per pace_center_id

Inputs:
  - staging_pace_center

Key Features:
  - Standardized identifiers
  - Clean descriptive attributes
  - Ready for joins in analytics layer

===============================================================================
*/

select

    -- Keys
    pace_center_id as center_id,

    -- Descriptors
    center_name,
    region,

    -- Metadata
    loaded_at

from {{ ref('staging_pace_center') }}