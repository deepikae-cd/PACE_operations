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
        -- Keys
        transport_id,
        participant_id,
        appointment_id,
        driver_id,
        vehicle_id,
        vendor_id,
        center_id,

        -- Trip descriptors (raw — no business logic here)
        transport_type,
        trip_direction,
        transport_status,
        cancellation_reason,
        special_equipment_needed,

        -- Addresses
        pickup_address,
        dropoff_address,

        -- Timestamps
        scheduled_pickup_time,
        actual_pickup_time,
        actual_dropoff_time,

        -- Metrics
        mileage,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_transportation', 'RAW_TRANSPORTATION') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where transport_id   is not null
      and participant_id is not null

)

select * from filtered