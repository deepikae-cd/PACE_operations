with src as (

    select *
    from {{ source('bronze', 'participant_raw') }}
    where participant_id is not null
      and first_name     is not null
      and last_name      is not null

)

select
    participant_id,
    upper(trim(first_name))             as first_name,
    upper(trim(last_name))              as last_name,
    upper(trim(gender))                 as gender,
    lower(trim(email))                  as email,
    regexp_replace(phone, '[^0-9]', '')  as phone,
    upper(coalesce(trim(status), 'ACTIVE')) as participant_status,
    cast(created_ts as timestamp)       as source_created_ts,
    current_timestamp()                 as load_ts,
    'participant'                       as source_system,
    md5(concat(
        coalesce(cast(participant_id as string), ''),
        coalesce(upper(trim(first_name)),        ''),
        coalesce(upper(trim(last_name)),         ''),
        coalesce(upper(trim(gender)),            ''),
        coalesce(lower(trim(email)),             ''),
        coalesce(regexp_replace(phone, '[^0-9]', ''), ''),
        coalesce(upper(trim(status)),            '')
    ))                                  as record_hash

from src

qualify row_number() over (
    partition by participant_id
    order by created_ts desc
) = 1