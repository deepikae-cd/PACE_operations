/*
  STG_APPOINTMENT
  Source  : {{ source('bronze_appointment', 'RAW_APPOINTMENT') }}
  Purpose : Cleanse, cast, deduplicate and enrich appointment records.
*/

with

source as (

    select * from {{ source('bronze_appointment', 'RAW_APPOINTMENT') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by appointment_id
               order by _loaded_at desc
           ) as _rn
    from source
    where appointment_id  is not null
      and participant_id  is not null
      and scheduled_date  is not null

),

cleaned as (

    select
        -- ── Keys ────────────────────────────────────────────────────────────
        sha2(concat_ws('||', appointment_id, cast(_loaded_at as varchar)))  as appointment_sk,
        trim(upper(appointment_id))                                         as appointment_id,
        trim(upper(participant_id))                                         as participant_id,
        trim(upper(caregiver_id))                                           as caregiver_id,
        trim(upper(provider_id))                                            as provider_id,
        trim(upper(center_id))                                              as center_id,
        trim(upper(parent_appointment_id))                                  as parent_appointment_id,

        -- ── Type normalisation ───────────────────────────────────────────────
        case
            when upper(trim(appointment_type)) like '%MEDICAL%'     then 'MEDICAL_VISIT'
            when upper(trim(appointment_type)) like '%THERAP%'      then 'THERAPY'
            when upper(trim(appointment_type)) like '%ASSESS%'      then 'ASSESSMENT'
            when upper(trim(appointment_type)) like '%DENTAL%'      then 'DENTAL'
            when upper(trim(appointment_type)) like '%SOCIAL%'      then 'SOCIAL_WORK'
            when upper(trim(appointment_type)) like '%NUTRI%'       then 'NUTRITION'
            when upper(trim(appointment_type)) like '%TRANSPORT%'   then 'TRANSPORTATION'
            when appointment_type is null                           then 'UNKNOWN'
            else 'OTHER'
        end as appointment_type,

        -- ── Status ──────────────────────────────────────────────────────────
        case
            when upper(trim(appointment_status)) in
                ('SCHEDULED','COMPLETED','CANCELLED','NO_SHOW')
            then upper(trim(appointment_status))
            else 'UNKNOWN'
        end as appointment_status,

        -- ── Boolean status flags ─────────────────────────────────────────────
        (upper(trim(appointment_status)) = 'COMPLETED')  as is_completed,
        (upper(trim(appointment_status)) = 'CANCELLED')  as is_cancelled,
        (upper(trim(appointment_status)) = 'NO_SHOW')    as is_no_show,

        trim(cancellation_reason) as cancellation_reason,

        -- ── Timestamps (CAST ONLY ONCE) ──────────────────────────────────────
        try_cast(scheduled_date    as timestamp_ntz) as scheduled_date,
        try_cast(actual_start_time as timestamp_ntz) as actual_start_time,
        try_cast(actual_end_time   as timestamp_ntz) as actual_end_time,

        -- ── Computed metrics (NO TRY_CAST HERE) ──────────────────────────────
        case
            when actual_start_time is not null and actual_end_time is not null
            then datediff('minute', actual_start_time, actual_end_time)
        end as duration_minutes_actual,

        case
            when actual_start_time is not null and scheduled_date is not null
            then datediff('minute', scheduled_date, actual_start_time)
        end as late_start_minutes,

        -- ── Location ────────────────────────────────────────────────────────
        case
            when upper(trim(location_type)) in
                ('CENTER','HOME','TELEHEALTH','HOSPITAL')
            then upper(trim(location_type))
            when location_type is null then 'UNKNOWN'
            else 'OTHER'
        end as location_type,

        trim(location_address) as location_address,

        -- ── Recurrence ──────────────────────────────────────────────────────
        upper(trim(recurrence_pattern)) as recurrence_pattern,
        trim(notes)                     as notes,

        -- ── Metadata ────────────────────────────────────────────────────────
        upper(trim(source_system)) as source_system,
        _loaded_at               as loaded_at,
        current_timestamp()      as dbt_updated_at

    from deduplicated
    where _rn = 1

)

select * from cleaned