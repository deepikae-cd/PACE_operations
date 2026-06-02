
  
    



create or replace transient  table PACE_DW.GOLD.participant_trip_summary
    
    
    
    
    as (-- models/gold/participant_trip_summary.sql

with base as (

    select *
    from PACE_DW.SILVER.transportation

),

agg as (

    select
        participant_id,

        count(*) as total_trips,

        sum(completed_flag) as completed_trips,

        sum(cancelled_flag) as cancelled_trips,

        round(
            sum(completed_flag) * 1.0 / nullif(count(*), 0),
            2
        ) as completion_rate,

        round(
            sum(cancelled_flag) * 1.0 / nullif(count(*), 0),
            2
        ) as cancellation_rate,

        min(created_ts) as first_trip_date,
        max(created_ts) as last_trip_date

    from base
    group by participant_id

)

select * from agg
    )
;



  