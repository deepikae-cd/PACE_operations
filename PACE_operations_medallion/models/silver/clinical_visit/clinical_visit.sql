with src as (

    select *
    from {{ source('bronze', 'clinical_visit_raw') }}
    where visit_id       is not null
      and participant_id is not null
      and provider_id    is not null
      and visit_date     is not null

)

select
    visit_id,
    participant_id,
    provider_id,
    visit_date,
    upper(trim(service_type))                        as service_type,
    upper(trim(diagnosis_code))                      as diagnosis_code,
    upper(coalesce(trim(status), 'COMPLETED'))        as visit_status,
    created_ts                                       as source_created_ts,
    current_timestamp()                              as load_ts,
    'clinical_visit'                                 as source_system,
    md5(concat(
        coalesce(cast(visit_id       as string), ''),
        coalesce(cast(participant_id as string), ''),
        coalesce(cast(provider_id    as string), ''),
        coalesce(cast(visit_date     as string), ''),
        coalesce(upper(trim(service_type)),      ''),
        coalesce(upper(trim(diagnosis_code)),    ''),
        coalesce(upper(trim(status)),            '')
    ))                                               as record_hash

from src

qualify row_number() over (
    partition by visit_id
    order by created_ts desc
) = 1