/*
===============================================================================
Model: gold_provider_performance
Purpose:
  Provides provider distribution and activity metrics by center.

Grain:
  center_id
===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_provider') }}

),

aggregated as (

    select
        center_id,

        count(*) as total_providers,

        sum(case when is_contract_active_flag then 1 else 0 end) as active_providers,
        sum(case when is_preferred_flag then 1 else 0 end) as preferred_providers,

        sum(case when accepts_pace_patients_flag then 1 else 0 end) as pace_providers

    from base
    group by center_id

)

select
    *,
    active_providers / nullif(total_providers, 0) as active_provider_ratio,
    current_timestamp() as dbt_updated_timestamp
from aggregated