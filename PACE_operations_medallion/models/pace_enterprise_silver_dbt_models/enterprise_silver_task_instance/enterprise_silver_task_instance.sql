/*
===============================================================================
Model       : enterprise_silver_task_instance
Layer       : Silver
Description :
  Trusted task execution dataset enriched with task template attributes
  and PACE center information for analytics.

Grain:
  One row per task_instance_id
===============================================================================
*/

select

    -- Keys
    ti.task_instance_id,
    ti.care_plan_activity_id,
    ti.task_template_id,

    -- ✅ FIXED: use correct column name from participant
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

left join {{ ref('enterprise_silver_careplan_activity') }} cpa
    on ti.care_plan_activity_id = cpa.care_plan_activity_id

left join {{ ref('enterprise_silver_participant') }} p
    on cpa.participant_id = p.participant_id
