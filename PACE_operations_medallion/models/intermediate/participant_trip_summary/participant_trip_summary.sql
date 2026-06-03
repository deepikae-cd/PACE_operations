with trips as (

    select *
    from {{ ref('transportation') }}

),

participant_base as (

    select *
    from {{ ref('participant') }}

),

agg as (

    select
        participant_id,

        count(*) as total_trips,

        count(case when upper(trip_status) = 'COMPLETED' then 1 end) as completed_trips,

        count(case when upper(trip_status) = 'DELAYED' then 1 end) as delayed_trips,

        count(case when upper(trip_status) = 'CANCELLED' then 1 end) as cancelled_trips,

        count(case when upper(trip_status) not in ('COMPLETED','DELAYED','CANCELLED')
                   then 1 end) as other_trips,

        min(pickup_time) as first_trip_date,
        max(pickup_time) as last_trip_date

    from trips
    group by participant_id

)

select
    p.participant_id,
    p.first_name,
    p.last_name,
    p.participant_status,

    coalesce(a.total_trips, 0) as total_trips,
    coalesce(a.completed_trips, 0) as completed_trips,
    coalesce(a.delayed_trips, 0) as delayed_trips,
    coalesce(a.cancelled_trips, 0) as cancelled_trips,
    coalesce(a.other_trips, 0) as other_trips,

    case 
        when a.participant_id is not null then 'TRAVELLED'
        else 'NO_TRAVEL'
    end as travel_flag,

    a.first_trip_date,
    a.last_trip_date

from participant_base p
left join agg a
    on p.participant_id = a.participant_id