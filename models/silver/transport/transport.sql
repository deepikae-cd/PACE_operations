select
    transport_id,
    participant_id,
    upper(trim(pickup_location)) as pickup_location,
    upper(trim(destination)) as destination,
    pickup_time,
    upper(trim(status)) as transport_status,
    created_ts as source_created_ts,
    current_timestamp() as load_ts,
    datediff(
        day,
        cast(pickup_time as date),
        current_date()
    ) as days_from_pickup,

    case
        when upper(status) = 'COMPLETED' then 1
        else 0
    end as completed_flag,

    case
        when upper(status) = 'SCHEDULED' then 1
        else 0
    end as scheduled_flag,

    case
        when upper(status) = 'CANCELLED' then 1
        else 0
    end as cancelled_flag,

    case
        when cast(pickup_time as date) < current_date()
             and upper(status) <> 'COMPLETED'
        then 'MISSED'

        when cast(pickup_time as date) = current_date()
        then 'TODAY'

        when cast(pickup_time as date) > current_date()
        then 'UPCOMING'

        else 'UNKNOWN'
    end as transport_category

from {{ source('bronze','transport_raw') }}