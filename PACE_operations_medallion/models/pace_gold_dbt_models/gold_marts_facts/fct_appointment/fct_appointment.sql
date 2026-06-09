with base as (

    select
        appointment_id,
        participant_id,

        scheduled_date as appointment_date,
        appointment_status,
        _loaded_at 

    from {{ ref('enterprise_silver_appointment') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by appointment_id
               order by _loaded_at desc   -- ✅ FIXED
           ) as _rn
    from base

)

select
    appointment_id,
    participant_id,
    appointment_date,

    case 
        when appointment_status = 'COMPLETED' then 1
        else 0
    end as completed_flag

from deduplicated
where _rn = 1