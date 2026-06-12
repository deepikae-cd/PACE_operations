/*
  INT_TASK_INSTANCE_CLEANED
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Clean task duration and ensure only valid records are used for
            downstream analytics.
  ──────────────────────────────────────────────────────────────────────────────
*/

select
    task_instance_id,
    care_plan_activity_id,
    task_template_id,
    actual_duration_minutes,
    performed_at

from {{ ref('staging_task_instance') }}

where actual_duration_minutes is not null
  and actual_duration_minutes >= 0