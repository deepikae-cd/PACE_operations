/*
===============================================================================
Model       : enterprise_silver_task
Layer       : Silver
Description :
  Trusted task execution dataset enriched with task template attributes
  and center information via participant mapping.

Grain:
  One row per task_instance_id
===============================================================================
*/

select

    -- Keys
    ti.task_instance_id,
    ti.care_plan_activity_id,
    ti.task_template_id,

    -- ✅ CORRECT center mapping
    p.center_id,

    -- Metrics
    ti.actual_duration_minutes as duration_minutes,

    -- Time
    ti.performed_at,

    -- Task enrichment
    ti.task_name,
    ti.task_category,

    -- Metadata
    ti.source_system,
    ti.loaded_at

from {{ ref('int_task_template') }} ti

-- Step 1: bring participant from care_plan_activity
left join {{ ref('enterprise_silver_careplan_activity') }} cpa
    on ti.care_plan_activity_id = cpa.care_plan_activity_id

-- ✅ Step 2: get center from participant (THIS IS THE FIX)
left join {{ ref('enterprise_silver_participant') }} p
    on cpa.participant_id = p.participant_id