/*
  ENTERPRISE_SILVER_TRANSPORTATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('stg_transportation') }}
  Purpose : Cleanse, deduplicate and enrich transportation records.
            Adds surrogate key, standardised vocabularies, computed flags
            for trip outcomes, punctuality, SLA breaches, and time/distance
            metrics.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ ref('stg_transportation') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by transport_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- ── Surrogate key ──────────────────────────────────────────────────
        sha2(concat_ws('||', transport_id, cast(_loaded_at as varchar))) as transport_sk,

        -- ── Natural / business keys (normalised) ───────────────────────────
        trim(upper(transport_id))   as transport_id,
        trim(upper(participant_id)) as participant_id,
        trim(upper(appointment_id)) as appointment_id,
        trim(upper(driver_id))      as driver_id,
        trim(upper(vehicle_id))     as vehicle_id,
        trim(upper(vendor_id))      as vendor_id,
        trim(upper(center_id))      as center_id,

        -- ── Transport type (controlled vocabulary) ─────────────────────────
        case
            when upper(trim(transport_type)) in (
                'AMBULANCE', 'WHEELCHAIR_VAN', 'RIDESHARE',
                'VOLUNTEER', 'SEDAN', 'STRETCHER_VAN'
            ) then upper(trim(transport_type))
            when transport_type is null then 'UNKNOWN'
            else 'OTHER'
        end as transport_type,

        -- Transport type rank (useful for ordering in reports)
        case
            when upper(trim(transport_type)) = 'AMBULANCE'      then 1
            when upper(trim(transport_type)) = 'STRETCHER_VAN'  then 2
            when upper(trim(transport_type)) = 'WHEELCHAIR_VAN' then 3
            when upper(trim(transport_type)) = 'SEDAN'          then 4
            when upper(trim(transport_type)) = 'RIDESHARE'      then 5
            when upper(trim(transport_type)) = 'VOLUNTEER'      then 6
            else 99
        end as transport_type_rank,

        -- ── Trip direction (controlled vocabulary) ─────────────────────────
        case
            when upper(trim(trip_direction)) in ('OUTBOUND', 'RETURN')
            then upper(trim(trip_direction))
            when trip_direction is null then 'UNKNOWN'
            else 'OTHER'
        end as trip_direction,

        -- ── Transport status (controlled vocabulary) ───────────────────────
        case
            when upper(trim(transport_status)) in (
                'SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW', 'IN_PROGRESS'
            ) then upper(trim(transport_status))
            when transport_status is null then 'UNKNOWN'
            else 'OTHER'
        end as transport_status,

        -- ── Boolean status flags ───────────────────────────────────────────
        (upper(trim(transport_status)) = 'SCHEDULED')   as is_scheduled_flag,
        (upper(trim(transport_status)) = 'COMPLETED')   as is_completed_flag,
        (upper(trim(transport_status)) = 'CANCELLED')   as is_cancelled_flag,
        (upper(trim(transport_status)) = 'NO_SHOW')     as is_no_show_flag,
        (upper(trim(transport_status)) = 'IN_PROGRESS') as is_in_progress_flag,

        -- Negative outcome — cancelled or no-show; useful for utilisation reports
        (
            upper(trim(transport_status)) in ('CANCELLED', 'NO_SHOW')
        ) as is_unsuccessful_flag,

        -- ── Cancellation ───────────────────────────────────────────────────
        trim(cancellation_reason) as cancellation_reason,

        -- Cancelled and a reason was documented
        (
            upper(trim(transport_status)) = 'CANCELLED'
            and nullif(trim(cancellation_reason), '') is not null
        ) as is_cancelled_with_reason_flag,

        -- ── Special equipment (controlled vocabulary) ──────────────────────
        case
            when upper(trim(special_equipment_needed)) in (
                'WHEELCHAIR_LIFT', 'STRETCHER', 'OXYGEN',
                'BARIATRIC', 'CAR_SEAT', 'NONE'
            ) then upper(trim(special_equipment_needed))
            when special_equipment_needed is null then 'NONE'
            else 'OTHER'
        end as special_equipment_needed,

        -- Trip required specialised equipment
        (
            nullif(trim(special_equipment_needed), '') is not null
            and upper(trim(special_equipment_needed)) != 'NONE'
        ) as requires_special_equipment_flag,

        -- ── Addresses ──────────────────────────────────────────────────────
        trim(pickup_address)  as pickup_address,
        trim(dropoff_address) as dropoff_address,

        -- ── Timestamps ─────────────────────────────────────────────────────
        scheduled_pickup_time,
        actual_pickup_time,
        actual_dropoff_time,

        -- ── Punctuality metrics ────────────────────────────────────────────
        -- Pickup delay in minutes (positive = late, negative = early)
        case
            when scheduled_pickup_time is not null
             and actual_pickup_time    is not null
            then datediff('minute', scheduled_pickup_time, actual_pickup_time)
        end as pickup_delay_minutes,

        -- Total trip duration in minutes (pickup to drop-off)
        case
            when actual_pickup_time  is not null
             and actual_dropoff_time is not null
            then datediff('minute', actual_pickup_time, actual_dropoff_time)
        end as trip_duration_minutes,

        -- On-time flag — arrived within 15 minutes of scheduled pickup
        case
            when actual_pickup_time    is null
              or scheduled_pickup_time is null then null
            when datediff('minute', scheduled_pickup_time, actual_pickup_time)
                 between -60 and 15 then true
            else false
        end as is_on_time_flag,

        -- Late pickup flag — more than 15 minutes after scheduled time
        case
            when actual_pickup_time    is null
              or scheduled_pickup_time is null then null
            when datediff('minute', scheduled_pickup_time, actual_pickup_time) > 15
            then true
            else false
        end as is_late_pickup_flag,

        -- ── SLA breach flag ────────────────────────────────────────────────
        -- AMBULANCE / STRETCHER_VAN > 30 min late; all others > 60 min late
        -- Only evaluated on completed or in-progress trips
        case
            when upper(trim(transport_status)) not in ('COMPLETED', 'IN_PROGRESS')
            then false
            when actual_pickup_time    is null
              or scheduled_pickup_time is null
            then false
            when upper(trim(transport_type)) in ('AMBULANCE', 'STRETCHER_VAN')
             and datediff('minute', scheduled_pickup_time, actual_pickup_time) > 30
            then true
            when datediff('minute', scheduled_pickup_time, actual_pickup_time) > 60
            then true
            else false
        end as is_sla_breached_flag,

        -- ── Mileage ────────────────────────────────────────────────────────
        -- Reject negative mileage values
        case
            when mileage >= 0 then mileage
        end as mileage,

        -- Mileage band for cost / utilisation reporting
        case
            when mileage is null then 'UNKNOWN'
            when mileage <  5   then '<5 MI'
            when mileage < 15   then '5-15 MI'
            when mileage < 30   then '15-30 MI'
            else '30+ MI'
        end as mileage_band,

        -- ── Date / time dimensions (for reporting grain) ───────────────────
        date_trunc('day',   scheduled_pickup_time) as trip_date,
        date_trunc('month', scheduled_pickup_time) as trip_month,
        dayofweek(scheduled_pickup_time)            as trip_day_of_week,   -- 0=Sun … 6=Sat
        hour(scheduled_pickup_time)                 as scheduled_pickup_hour,

        -- ── Metadata ───────────────────────────────────────────────────────
        upper(trim(source_system)) as source_system,
        _loaded_at                 as loaded_timestamp,
        _source_file               as source_file,
        current_timestamp()        as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned