/*
  MODEL: GOLD_MEDICATION_SITE_VARIANCE
  ------------------------------------------------------------------------------
  PURPOSE:
    Compares medication patterns across centers for equity analysis.

  GRAIN:
    1 row per center_id
*/

select
    center_id,

    count(*) as total_medications,
    avg(total_cost) as avg_cost,

    sum(case when is_off_formulary_flag then 1 else 0 end) as off_formulary_count,
    sum(case when is_high_risk_controlled_flag then 1 else 0 end) as high_risk_count,

    off_formulary_count / nullif(count(*), 0) as off_formulary_rate,

    current_timestamp() as dbt_updated_timestamp

from {{ ref('enterprise_silver_medication') }}
group by center_id
