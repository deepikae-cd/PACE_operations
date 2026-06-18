/*
===============================================================================
Model: gold_transportation_performance
Purpose:
  Provides transportation performance KPIs at daily level.

Grain:
  ride_date
===============================================================================
*/

with base as (

    select
        ride_date,
        upper(trim(trip_status)) as trip_status
    from {{ ref('enterprise_silver_transportation') }}

),

aggregated as (

    select
        ride_date,

        count(*) as total_trips,

        -- ✅ FIX: derive completed trips dynamically
        sum(case when trip_status = 'COMPLETED' then 1 else 0 end) as completed_trips,

        sum(case when trip_status = 'CANCELLED' then 1 else 0 end) as cancelled_trips

    from base
    where ride_date is not null
    group by ride_date

)

select
    ride_date,
    total_trips,
    completed_trips,
    cancelled_trips,

    completed_trips / nullif(total_trips, 0) as completion_rate,

    current_timestamp() as dbt_updated_timestamp

from aggregated