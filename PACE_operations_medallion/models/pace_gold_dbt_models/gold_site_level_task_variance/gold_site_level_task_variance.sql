/*
  GOLD_SITE_LEVEL_TASK_VARIANCE
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Analyze variation in task duration across centers and task types.
  ──────────────────────────────────────────────────────────────────────────────
*/

select
    -- Dimensions
    t.center_id,
    t.task_category as task_type,

    -- Metrics
    avg(t.duration_minutes) as avg_time,
    min(t.duration_minutes) as min_time,
    max(t.duration_minutes) as max_time

from {{ ref('enterprise_silver_task') }} t

group by
    t.center_id,
    t.task_category