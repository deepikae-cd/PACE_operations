/*
  STAGING_GOVERNANCE_RULES
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_governance', 'RAW_GOVERNANCE_RULES') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select
        -- Keys
        rule_id,

        -- Descriptors (raw — no business logic here)
        rule_name,
        rule_category,
        rule_subcategory,
        rule_description,
        rule_logic,
        applies_to_domain,
        enforcement_level,
        regulatory_reference,
        is_active,

        -- Dates
        effective_date,
        expiry_date,

        -- Audit trail
        created_by,
        created_at,
        last_updated_by,
        last_updated_at,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_governance', 'RAW_GOVERNANCE_RULES') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where rule_id is not null

)

select * from filtered