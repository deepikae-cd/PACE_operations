{{ config(
    materialized = 'incremental',
    unique_key = 'appointment_id'
) }}

with base as (

    select
        appointment_id,
        participant_id,
        scheduled_date as appointment_date,
        appointment_status,
        loaded_timestamp
    from {{ ref('enterprise_silver_appointment') }}

    {% if is_incremental() %}
        where loaded_timestamp > (
            select coalesce(max(loaded_at), '1900-01-01')
            from {{ this }}
        )
    {% endif %}

),

deduplicated as (

    select
        appointment_id,
        participant_id,
        appointment_date,
        appointment_status,
        loaded_timestamp,
        row_number() over (
            partition by appointment_id
            order by loaded_timestamp desc, participant_id
        ) as _rn
    from base

)

select
    appointment_id,
    participant_id,
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

    loaded_timestamp as loaded_at

from deduplicated
where _rn = 1