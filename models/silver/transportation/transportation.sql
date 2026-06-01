with source_data as (

    select
        transport_id,
        participant_id,
        pickup_location,
        destination,
        pickup_time,
        status,
        created_ts

    from {{ source('bronze', 'transportation_raw') }}

),

cleaned as (

    select
        transport_id,
        participant_id,
        pickup_location,
        destination,

        -- standardize timestamp handling (optional but common in silver layer)
        pickup_time,
        created_ts,

        -- optional derived columns (useful in silver)
        case 
            when status is null then 'UNKNOWN'
            else upper(status)
        end as status

    from source_data

)

select * from cleaned