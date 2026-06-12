select

    -- Keys
    t.task_instance_id,
    t.care_plan_activity_id,
    t.task_template_id,

    -- Center ✅ CRITICAL
    cpa.center_id,

    -- Task details
    t.task_name,
    t.task_category,

    -- Metrics
    t.duration_minutes,

    t.performed_at

from {{ ref('enterprise_silver_task') }} t

left join {{ ref('enterprise_silver_care_plan_activity') }} cpa
    on t.care_plan_activity_id = cpa.care_plan_activity_id