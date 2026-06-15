/*
  FACT_CAREGIVER_ACTIVITY
  ------------------------------------------------------------------------------
  Purpose:
    Gold fact table combining caregiver assignments with task execution.

  Grain:
    One row per caregiver per task_instance

  Join Logic:
    task_instance → care_plan_activity → participant → caregiver_assignment
-------------------------------------------------------------------------------*/

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

care_plan_activity as (

    select
        care_plan_activity_id,
        participant_id
    from {{ ref('enterprise_silver_careplan_activity') }}

),

caregiver_assignment as (

    select
        caregiver_id,
        participant_id,
        is_active_flag
    from {{ ref('enterprise_silver_caregiver_assignment') }}

)

select

    /* ---------- Keys ---------- */

    sha2(concat_ws('||',
        ca.caregiver_id,
        ti.task_instance_id
    )) as caregiver_activity_sk,

    ca.caregiver_id,
    ti.task_instance_id,
    ti.center_id,

    /* ---------- Time ---------- */

    ti.performed_at,

    /* ---------- Task ---------- */

    ti.task_name,
    ti.task_category,

    /* ---------- Metrics ---------- */

    ti.duration_minutes as task_minutes,

    /* ---------- Flags ---------- */

    ca.is_active_flag,
    (ti.duration_minutes > 480) as is_long_task_flag,

    /* ---------- Metadata ---------- */

    current_timestamp() as dbt_updated_timestamp

from task_instance ti

-- Step 1: get participant
join care_plan_activity cpa
    on ti.care_plan_activity_id = cpa.care_plan_activity_id

-- Step 2: map to caregiver
join caregiver_assignment ca
    on cpa.participant_id = ca.participant_id
