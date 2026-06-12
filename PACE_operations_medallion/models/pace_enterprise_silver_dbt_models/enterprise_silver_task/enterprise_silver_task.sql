/*
===============================================================================
Model       : enterprise_silver_task
Layer       : Silver
Description :
  Integrated task execution dataset enriched with task template and
  center information. Serves as the canonical source for task analytics.

Grain:
  One row per task_instance_id

===============================================================================
*/

with task as (

    select * from {{ ref('staging_task_instance') }}

),

template as (

    select * from {{ ref('staging_task_template') }}

),

care_plan as (

    select * from {{ ref('enterprise_silver_careplan_activity') }}

)

select

    -- Keys
    t.task_instance_id,
    t.care_plan_activity_id,
    t.task_template_id,

    -- ✅ Center (critical for Gold)
    cpa.center_id,

    -- Task enrichment
    tt.task_name,
    tt.task_category,

    -- Metrics
    t.actual_duration_minutes as duration_minutes,

    -- Time
    t.performed_at

from task t

left join template tt
    on t.task_template_id = tt.task_template_id

left join care_plan cpa
    on t.care_plan_activity_id = cpa.care_plan_activity_id