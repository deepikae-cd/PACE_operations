with tasks as (

    select
        ti.task_instance_id,
        ti.task_id,
        ti.participant_id,
        ti.start_time,
        ti.end_time,
        datediff('minute', ti.start_time, ti.end_time) as task_minutes
    from {{ ref('enterprise_silver_task_instance') }} ti

),

caregiver as (

    select
        ca.task_instance_id,
        ca.caregiver_id
    from {{ ref('enterprise_silver_caregiver_assignment') }} ca

),

transport as (

    select
        task_instance_id,
        travel_minutes
    from {{ ref('enterprise_silver_transportation') }}

)

select
    c.caregiver_id,
    t.task_instance_id,
    t.participant_id,
    t.start_time,
    t.end_time,
    t.task_minutes,
    coalesce(tr.travel_minutes, 0) as travel_minutes
from tasks t

