/*
===============================================================================
Model       : enterprise_silver_pace_center
Layer       : Silver
Description :
  Trusted PACE center dimension providing standardized and cleansed
  center-level attributes. This model serves as the authoritative source
  for PACE center metadata and is used to join operational fact tables
  (e.g., tasks, care plans, notifications) for site-level analytics.

Grain:
  One row per pace_center_id

Inputs:
  - staging_pace_center

Key Features:
  - Standardized and normalized center identifiers
  - Clean, trimmed descriptive attributes
  - Consistent join key (center_id) for downstream models
  - Lightweight dimension suitable for enrichment in Gold layer

Business Use Cases:
  - Center-level performance reporting
  - Regional analytics and segmentation
  - Capacity and utilization analysis
  - Linking operational data to physical locations

===============================================================================
*/

with source as (

    select *
    from {{ ref('staging_pace_center') }}

),

final as (

    select

        -- 🔑 Surrogate / Join Key (standardized across models)
        pace_center_id as center_id,

        -- 🏥 Descriptive Attributes
        center_name,
        region,

        -- 🧾 Metadata
        loaded_at,

        -- Audit column (recommended for Silver consistency)
        current_timestamp() as dbt_updated_timestamp

    from source

)

select * from final