select

    transportation_id,
    participant_id,
    ride_date,
    pickup_location,
    dropoff_location,
    trip_status,
    case when trip_status = 'completed' then 1 else 0 end as completed_flag

from {{ ref('staging_transportation') }}