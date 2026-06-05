/*
================================================================================
Model       : int_appointment
Layer       : Intermediate
Project     : pace_intermediate_dbt_models
Folder      : int_appointment/
Description : Enriches enterprise silver appointment data with participant,
              provider, and caregiver context. Applies PACE-specific business
              logic for appointment classification, attendance status resolution,
              and care coordination flags.

Depends on  :
  - {{ ref('enterprise_silver_appointment') }}
  - {{ ref('enterprise_silver_participant') }}
  - {{ ref('enterprise_silver_provider') }}
  - {{ ref('enterprise_silver_caregiver') }}
  - {{ ref('enterprise_silver_organization') }}

Materialization : view (default for intermediate layer)
Tags            : ['intermediate', 'appointment', 'pace', 'care_coordination']
================================================================================
*/

with

-- ============================================================
-- Anchor timestamp (consistent evaluation)
-- ============================================================
current_ts as (
    select current_timestamp as now_ts
),

-- ============================================================
-- Source CTEs
-- ============================================================
silver_appointment as (
    select * from {{ ref('enterprise_silver_appointment') }}
),

silver_participant as (
    select
        participant_id,
        first_name  as participant_first_name,
        last_name   as participant_last_name,
        full_name   as participant_full_name,
        date_of_birth,

        -- ✅ SAFE (no dependency on missing columns)
        null as enrollment_status,

        primary_pace_center_id,
        primary_care_team_id,
        medicaid_number,
        medicare_number,
        is_active_enrollee
    from {{ ref('enterprise_silver_participant') }}
),

silver_provider as (
    select
        provider_id,
        first_name  as provider_first_name,
        last_name   as provider_last_name,
        full_name   as provider_full_name,
        provider_type_code,
        provider_type_description,
        provider_specialty_code,
        provider_specialty_description,
        npi_number,
        organization_id,
        is_active_provider
    from {{ ref('enterprise_silver_provider') }}
),

silver_caregiver as (
    select
        caregiver_id,
        participant_id,
        caregiver_full_name,
        caregiver_relationship_code,
        caregiver_relationship_description,
        is_primary_caregiver,
        is_emergency_contact
    from {{ ref('enterprise_silver_caregiver') }}
),

silver_organization as (
    select
        organization_id,
        organization_name,
        organization_type_code,
        pace_center_id,
        pace_center_name,
        address_state,
        address_city
    from {{ ref('enterprise_silver_organization') }}
),

-- ============================================================
-- Deduplicated primary caregiver
-- ============================================================
primary_caregiver as (
    select *
    from (
        select
            participant_id,
            caregiver_id,
            caregiver_full_name,
            caregiver_relationship_code,
            caregiver_relationship_description,
            row_number() over (
                partition by participant_id
                order by is_primary_caregiver desc
            ) as rn
        from silver_caregiver
    )
    where rn = 1
),

-- ============================================================
-- Business classification
-- ============================================================
appointment_classified as (

    select
        appt.*,
        ts.now_ts,
        case
            when appt.appointment_datetime > ts.now_ts then 'upcoming'
            when appt.attendance_status_code in ('PRESENT','ATTENDED','COMP') then 'attended'
            when appt.attendance_status_code in ('NS','NO_SHOW','NOSHOW') then 'no_show'
            when appt.attendance_status_code in ('CANCEL_PT','CANCEL_PROVIDER') then 'cancelled'
            when appt.attendance_status_code in ('RESCHEDULED','RESCHEDULE') then 'rescheduled'
            when appt.attendance_status_code = 'LATE_CANCEL' then 'late_cancellation'
            else 'unknown'
        end as attendance_status_normalized,

        -- Category
        case
            when appt.appointment_type_code in ('IDT','IDT_CARE_CONF') then 'interdisciplinary_team'
            when appt.appointment_type_code in ('PCP','PRIMARY_CARE') then 'primary_care'
            when appt.appointment_type_code in ('SPEC','SPECIALIST') then 'specialist'
            when appt.appointment_type_code in ('BH','BEHAV_HEALTH') then 'behavioral_health'
            when appt.appointment_type_code in ('PT','OT','ST') then 'therapy'
            when appt.appointment_type_code in ('TRANS_EVAL','TRANSPORT') then 'transportation_related'
            when appt.appointment_type_code in ('DENTAL','VISION','AUDIOLOGY') then 'ancillary'
            when appt.appointment_type_code in ('DAYCARE','ADC') then 'adult_day_center'
            else 'other'
        end as appointment_category,

        -- Care setting
        case
            when appt.location_type_code in ('OFFICE','CLINIC','PACE_CENTER') then 'in_person'
            when appt.location_type_code in ('TELE','TELEHEALTH','VIDEO') then 'telehealth'
            when appt.location_type_code in ('HOME','HOME_VISIT') then 'home_visit'
            when appt.location_type_code in ('HOSP','HOSPITAL','INPATIENT') then 'inpatient'
            when appt.location_type_code in ('SNF','SKILLED_NF') then 'skilled_nursing'
            else 'other'
        end as care_setting,

        -- Scheduling metrics
        cast(appt.appointment_datetime as date) = appt.scheduled_date
            as is_same_day_scheduled,

        datediff(
            'day',
            appt.created_at,
            appt.appointment_datetime
        ) as days_from_creation_to_appointment,

        -- Flags
        case
            when appt.appointment_type_code in ('IDT','IDT_CARE_CONF')
                 and appt.attendance_status_code not in ('PRESENT','ATTENDED','COMP')
            then true else false
        end as is_missed_idt,

        case
            when appt.attendance_status_code in ('NS','NO_SHOW','NOSHOW')
                 and appt.appointment_datetime < ts.now_ts
            then true else false
        end as is_confirmed_no_show

    from silver_appointment appt
    cross join current_ts ts
),

-- ============================================================
-- Final model
-- ============================================================
final as (

    select

        -- Keys
        appt.appointment_id,
        appt.appointment_source_id,
        appt.participant_id,
        appt.provider_id,
        appt.organization_id,

        -- Core
        appt.appointment_datetime,
        appt.appointment_date,
        appt.appointment_time,
        appt.scheduled_date,
        appt.appointment_duration_minutes,
        appt.appointment_type_code,
        appt.appointment_type_description,
        appt.appointment_category,
        appt.care_setting,
        appt.location_type_code,
        appt.location_name,

        -- Attendance
        appt.attendance_status_code,
        appt.attendance_status_description,
        appt.attendance_status_normalized,
        appt.is_confirmed_no_show,
        appt.is_missed_idt,

        -- Scheduling
        appt.is_same_day_scheduled,
        appt.days_from_creation_to_appointment,
        appt.cancellation_reason_code,
        appt.cancellation_reason_description,
        appt.reschedule_reason_code,

        -- Participant
        pt.participant_first_name,
        pt.participant_last_name,
        pt.participant_full_name,
        pt.date_of_birth,
        pt.enrollment_status as participant_enrollment_status,
        pt.primary_pace_center_id,
        pt.primary_care_team_id,
        pt.medicaid_number,
        pt.medicare_number,
        pt.is_active_enrollee,

        -- Provider
        prov.provider_full_name,
        prov.provider_type_code,
        prov.provider_specialty_code,
        prov.npi_number,
        prov.is_active_provider,

        -- Organization
        org.organization_name,
        org.pace_center_name,
        org.address_city  as pace_center_city,
        org.address_state as pace_center_state,

        -- Caregiver
        cg.caregiver_id   as primary_caregiver_id,
        cg.caregiver_full_name as primary_caregiver_full_name,

        -- Audit
        appt.created_at,
        appt.updated_at,
        appt.source_system,
        appt.silver_loaded_at,
        appt.now_ts as int_loaded_at

    from appointment_classified appt

    left join silver_participant pt
        on appt.participant_id = pt.participant_id

    left join silver_provider prov
        on appt.provider_id = prov.provider_id

    left join silver_organization org
        on appt.organization_id = org.organization_id

    left join primary_caregiver cg
        on appt.participant_id = cg.participant_id
)

select * from final