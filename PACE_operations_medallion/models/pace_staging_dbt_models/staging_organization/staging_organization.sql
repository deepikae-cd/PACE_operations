/*
  STAGING_ORGANIZATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_organization', 'RAW_ORGANIZATION_SERVICE_AREA') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/
with source as (

    select
        -- Organization keys
        organization_id,
        parent_organization_id,
        center_id,
        service_area_id,

        -- Organization identity (raw)
        organization_name,
        organization_type,
        tax_id,
        npi_number,
        cms_certification_number,
        state_license_number,

        -- Accreditation (raw)
        accreditation_status,
        accreditation_body,
        accreditation_expiry_date,

        -- Center details (raw)
        center_name,
        center_address_line1,
        center_address_line2,
        center_city,
        center_state,
        center_zip_code,
        center_county,
        center_phone,
        center_fax,
        center_email,
        center_operating_hours,
        center_capacity,
        center_status,

        -- Service area (raw)
        service_area_name,
        service_area_type,
        coverage_radius_miles,
        zip_codes_served,
        counties_served,
        state_served,

        -- Population & enrollment (raw)
        population_served,
        eligible_population,
        enrolled_count,
        enrollment_capacity,

        -- Contract (raw)
        contract_start_date,
        contract_end_date,
        contract_status,

        -- Services (raw booleans + pipe-delimited)
        services_offered,
        transportation_available,
        meal_service_available,
        pharmacy_on_site,
        adult_day_care,
        home_care_available,
        inpatient_partnership,
        specialty_services,

        -- Contacts (raw)
        primary_contact_name,
        primary_contact_title,
        primary_contact_phone,
        primary_contact_email,
        medical_director_name,
        medical_director_npi,

        -- Regulatory & financial (raw)
        fiscal_intermediary,
        medicare_agreement_id,
        medicaid_agreement_id,
        funding_model,
        capitation_rate_monthly,
        last_cms_audit_date,
        last_state_audit_date,
        quality_rating,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_organization', 'RAW_ORGANIZATION_SERVICE_AREA') }}

),

filtered as (

    select *
    from source
    where organization_id is not null
      and center_id        is not null

)

select * from filtered