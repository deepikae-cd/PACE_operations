/*
  FACT_CAREGIVER_ACTIVITY
  ------------------------------------------------------------------------------
  Purpose:
    Gold fact combining caregiver assignments with task execution.

  Grain:
    One row per caregiver per care_plan_activity_id
------------------------------------------------------------------------------*/

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
        ca.care_plan_activity_id,   
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
    on ti.care_plan_activity_id = ca.care_plan_activity_id  