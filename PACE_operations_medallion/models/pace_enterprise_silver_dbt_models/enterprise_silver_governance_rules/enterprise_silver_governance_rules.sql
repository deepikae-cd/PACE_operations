/*
  ENTERPRISE_SILVER_GOVERNANCE_RULES
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('staging_governance_rules') }}
  Purpose : Cleanse, deduplicate and enrich governance rule records.
            Adds surrogate key, standardised vocabularies, computed flags
            for rule lifecycle status, enforcement classification, and
            regulatory domain tagging.
  ──────────────────────────────────────────────────────────────────────────────
  Note    : Governance rules are low-volume, slowly changing reference data.
            Materialised as table (full refresh) for simplicity and to ensure
            downstream compliance models always join to a complete rule set.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ ref('staging_governance_rules') }}

),

deduplicated as (

    -- Keep latest version of each rule
    select *,
           row_number() over (
               partition by rule_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||', rule_id, cast(_loaded_at as varchar))) as rule_sk,

        -- Natural key
        trim(upper(rule_id)) as rule_id,

        -- Rule descriptors
        trim(rule_name)                         as rule_name,
        trim(rule_description)                  as rule_description,
        trim(rule_logic)                        as rule_logic,
        trim(regulatory_reference)              as regulatory_reference,

        -- Category (controlled vocabulary)
        case
            when upper(trim(rule_category)) in (
                'HIPAA', 'CMS', 'STATE_REGULATION', 'INTERNAL'
            ) then upper(trim(rule_category))
            when rule_category is null then 'UNKNOWN'
            else 'OTHER'
        end as rule_category,

        -- Subcategory (controlled vocabulary)
        case
            when upper(trim(rule_subcategory)) in (
                'ENROLLMENT', 'BILLING', 'CARE_PLAN',
                'REPORTING', 'MEDICATION', 'STAFFING'
            ) then upper(trim(rule_subcategory))
            when rule_subcategory is null then 'UNKNOWN'
            else 'OTHER'
        end as rule_subcategory,

        -- Domain (controlled vocabulary)
        case
            when upper(trim(applies_to_domain)) in (
                'PARTICIPANT', 'APPOINTMENT', 'CAREGIVER',
                'CLINICAL', 'BILLING', 'TRANSPORTATION', 'MEAL_DELIVERY'
            ) then upper(trim(applies_to_domain))
            when applies_to_domain is null then 'CROSS_DOMAIN'
            else 'OTHER'
        end as applies_to_domain,

        -- Enforcement level (controlled vocabulary)
        case
            when upper(trim(enforcement_level)) in (
                'HARD_BLOCK', 'SOFT_WARNING', 'AUDIT_ONLY'
            ) then upper(trim(enforcement_level))
            when enforcement_level is null then 'UNKNOWN'
            else 'OTHER'
        end as enforcement_level,

        -- Enforcement rank (useful for prioritisation in reports)
        case
            when upper(trim(enforcement_level)) = 'HARD_BLOCK'    then 1
            when upper(trim(enforcement_level)) = 'SOFT_WARNING'  then 2
            when upper(trim(enforcement_level)) = 'AUDIT_ONLY'    then 3
            else 99
        end as enforcement_rank,

        -- Boolean enforcement flags
        (upper(trim(enforcement_level)) = 'HARD_BLOCK')   as is_hard_block_flag,
        (upper(trim(enforcement_level)) = 'SOFT_WARNING') as is_soft_warning_flag,
        (upper(trim(enforcement_level)) = 'AUDIT_ONLY')   as is_audit_only_flag,

        -- External regulatory flag (non-internal rules)
        (upper(trim(rule_category)) in ('HIPAA', 'CMS', 'STATE_REGULATION')) as is_regulatory_flag,

        -- Lifecycle dates
        effective_date,
        expiry_date,

        -- Rule lifecycle status as of today
        case
            when is_active = false                              then 'INACTIVE'
            when effective_date > current_date()               then 'PENDING'
            when expiry_date is not null
             and expiry_date < current_date()                  then 'EXPIRED'
            when expiry_date is not null
             and expiry_date < dateadd('day', 30, current_date()) then 'EXPIRING_SOON'
            else 'ACTIVE'
        end as rule_status,

        -- Boolean lifecycle flags
        (
            is_active = true
            and effective_date <= current_date()
            and (expiry_date is null or expiry_date >= current_date())
        ) as is_currently_enforceable_flag,

        (
            expiry_date is not null
            and expiry_date between current_date()
            and dateadd('day', 30, current_date())
        ) as is_expiring_soon_flag,

        -- Rule age in days since effective
        case
            when effective_date is not null
            then datediff('day', effective_date, current_date())
        end as rule_age_days,

        -- Audit trail
        trim(created_by)        as created_by,
        created_at,
        trim(last_updated_by)   as last_updated_by,
        last_updated_at,

        -- Metadata
        upper(trim(source_system))  as source_system,
        _loaded_at                  as loaded_timestamp,
        _source_file                as source_file,
        current_timestamp()         as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned