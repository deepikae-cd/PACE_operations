with src as (

    select *
    from {{ source('bronze', 'provider_raw') }}
    where provider_id   is not null
      and provider_name is not null
      and status        is not null

)

select
    provider_id,
    upper(trim(provider_name))           as provider_name,
    upper(trim(specialty))               as specialty,
    upper(trim(license_number))          as license_number,
    regexp_replace(phone, '[^0-9]', '')   as phone,
    upper(coalesce(trim(status), 'ACTIVE')) as provider_status,
    created_ts                           as source_created_ts,
    current_timestamp()                  as load_ts,
    'provider'                           as source_system,
    md5(concat(
        coalesce(cast(provider_id as string), ''),
        coalesce(upper(trim(provider_name)),  ''),
        coalesce(upper(trim(specialty)),      ''),
        coalesce(upper(trim(license_number)), ''),
        coalesce(regexp_replace(phone, '[^0-9]', ''), ''),
        coalesce(upper(trim(status)),         '')
    ))                                   as record_hash

from src

qualify row_number() over (
    partition by provider_id
    order by created_ts desc
) = 1