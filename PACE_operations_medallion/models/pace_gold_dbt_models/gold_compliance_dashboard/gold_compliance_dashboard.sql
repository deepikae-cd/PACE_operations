/*
  GOLD_COMPLIANCE_DASHBOARD
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('fact_compliance_violation') }}
  Purpose : Business-ready aggregated compliance metrics for dashboards.

  Grain   : entity_id + rule_category
  ──────────────────────────────────────────────────────────────────────────────
*/

with base as (

    select *
    from {{ ref('fct_compliance_violation') }}

)

select
    entity_id,
    rule_category,

    -- Core KPIs
    count(*) as total_violations,
    sum(is_open_flag) as open_violations,
    sum(is_high_flag) as high_severity_violations,

    -- Derived KPIs
    round(sum(is_open_flag) * 1.0 / count(*), 4) as open_violation_rate,
    round(sum(is_high_flag) * 1.0 / count(*), 4) as high_severity_rate

from base
group by entity_id, rule_category