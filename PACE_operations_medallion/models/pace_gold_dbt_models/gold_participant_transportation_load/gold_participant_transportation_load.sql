/*
===============================================================================
Model: gold_participant_transportation_load
Purpose:
  Measures transportation dependency at participant level.

Grain:
  participant_id
===============================================================================
*/

with base as (

    select
        participant_id,
        ride_date,
        upper(trim(trip_status)) as trip_status

    from {{ ref('enterprise_silver_transportation') }}

),

aggregated as (

    select
        participant_id,

        count(*) as total_trips,

        -- ✅ derive instead of relying on missing column
        sum(case when trip_status = 'COMPLETED' then 1 else 0 end) as completed_trips,

        count(distinct ride_date) as active_days

    from base
    where participant_id is not null
    group by participant_id

)

select
    participant_id,
    total_trips,
    completed_trips,
    active_days,

    total_trips / nullif(active_days, 0) as trips_per_day,

    current_timestamp() as dbt_updated_timestamp

from aggregated