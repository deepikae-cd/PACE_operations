/*
  ENTERPRISE_SILVER_TASK_INSTANCE
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Trusted task execution dataset enriched with task template attributes
            and ready for analytics.

  Grain   : One row per task_instance_id
  ──────────────────────────────────────────────────────────────────────────────
*/

select

    -- Keys
    ti.task_instance_id,
    ti.care_plan_activity_id,
    ti.task_template_id,

    -- Metrics
    ti.actual_duration_minutes as duration_minutes,

    -- Time
    ti.performed_at,

    -- Task enrichment
    tt.task_name,
    tt.task_category,

    -- Metadata
    ti.source_system,
    ti.loaded_at

from {{ ref('int_task_template') }} ti