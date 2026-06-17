/*
===============================================================================
Model: gold_center_quality_metrics
Purpose:
  Tracks quality performance at the center level including ratings
  and audit compliance indicators.

Grain:
  center_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_organization') }}

),

aggregated as (

    select
        center_id,

        avg(quality_rating) as avg_quality_rating,

        max(quality_rating_tier) as quality_rating_tier,

        max(is_cms_audit_overdue_flag) as is_cms_audit_overdue_flag,
        max(is_state_audit_overdue_flag) as is_state_audit_overdue_flag,

        avg(days_since_cms_audit) as avg_days_since_cms_audit,
        avg(days_since_state_audit) as avg_days_since_state_audit

    from base
    group by center_id

),

final as (

    select
        *,
        current_timestamp() as dbt_updated_timestamp
    from aggregated

)

select * from final
