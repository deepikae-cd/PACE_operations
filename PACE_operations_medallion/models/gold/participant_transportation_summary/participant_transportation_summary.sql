with base as (
    select
        *,
        case when status = 'completed' then 1 else 0 end as completed_flag,
        case when status = 'cancelled' then 1 else 0 end as cancelled_flag
    from {{ ref('transportation') }}
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

select * from agg;
