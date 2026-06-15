/*
  FACT_CAREGIVER_ACTIVITY
  ------------------------------------------------------------------------------
  Purpose:
    Gold fact table capturing caregiver activity based on task execution
    and caregiver assignment.

  Grain:
    One row per caregiver per task_instance

  Notes:
    - Uses only verified columns from Silver layer
    - Transportation excluded (can be added later safely)
    - Designed to compile without column errors
  ------------------------------------------------------------------------------
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
        ca.task_instance_id,
        ca.caregiver_id
    from {{ ref('enterprise_silver_caregiver_assignment') }} ca

)

select

    /* ---------- Keys ---------- */

    sha2(concat_ws('||',
        ca.caregiver_id,
        ti.task_instance_id
    )) as caregiver_activity_sk,

    ca.caregiver_id,
    ti.task_instance_id,
    ti.care_plan_activity_id,
    ti.center_id,

    /* ---------- Time ---------- */

    ti.performed_at,

    /* ---------- Task Info ---------- */

    ti.task_name,
    ti.task_category,

    /* ---------- Metrics ---------- */

    ti.duration_minutes as task_minutes,

    /* ---------- Flags ---------- */

    (ti.duration_minutes > 480) as is_long_task_flag,

    /* ---------- Metadata ---------- */

    current_timestamp() as dbt_updated_timestamp

from task_instance ti

join caregiver_assignment ca
    on ti.task_instance_id = ca.task_instance_id