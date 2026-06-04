/*
  ENTER Purpose : Cleanse, deduplicate, and standardise governance rules.  ENTERPRISE_SILVER_GOVERNANCE
            Normalises category, enforcement level, and expiry flags.
            Removes unsafe timestamp casting for Snowflake compatibility.
  ──────────────────────────────────────────────────────────────────────────────
*/

with

source as (

    select * from {{ source('bronze_governance', 'RAW_GOVERNANCE_RULES') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by rule_id
               order by _loaded_at desc
           ) as _rn
    from source
    where rule_id   is not null
      and rule_name is not null

),

cleaned as (

    select
        -- Keys
        sha2(concat_ws('||', rule_id, cast(_loaded_at as varchar))) as rule_sk,
        trim(upper(rule_id))  as rule_id,
        trim(rule_name)       as rule_name,

        -- Category
        case
            when upper(trim(rule_category)) in
                ('HIPAA','CMS','STATE_REGULATION','INTERNAL')
            then upper(trim(rule_category))
            when rule_category is null then 'UNKNOWN'
            else 'OTHER'
        end as rule_category,

        trim(rule_subcategory) as rule_subcategory,
        trim(rule_description) as rule_description,
        trim(rule_logic)       as rule_logic,

        upper(trim(applies_to_domain)) as applies_to_domain,
        try_cast(effective_date as date) as effective_date,
        try_cast(expiry_date as date)    as expiry_date,

        -- Flags
        coalesce(is_active, false) as is_active_flag,
        (try_cast(expiry_date as date) < current_date()) as is_expired_flag,

        -- Enforcement
        case
            when upper(trim(enforcement_level)) in
                ('HARD_BLOCK','SOFT_WARNING','AUDIT_ONLY')
            then upper(trim(enforcement_level))
            else 'UNKNOWN'
        end as enforcement_level,

        trim(regulatory_reference) as regulatory_reference,
        trim(created_by)           as created_by,
        created_at as created_timestamp,
        trim(last_updated_by) as last_updated_by,
        last_updated_at as last_updated_timestamp,

        -- Metadata
        upper(trim(source_system)) as source_system,
        _loaded_at as loaded_timestamp,
        current_timestamp() as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned
  ──────────────────────────────────────────────────────────────────────────────

