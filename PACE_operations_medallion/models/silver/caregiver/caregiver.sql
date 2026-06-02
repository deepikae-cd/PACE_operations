select
    caregiver_id,
    upper(trim(caregiver_name))        as caregiver_name,
    regexp_replace(phone, '[^0-9]', '') as phone,
    upper(trim(specialization))        as specialization,
    upper(trim(status))                as caregiver_status,
    created_ts                         as source_created_ts,
    current_timestamp()                as load_ts,
    'caregiver'                        as source_system,
    md5(concat(
        coalesce(cast(caregiver_id as string),        ''),
        coalesce(upper(trim(caregiver_name)),         ''),
        coalesce(regexp_replace(phone, '[^0-9]', ''), ''),
        coalesce(upper(trim(specialization)),         ''),
        coalesce(upper(trim(status)),                 '')
    ))                                 as record_hash

from (
    select
        *,
        row_number() over (
            partition by caregiver_id
            order by created_ts desc
        ) as _rn
    from {{ source('bronze', 'caregiver_raw') }}
    where caregiver_id   is not null
      and caregiver_name is not null
      and status         is not null
)
where _rn = 1