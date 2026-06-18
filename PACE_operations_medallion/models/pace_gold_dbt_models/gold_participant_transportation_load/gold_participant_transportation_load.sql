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

    select *
    from {{ ref('enterprise_silver_transportation') }}

),

aggregated as (

    select
        participant_id,

        count(*) as total_trips,
        sum(completed_flag) as completed_trips,

        count(distinct ride_date) as active_days

    from base
    group by participant_id

)

select
    participant_id,
    total_trips,
    completed_trips,
    active_days,

    total_trips / nullif(active_days,0) as trips_per_day,

    current_timestamp() as dbt_updated_timestamp

from aggregated