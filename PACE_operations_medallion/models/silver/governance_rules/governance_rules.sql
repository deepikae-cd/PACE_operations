with src as (

    select *
    from {{ source('bronze', 'governance_rules_raw') }}
    where rule_id        is not null
      and rule_name      is not null
      and status         is not null
      and effective_date is not null

)

select
    rule_id,
    upper(trim(rule_name))        as rule_name,
    upper(trim(rule_type))        as rule_type,
    trim(description)             as rule_description,
    effective_date,
    upper(trim(status))           as rule_status,
    created_ts                    as source_created_ts,
    current_timestamp()           as load_ts,
    'governance_rules'            as source_system,
    md5(concat(
        coalesce(cast(rule_id as string),       ''),
        coalesce(upper(trim(rule_name)),        ''),
        coalesce(upper(trim(rule_type)),        ''),
        coalesce(upper(trim(status)),           ''),
        coalesce(cast(effective_date as string),'')
    ))                            as record_hash

from src

qualify row_number() over (
    partition by rule_id
    order by created_ts desc
) = 1