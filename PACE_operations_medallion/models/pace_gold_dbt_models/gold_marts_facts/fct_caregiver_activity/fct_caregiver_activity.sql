/*
  FACT_CAREGIVER_ACTIVITY
  ──────────────────────────────────────────────────────────────────────────────
  Purpose:
    Consolidates caregiver activity using task execution, caregiver assignment,
    and transportation data.

  Grain:
    One record per caregiver per task_instance

  Sources:
    - enterprise_silver_task_instance
    - enterprise_silver_caregiver_assignment
    - enterprise_silver_transportation

  Notes:
    - Uses duration_minutes (already computed in Silver)
    - Uses performed_at as event timestamp
    - No participant_id directly available in this layer
  ──────────────────────────────────────────────────────────────────────────────
*/

with task_instance as (

    select
        ti.task_instance_id,
        ti.care_plan_activity_id,
        ti.center_id,
        ti.duration_minutes,
        ti.performed_at,
        ti.task_name,
        ti.task_category

    from {{ ref('enterprise_silver_task_instance') }} ti

),

caregiver_assignment as (

    select
        task_instance_id,
        caregiver_id
    from {{ ref('enterprise_silver_caregiver_assignment') }}

),

transport as (

    select
        task_instance_id,
        travel_minutes
    from {{ ref('enterprise_silver_transportation') }}

)

select

    /* ───────── Keys ───────── */

    sha2(concat_ws('||',
        ca.caregiver_id,
        ti.task_instance_id
    )) as caregiver_activity_sk,

    ca.caregiver_id,
    ti.task_instance_id,
    ti.care_plan_activity_id,
    ti.center_id,

    /* ───────── Time ───────── */

    ti.performed_at,

    /* ───────── Task context ───────── */

    ti.task_name,
    ti.task_category,

    /* ───────── Metrics ───────── */

    ti.duration_minutes as task_minutes,
    coalesce(tr.travel_minutes, 0) as travel_minutes,

    (ti.duration_minutes + coalesce(tr.travel_minutes, 0)) as total_time_minutes,

    /* ───────── Flags ───────── */

    (tr.travel_minutes is null) as is_travel_missing_flag,
    (ti.duration_minutes > 480) as is_long_task_flag,

    /* ───────── Metadata ───────── */

    current_timestamp() as dbt_updated_timestamp

from task_instance ti

join caregiver_assignment ca
    on ti.task_instance_id = ca.task_instance_id

left join transport tr
    on ti.task_instance_id = tr.task_instance_id