select
    appointment_id,
    participant_id,
    provider_id,
    appointment_date,
    upper(trim(service_type)) as service_type,
    upper(trim(status)) as appointment_status,
    created_ts as source_created_ts,
    current_timestamp() as load_ts,
    case
        when upper(status) = 'COMPLETED' then 1
        else 0
    end as completed_flag,

    case
        when upper(status) = 'CANCELLED' then 1
        else 0
    end as cancelled_flag,

    case
        when appointment_date < current_date()
             and upper(status) <> 'COMPLETED'
        then 'OVERDUE'

        when appointment_date = current_date()
        then 'TODAY'

        when appointment_date > current_date()
        then 'UPCOMING'

        else 'UNKNOWN'
    end as appointment_category

from PACE_DW.BRONZE.appointment_raw