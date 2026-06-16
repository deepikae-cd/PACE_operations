/*
  int_compliance_violation_metrics
  ──────────────────────────────────────────────────────────────────────────────
  Purpose : Aggregate compliance violations into entity-level metrics
            segmented by rule category.

  Grain   : 1 row per (entity_id, rule_category)

  Logic   :
    - Standardizes status into open flag
    - Standardizes severity into high-severity flag
    - Joins rule metadata for categorization
    - Aggregates violations into KPI-style measures

  Inputs  :
    - staging_compliance_violation
    - staging_governance_rules

  Outputs :
    - total_violations
    - open_violations
    - high_severity_violations
  ──────────────────────────────────────────────────────────────────────────────
*/

with base as (

    select
        -- Business keys
        v.entity_id,
        v.rule_id,

        -- Flags (standardized)
        case
            when lower(v.status) = 'open' then 1
            else 0
        end as is_open,

        case
            when lower(v.severity) = 'high' then 1
            else 0
        end as is_high,

        -- Rule attributes (dimension enrichment)
        r.rule_category,
        r.enforcement_level

    from {{ ref('staging_compliance_violation') }} v

    left join {{ ref('staging_governance_rules') }} r
        on v.rule_id = r.rule_id

)

select
    entity_id,
    rule_category,

    -- Aggregated measures
    count(*) as total_violations,
    sum(is_open) as open_violations,
    sum(is_high) as high_severity_violations

from base
group by entity_id, rule_category