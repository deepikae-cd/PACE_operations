/*
  FACT_CAREGIVER_ACTIVITY
  ──────────────────────────────────────────────────────────────────────────────
  Purpose:
    Consolidates caregiver activity by combining task execution, caregiver 
    assignments, and transportation details.

  Grain:
    One record per caregiver per task_instance

  Sources:
    - enterprise_silver_task_instance      (task execution)
    - enterprise_silver_caregiver_assignment (caregiver mapping)
    - enterprise_silver_transportation     (travel time)

  Key Metrics:
    - task_minutes        → caregiving duration
    - travel_minutes      → travel duration
    - total_time_minutes  → total effort

  Notes:
    - task_id is NOT used because it does not exist in task_instance
    - Safe joins + null handling applied
    - Ready for BI and analytics use cases

  Use Cases:
    - UC‑5: Caregiver transit vs caregiving
    - UC‑6: Task duration analysis
    - UC‑2: Capacity & workload planning
  ──────────────────────────────────────────────────────────────────────────────
*/

with task_instance as (

    -- Task execution (core activity)
    select
        ti.task_instance_id,
        ti.participant_id,
        ti.start_time,
        ti.end_time,

        -- Calculate caregiving duration
        datediff('minute', ti.start_time, ti.end_time) as task_minutes

    from {{ ref('enterprise_silver_task_instance') }} ti

),

caregiver_assignment as (

    -- Map caregiver to task instance
    select
        ca.task_instance_id,
        ca.caregiver_id
    from {{ ref('enterprise_silver_caregiver_assignment') }} ca

),

transport as (

    -- Travel time information
    select
        task_instance_id,
        travel_minutes
    from {{ ref('enterprise_silver_transportation') }}

)

select

    /* ─────────────── Keys ─────────────── */

    -- Surrogate key
    sha2(concat_ws('||',
        ca.caregiver_id,
        ti.task_instance_id
    )) as caregiver_activity_sk,

    -- Business keys
    ca.caregiver_id,
    ti.task_instance_id,
    ti.participant_id,


    /* ─────────────── Time Attributes ─────────────── */

    ti.start_time,
    ti.end_time,


    /* ─────────────── Metrics ─────────────── */

    ti.task_minutes,
    coalesce(tr.travel_minutes, 0) as travel_minutes,

    -- Total effort (care + travel)
    (ti.task_minutes + coalesce(tr.travel_minutes, 0)) as total_time_minutes,


    /* ─────────────── Flags (optional but useful) ─────────────── */

    -- No travel recorded
    (tr.travel_minutes is null) as is_travel_missing_flag,

    -- Long duration anomaly (example > 8 hours)
    (ti.task_minutes > 480) as is_long_task_flag,


    /* ─────────────── Metadata ─────────────── */

    current_timestamp() as dbt_updated_timestamp

from task_instance ti

-- Inner join ensures only assigned work is counted
join caregiver_assignment ca
    on ti.task_instance_id = ca.task_instance_id

-- Travel is optional → left join
left join transport tr
    on ti.task_instance_id = tr.task_instance_id