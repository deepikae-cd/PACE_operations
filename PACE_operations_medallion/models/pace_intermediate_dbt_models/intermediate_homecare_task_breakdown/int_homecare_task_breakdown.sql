/*
===============================================================================
Model       : int_home_care_task_breakdown
Layer       : Intermediate
Description :
  Combines care plan, task instance, and task template to create
  a unified dataset for analyzing home care activity distribution.

Grain:
  - One row per task_instance

Use Case:
  - Enables calculation of % of time spent on medication assistance
===============================================================================
*/

select

    ti.task_instance_id,
    ti.care_plan_activity_id,
    ti.task_template_id,

    -- ─────────────────────────────────────────────
    -- Metrics (CRITICAL)
    -- ─────────────────────────────────────────────
    ti.actual_duration_minutes,

    -- ─────────────────────────────────────────────
    -- Time + Context
    -- ─────────────────────────────────────────────
    ti.performed_at,
    cp.program_year,
    cp.participant_id,

    -- ─────────────────────────────────────────────
    -- Classification (CRITICAL FIELD)
    -- ─────────────────────────────────────────────
    tt.task_category,
    tt.task_name,

    -- ─────────────────────────────────────────────
    -- Metadata
    -- ─────────────────────────────────────────────
    ti.source_system,
    ti.loaded_at

from {{ ref('staging_task_instance') }} ti

left join {{ ref('staging_care_plan_activity') }} cp
    on ti.care_plan_activity_id = cp.care_plan_activity_id

left join {{ ref('staging_task_template') }} tt
    on ti.task_template_id = tt.task_template_id