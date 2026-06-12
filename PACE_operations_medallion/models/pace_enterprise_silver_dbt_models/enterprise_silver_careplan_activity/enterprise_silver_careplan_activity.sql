/*
===============================================================================
Model       : enterprise_silver_care_plan_activity
Layer       : Silver
Description :
  Trusted care plan activity dataset providing linkage between participants,
  tasks, and centers.

Grain:
  One row per care_plan_activity_id
===============================================================================
*/

select

    -- Keys
    trim(upper(care_plan_activity_id)) as care_plan_activity_id,

    -- Critical for your use case
    trim(upper(center_id))             as center_id,

    -- Optional useful fields
    participant_id,
    activity_type,

    -- Metadata
    source_system,
    _loaded_at as loaded_at

from {{ ref('staging_careplan_activity') }}

where care_plan_activity_id is not null