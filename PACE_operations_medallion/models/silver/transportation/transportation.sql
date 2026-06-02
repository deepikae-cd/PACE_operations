with src as (

    select *
    from {{ source('bronze', 'transportation_raw') }}
    where transport_id     is not null
      and participant_id   is not null
      and pickup_location  is not null
      and destination      is not null
      and pickup_time      is not null

)

select
    transport_id                              as transportation_id,
    participant_id,
    upper(trim(pickup_location))              as pickup_location,
    upper(trim(destination))                  as destination,
    pickup_time,
    upper(coalesce(trim(status), 'UNKNOWN'))  as trip_status,
    created_ts                                as source_created_ts,
    current_timestamp()                       as load_ts,
    'transportation'                          as source_system,
    md5(concat(
        coalesce(cast(transport_id   as string),   ''),
        coalesce(cast(participant_id as string),   ''),
        coalesce(upper(trim(pickup_location)),     ''),
        coalesce(upper(trim(destination)),         ''),
        coalesce(cast(pickup_time    as string),   ''),
        coalesce(upper(trim(status)),              '')
    ))                                        as record_hash

from src

qualify row_number() over (
    partition by transport_id
    order by created_ts desc
) = 1