/*
===============================================================================
Model       : enterprise_silver_care_plan_activity
Layer       : Silver
Description :
  Trusted care plan activity dataset providing linkage between participants
  and care activities. Does NOT include center mapping.

Grain:
  One row per care_plan_activity_id
===============================================================================
*/

select

    -- Keys
    care_plan_activity_id,
    participant_id,

    -- Business fields
    program_year,
    activity_type,

    -- Metadata
    source_system,
    loaded_at

from {{ ref('staging_careplan_activity') }};