
/*
  ENTERPRISE_SILVER_TRANSPORTATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_transportation', 'RAW_TRANSPORTATION') }}
  Purpose : Cleanse, deduplicate, and enrich transportation records.
            Adds pickup_wait_minutes and trip_duration_minutes.
  ──────────────────────────────────────────────────────────────────────────────
*/

with

source as (

    select * from {{ source('bronze_transportation', 'RAW_TRANSPORTATION') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by transport_id
               order by _loaded_at desc
           ) as _rn
    from source
    where transport_id   is not null
      and participant_id is not null

),

cleaned as (

    select
        sha2(concat_ws('||', transport_id, cast(_loaded_at as varchar))) as transport_sk,
        trim(upper(transport_id))       as transport_id,
        trim(upper(participant_id))     as participant_id,
        trim(upper(appointment_id))     as appointment_id,
        trim(upper(center_id))          as center_id,

        -- Transport type
        case
            when upper(trim(transport_type)) in
                ('AMBULANCE','WHEELCHAIR_VAN','RIDESHARE','VOLUNTEER')
            then upper(trim(transport_type))
            when transport_type is null then 'UNKNOWN'
            else 'OTHER'
        end as transport_type,

        case
            when upper(trim(trip_direction)) in ('OUTBOUND','RETURN')
            then upper(trim(trip_direction))
            else 'UNKNOWN'
        end as trip_direction,

        case
            when upper(trim(transport_status)) in
                ('SCHEDULED','COMPLETED','CANCELLED','NO_SHOW')
            then upper(trim(transport_status))
            else 'UNKNOWN'
        end as transport_status,

        (upper(trim(transport_status)) = 'COMPLETED') as is_completed_flag,
        (upper(trim(transport_status)) = 'CANCELLED') as is_cancelled_flag,
        (upper(trim(transport_status)) = 'NO_SHOW')   as is_no_show_flag,

        trim(cancellation_reason) as cancellation_reason,
        scheduled_pickup_time as scheduled_pickup_timestamp,
        actual_pickup_time as actual_pickup_timestamp,
        actual_dropoff_time as actual_dropoff_timestamp,

        case
            when actual_pickup_time is not null and scheduled_pickup_time is not null
            then datediff('minute', scheduled_pickup_time, actual_pickup_time)
        end as pickup_wait_minutes,

        case
            when actual_pickup_time is not null and actual_dropoff_time is not null
            then datediff('minute', actual_pickup_time, actual_dropoff_time)
        end as trip_duration_minutes,

        trim(pickup_address) as pickup_address,
        trim(dropoff_address) as dropoff_address,
        trim(special_equipment_needed) as special_equipment_needed,

        coalesce(try_cast(mileage as number(8,2)), 0) as mileage,
        trim(upper(driver_id))  as driver_id,
        trim(upper(vehicle_id)) as vehicle_id,
        trim(upper(vendor_id))  as vendor_id,

        upper(trim(source_system)) as source_system,
        _loaded_at as loaded_timestamp,
        current_timestamp() as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned