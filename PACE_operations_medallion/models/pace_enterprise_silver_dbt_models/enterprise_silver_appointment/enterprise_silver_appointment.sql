/*
  ENTERPRISE_SILVER_APPOINTMENT
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('staging_appointment') }}
  Purpose : Cleanse, deduplicate and enrich appointment records.
            Adds surrogate key, computed metrics (actual duration,
            late-start minutes) and boolean status flags.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ ref('staging_appointment') }}

    {% if is_incremental() %}
        -- Only process records newer than the last load
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by appointment_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||', appointment_id, cast(_loaded_at as varchar))) as appointment_sk,

        -- Natural keys (normalised)
        trim(upper(appointment_id))         as appointment_id,
        trim(upper(participant_id))         as participant_id,
        trim(upper(caregiver_id))           as caregiver_id,
        trim(upper(provider_id))            as provider_id,
        trim(upper(center_id))              as center_id,
        trim(upper(parent_appointment_id))  as parent_appointment_id,

        -- Appointment type (standardised)
        case
            when upper(trim(appointment_type)) like '%MEDICAL%'   then 'MEDICAL_VISIT'
            when upper(trim(appointment_type)) like '%THERAP%'    then 'THERAPY'
            when upper(trim(appointment_type)) like '%ASSESS%'    then 'ASSESSMENT'
            when upper(trim(appointment_type)) like '%DENTAL%'    then 'DENTAL'
            when upper(trim(appointment_type)) like '%SOCIAL%'    then 'SOCIAL_WORK'
            when upper(trim(appointment_type)) like '%NUTRI%'     then 'NUTRITION'
            when upper(trim(appointment_type)) like '%TRANSPORT%' then 'TRANSPORTATION'
            when appointment_type is null                         then 'UNKNOWN'
            else 'OTHER'
        end as appointment_type,

        -- Appointment status (controlled vocabulary)
        case
            when upper(trim(appointment_status)) in
                ('SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW')
            then upper(trim(appointment_status))
            else 'UNKNOWN'
        end as appointment_status,

        -- Boolean status flags
        (upper(trim(appointment_status)) = 'COMPLETED') as is_completed_flag,
        (upper(trim(appointment_status)) = 'CANCELLED') as is_cancelled_flag,
        (upper(trim(appointment_status)) = 'NO_SHOW')   as is_no_show_flag,

        trim(cancellation_reason) as cancellation_reason,

        -- Timestamps
        scheduled_date,
        actual_start_time,
        actual_end_time,

        -- Computed metrics
        case
            when actual_start_time is not null
             and actual_end_time   is not null
            then datediff('minute', actual_start_time, actual_end_time)
        end as duration_minutes_actual,

        case
            when actual_start_time is not null
             and scheduled_date    is not null
            then datediff('minute', scheduled_date, actual_start_time)
        end as late_start_minutes,

        -- Late-start flag (> 15 min threshold)
        case
            when actual_start_time is not null
             and scheduled_date    is not null
             and datediff('minute', scheduled_date, actual_start_time) > 15
            then true
            else false
        end as is_late_start_flag,

        -- Location (controlled vocabulary)
        case
            when upper(trim(location_type)) in
                ('CENTER', 'HOME', 'TELEHEALTH', 'HOSPITAL')
            then upper(trim(location_type))
            when location_type is null then 'UNKNOWN'
            else 'OTHER'
        end as location_type,

        trim(location_address) as location_address,

        -- Recurrence
        upper(trim(recurrence_pattern)) as recurrence_pattern,
        (recurrence_pattern is not null) as is_recurring_flag,

        trim(notes) as notes,

        -- Metadata
        upper(trim(source_system))  as source_system,
        _loaded_at                  as loaded_timestamp,
        _source_file                as source_file,
        current_timestamp()         as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned