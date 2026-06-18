/*
===============================================================================
Model: gold_provider_network_analysis
Purpose:
  Analyzes provider networks and specialization distribution.

Grain:
  center_id + provider_type
===============================================================================
*/

with base as (

    select *
    from {{ ref('enterprise_silver_provider') }}

),

aggregated as (

    select
        center_id,
        provider_type,

        count(*) as provider_count,
        sum(case when is_in_network_flag then 1 else 0 end) as in_network_count,
        sum(case when is_preferred_flag then 1 else 0 end) as preferred_count

    from base
    group by 1,2

)

select
    *,
    current_timestamp() as dbt_updated_timestamp
from aggregated