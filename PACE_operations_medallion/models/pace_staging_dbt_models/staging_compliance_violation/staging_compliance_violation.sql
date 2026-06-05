/*
  STAGING_COMPLIANCE_VIOLATIONS
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_governance', 'RAW_COMPLIANCE_VIOLATIONS') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select
        -- Keys
        violation_id,
        rule_id,
        entity_id,
        center_id,

        -- Descriptors (raw — no business logic here)
        entity_type,
        violation_description,
        severity,
        status,
        resolved_by,

        -- Timestamps
        violation_date,
        resolved_at,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_governance', 'RAW_COMPLIANCE_VIOLATIONS') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where violation_id is not null
      and rule_id      is not null

)

select * from filtered