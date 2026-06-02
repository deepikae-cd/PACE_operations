select
    appointment_id,
    participant_id,
    provider_id,
    appointment_date,
    upper(trim(service_type))                       as service_type,
    upper(trim(status))                             as appointment_status,
    created_ts                                      as source_created_ts,
    current_timestamp()                             as load_ts,
    'appointments'                                  as source_system,
    md5(concat(
        coalesce(cast(appointment_id   as string), ''),
        coalesce(cast(participant_id   as string), ''),
        coalesce(cast(provider_id      as string), ''),
        coalesce(cast(appointment_date as string), ''),
        coalesce(upper(trim(status)),              ''),
        coalesce(upper(trim(service_type)),        '')
    ))                                              as record_hash

from (
    select
        *,
        row_number() over (
            partition by appointment_id
            order by created_ts desc
        ) as _rn
    from {{ source('bronze', 'appointment_raw') }}
    where appointment_id   is not null
      and participant_id   is not null
      and provider_id      is not null
      and appointment_date is not null
)
where _rn = 1