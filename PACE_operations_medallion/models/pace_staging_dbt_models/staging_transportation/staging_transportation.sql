/*
  STG_TRANSPORTATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_transportation', 'RAW_TRANSPORTATION') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/


with source as (

    select
        -- Standardized keys
        transport_id as transportation_id,
        participant_id,
        appointment_id,
        driver_id,
        vehicle_id,
        vendor_id,
        center_id,

        -- Standardized descriptors
        transport_type,
        trip_direction,
        transport_status as trip_status,
        cancellation_reason,
        special_equipment_needed,

        -- Standardized locations
        pickup_address as pickup_location,
        dropoff_address as dropoff_location,

        --  Standardized timestamps
        scheduled_pickup_time as ride_date,
        actual_pickup_time,
        actual_dropoff_time,

        mileage,

        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_transportation', 'RAW_TRANSPORTATION') }}

),

filtered as (

    select *
    from source
    where transportation_id is not null
      and participant_id is not null

)

select * from filtered