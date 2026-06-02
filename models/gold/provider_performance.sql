with base as (

    select
        provider_id,
        appointment_id,
        appointment_status,
        appointment_category
    from {{ ref('appointment') }}

),

agg as (

    select
        provider_id,

        count(*) as total_appointments,

        sum(case when appointment_status = 'COMPLETED' then 1 else 0 end) as completed_appointments,

        sum(case when appointment_status = 'CANCELLED' then 1 else 0 end) as cancelled_appointments,

        round(
            100.0 * sum(case when appointment_status = 'COMPLETED' then 1 else 0 end)
            / nullif(count(*),0), 2
        ) as completion_rate_pct,

        round(
            100.0 * sum(case when appointment_status = 'CANCELLED' then 1 else 0 end)
            / nullif(count(*),0), 2
        ) as cancellation_rate_pct,

        sum(case when appointment_category = 'OVERDUE' then 1 else 0 end) as overdue_appointments

    from base
    group by provider_id

)

select
    *,
    current_timestamp() as load_ts
from agg