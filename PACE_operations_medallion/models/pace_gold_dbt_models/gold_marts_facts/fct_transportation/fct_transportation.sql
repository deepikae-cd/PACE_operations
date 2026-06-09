with source as (

    select *
    from {{ ref('enterprise_silver_transportation') }}

),

cleaned as (

    select

        --  Keys
        transportation_id,
        participant_id,
        --  Trip details
        ride_date,
        trim(pickup_location)  as pickup_location,
        trim(dropoff_location) as dropoff_location,

        -- Standardized status
        upper(trim(trip_status)) as trip_status,

        -- Flag
        case 
            when upper(trim(trip_status)) = 'COMPLETED' then 1 
            else 0 
        end as completed_flag

    from source
    where transportation_id is not null

),

deduplicated as (

    select *,
           row_number() over (
               partition by transportation_id
               order by ride_date desc
           ) as _rn
    from cleaned

)

select
    transportation_id,
    participant_id,
    ride_date,
    pickup_location,
    dropoff_location,
    trip_status,
    completed_flag

from deduplicated
where _rn = 1