with source_data as (

    select
        appointment_id,
        participant_id,
        provider_id,
        center_id,
        scheduled_date as appointment_date,
        appointment_status,
        loaded_timestamp
    from {{ ref('enterprise_silver_appointment') }}

),

deduplicated as (

    select
        appointment_id,
        participant_id,
        provider_id,
        center_id,
        appointment_date,
        appointment_status,
        loaded_timestamp,

        row_number() over (
            partition by appointment_id
            order by
                loaded_timestamp desc,
                participant_id asc,
                provider_id asc,
                center_id asc
        ) as row_num

    from source_data

)

select
    appointment_id,
    participant_id,
    provider_id,
    center_id,
    appointment_date,
    appointment_status,

    case
        when appointment_status = 'COMPLETED' then 1
        else 0
    end as completed_flag,

    case
        when appointment_status = 'NO_SHOW' then 1
        else 0
    end as no_show_flag,

    loaded_timestamp

from deduplicated
where row_num = 1
