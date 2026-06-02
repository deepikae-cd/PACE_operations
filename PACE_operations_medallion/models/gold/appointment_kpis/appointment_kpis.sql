select
    appointment_date,

    count(*)                                                                as total_appointments,

    sum(case when appointment_status = 'COMPLETED' then 1 else 0 end)      as completed_count,

    sum(case when appointment_status = 'CANCELLED' then 1 else 0 end)      as cancelled_count,

    round(
        100.0 * sum(case when appointment_status = 'COMPLETED' then 1 else 0 end)
        / nullif(count(*), 0), 2
    )                                                                       as completion_rate,

    round(
        100.0 * sum(case when appointment_status = 'CANCELLED' then 1 else 0 end)
        / nullif(count(*), 0), 2
    )                                                                       as cancellation_rate,

    sum(case
        when appointment_date < current_date()
             and appointment_status not in ('COMPLETED', 'CANCELLED')
        then 1 else 0
    end)                                                                    as overdue_count,

    current_timestamp()                                                     as load_ts

from {{ ref('silver', 'appointment') }}

group by appointment_date