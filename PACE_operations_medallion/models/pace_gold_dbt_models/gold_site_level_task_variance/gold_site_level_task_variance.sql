/*
  GOLD_SITE_LEVEL_TASK_VARIANCE
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Analyze variation in task duration across centers and task types.
  ──────────────────────────────────────────────────────────────────────────────
*/

select
    -- Dimensions
    c.center_id,
    t.task_category as task_type,

    -- Metrics
    avg(t.duration_minutes) as avg_time,
    min(t.duration_minutes) as min_time,
    max(t.duration_minutes) as max_time

from {{ ref('enterprise_silver_task') }} t

join {{ ref('enterprise_silver_careplan_activity') }} cpa
    on t.care_plan_activity_id = cpa.care_plan_activity_id

join {{ ref('enterprise_silver_pace_center') }} c
    on cpa.center_id = c.center_id

group by
    c.center_id,
    t.task_category