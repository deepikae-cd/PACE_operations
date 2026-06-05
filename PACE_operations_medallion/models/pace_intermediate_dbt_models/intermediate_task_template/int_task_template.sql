/*
===============================================================================
Model       : int_task_template
Layer       : Intermediate
Description :
  Joins task instances with task templates to attach task category
  and task name to each task instance.

Grain:
  - One row per task_instance_id
===============================================================================
*/

select

    -- Keys
    ti.task_instance_id,
    ti.care_plan_activity_id,
    ti.task_template_id,

    -- Metrics
    ti.actual_duration_minutes,
    ti.performed_at,

    -- Template enrichment
    tt.task_name,
    tt.task_category,

    -- Metadata
    ti.source_system,
    ti.loaded_at

from {{ ref('staging_task_instance') }} ti

left join {{ ref('staging_task_template') }} tt
    on ti.task_template_id = tt.task_template_id