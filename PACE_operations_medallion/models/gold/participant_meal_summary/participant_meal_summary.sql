with base as (

    select *
    from {{ ref('meal_delivery') }}

),

agg as (

    select

        participant_id,

        count(*) as total_meals_scheduled,

        sum(delivered_flag) as meals_delivered,

        sum(pending_flag) as meals_pending,

        sum(cancelled_flag) as meals_cancelled,

        sum(case when delivery_category = 'MISSED' then 1 else 0 end) as missed_deliveries,

        sum(case when delivered_flag = 0 then 1 else 0 end) as not_delivered,

        round(
            100.0 * sum(delivered_flag) / nullif(count(*), 0),
            2
        ) as delivery_success_rate_pct,

        round(
            100.0 * sum(case when delivered_flag = 0 then 1 else 0 end)
            / nullif(count(*), 0),
            2
        ) as non_delivery_rate_pct,

        current_timestamp() as load_ts

    from base
    group by participant_id

)

select * from agg