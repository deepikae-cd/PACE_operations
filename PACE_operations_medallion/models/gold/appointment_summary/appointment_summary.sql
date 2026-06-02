select
    appointment_date,

    count(*) as total_appointments,

    sum(completed_flag) as completed,

    sum(cancelled_flag) as cancelled,

    round(100.0 * sum(completed_flag) / nullif(count(*),0), 2) as completion_rate,

    round(100.0 * sum(cancelled_flag) / nullif(count(*),0), 2) as cancellation_rate,

    sum(case when appointment_category = 'OVERDUE' then 1 else 0 end) as overdue_count,

    current_timestamp() as load_ts

from {{ ref('appointment') }}
group by appointment_date 

