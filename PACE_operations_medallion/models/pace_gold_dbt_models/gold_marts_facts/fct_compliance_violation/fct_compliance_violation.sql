/*
  FCT_COMPLIANCE_VIOLATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  :
    - {{ ref('staging_compliance_violation') }}
    - {{ ref('dim_governance_rules') }}

  Purpose : Atomic fact table representing each compliance violation event.

  Grain   : 1 row per violation_id
  ──────────────────────────────────────────────────────────────────────────────
*/

with base as (

    select
        v.violation_id,
        v.entity_id,
        v.rule_id,
        v.center_id,

        -- Flags
        case when lower(v.status) = 'open' then 1 else 0 end as is_open_flag,
        case when lower(v.severity) = 'high' then 1 else 0 end as is_high_flag,

        -- Dates
        v.violation_date,
        v.resolved_at

    from {{ ref('staging_compliance_violation') }} v

),

enriched as (

    select
        b.*,
        d.rule_sk,
        d.rule_category,
        d.enforcement_level
    from base b
    left join {{ ref('dim_governance_rules') }} d
        on b.rule_id = d.rule_id

)

select * from enriched
