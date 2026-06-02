with base as (

    select
        *,
        case when appointment_status = 'COMPLETED' then 1 else 0 end as completed_flag,
        case when appointment_status = 'CANCELLED' then 1 else 0 end as cancelled_flag
    from {{ ref('appointment') }}

),

agg as (

    select
        appointment_date,

        count(*) as total_appointments,

        sum(completed_flag) as completed,
        sum(cancelled_flag) as cancelled,

        round(
            100.0 * sum(completed_flag) / nullif(count(*), 0),
            2
        ) as completion_rate,

        round(
            100.0 * sum(cancelled_flag) / nullif(count(*), 0),
            2
        ) as cancellation_rate,

        -- ✅ Only keep if this column exists
        sum(case when appointment_status = 'OVERDUE' then 1 else 0 end) as overdue_count,

        current_timestamp() as load_ts

    from base
    group by appointment_date

)

select * from agg
