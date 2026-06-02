with source_data as (

    select
        transport_id,
        participant_id,
        pickup_location,
        destination,
        pickup_time,
        status,
        created_ts

    from PACE_DW.BRONZE.transportation_raw

),

cleaned as (

    select
        transport_id,
        participant_id,
        pickup_location,
        destination,
        pickup_time,
        created_ts,

        -- standardized status (DO NOT overwrite raw column)
        upper(coalesce(status, 'UNKNOWN')) as trip_status,

        -- derived flags (required for Gold)
        case 
            when upper(status) = 'COMPLETED' then 1 
            else 0 
        end as completed_flag,

        case 
            when upper(status) = 'CANCELLED' then 1 
            else 0 
        end as cancelled_flag

    from source_data

)

select * from cleaned