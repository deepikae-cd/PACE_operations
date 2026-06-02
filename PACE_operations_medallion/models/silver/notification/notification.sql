with src as (

    select *
    from {{ source('bronze', 'notification_raw') }}
    where notification_id is not null
      and participant_id  is not null
      and status          is not null
      and channel         is not null

)

select
    notification_id,
    participant_id,
    upper(trim(notification_type))  as notification_type,
    upper(trim(channel))            as notification_channel,
    upper(trim(status))             as notification_status,
    created_ts                      as source_created_ts,
    current_timestamp()             as load_ts,
    'notification'                  as source_system,
    md5(concat(
        coalesce(cast(notification_id as string), ''),
        coalesce(cast(participant_id  as string), ''),
        coalesce(upper(trim(notification_type)),  ''),
        coalesce(upper(trim(channel)),            ''),
        coalesce(upper(trim(status)),             '')
    ))                              as record_hash

from src

qualify row_number() over (
    partition by notification_id
    order by created_ts desc
) = 1