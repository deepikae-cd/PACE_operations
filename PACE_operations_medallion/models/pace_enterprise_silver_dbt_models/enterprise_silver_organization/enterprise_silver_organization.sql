/*
  ENTERPRISE_SILVER_ORGANIZATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_organization', 'RAW_ORGANIZATION_SERVICE_AREA') }}

  Purpose : Cleanse, deduplicate, and standardise organization, center,
            and service area data for PACE operations.
            Normalises organization type, contract status, and service attributes.

  Grain   : One record per organization_id + center_id + service_area_id (latest)
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ source('bronze_organization', 'RAW_ORGANIZATION_SERVICE_AREA') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by organization_id, center_id, service_area_id
               order by _loaded_at desc
           ) as _rn
    from source
    where organization_id is not null

),

cleaned as (

    select
        -- ✅ Surrogate key
        sha2(
            concat_ws('||',
                organization_id,
                center_id,
                service_area_id,
                cast(_loaded_at as varchar)
            )
        ) as organization_sk,

        -- ✅ Organization
        trim(upper(organization_id))        as organization_id,
        trim(organization_name)             as organization_name,

        case
            when upper(trim(organization_type)) in
                ('PACE','HOSPITAL','CLINIC','GROUP','OTHER')
            then upper(trim(organization_type))
            else 'UNKNOWN'
        end as organization_type,

        trim(upper(parent_organization_id)) as parent_organization_id,
        trim(tax_id)                        as tax_id,
        trim(npi_number)                    as npi_number,

        trim(cms_certification_number)      as cms_certification_number,
        trim(state_license_number)          as state_license_number,

        case
            when upper(trim(accreditation_status)) in
                ('ACTIVE','EXPIRED','PENDING')
            then upper(trim(accreditation_status))
            else 'UNKNOWN'
        end as accreditation_status,

        trim(accreditation_body)            as accreditation_body,
        accreditation_expiry_date,

        -- ✅ Center
        trim(upper(center_id))              as center_id,
        trim(center_name)                   as center_name,
        trim(center_address_line1)          as center_address_line1,
        trim(center_address_line2)          as center_address_line2,
        trim(center_city)                   as center_city,
        upper(trim(center_state))           as center_state,
        left(regexp_replace(center_zip_code, '[^0-9]', ''), 5) as center_zip_code,
        trim(center_county)                 as center_county,

        regexp_replace(center_phone, '[^0-9+]', '') as center_phone,
        regexp_replace(center_fax, '[^0-9+]', '')   as center_fax,
        lower(trim(center_email))                   as center_email,

        trim(center_operating_hours)       as center_operating_hours,
        coalesce(center_capacity, 0)       as center_capacity,

        case
            when upper(trim(center_status)) in
                ('ACTIVE','INACTIVE','CLOSED')
            then upper(trim(center_status))
            else 'UNKNOWN'
        end as center_status,

        -- ✅ Service Area
        trim(upper(service_area_id)) as service_area_id,
        trim(service_area_name)      as service_area_name,
        trim(service_area_type)      as service_area_type,

        coalesce(coverage_radius_miles, 0) as coverage_radius_miles,
        trim(zip_codes_served)       as zip_codes_served,
        trim(counties_served)        as counties_served,
        upper(trim(state_served))    as state_served,

        coalesce(population_served, 0)    as population_served,
        coalesce(eligible_population, 0) as eligible_population,
        coalesce(enrolled_count, 0)      as enrolled_count,
        coalesce(enrollment_capacity, 0) as enrollment_capacity,

        -- ✅ Contract
        contract_start_date,
        contract_end_date,

        case
            when upper(trim(contract_status)) in
                ('ACTIVE','EXPIRED','TERMINATED')
            then upper(trim(contract_status))
            else 'UNKNOWN'
        end as contract_status,

        -- ✅ Services
        trim(services_offered) as services_offered,

        coalesce(transportation_available, false) as transportation_available,
        coalesce(meal_service_available, false)   as meal_service_available,
        coalesce(pharmacy_on_site, false)         as pharmacy_on_site,
        coalesce(adult_day_care, false)           as adult_day_care,
        coalesce(home_care_available, false)      as home_care_available,
        coalesce(inpatient_partnership, false)    as inpatient_partnership,

        trim(specialty_services) as specialty_services,

        -- ✅ Contacts
        trim(primary_contact_name)  as primary_contact_name,
        trim(primary_contact_title) as primary_contact_title,
        regexp_replace(primary_contact_phone, '[^0-9+]', '') as primary_contact_phone,
        lower(trim(primary_contact_email)) as primary_contact_email,

        trim(medical_director_name) as medical_director_name,
        trim(medical_director_npi)  as medical_director_npi,

        -- ✅ Agreements
        trim(fiscal_intermediary)   as fiscal_intermediary,
        trim(medicare_agreement_id) as medicare_agreement_id,
        trim(medicaid_agreement_id) as medicaid_agreement_id,

        trim(funding_model)         as funding_model,
        coalesce(capitation_rate_monthly, 0) as capitation_rate_monthly,

        last_cms_audit_date,
        last_state_audit_date,
        quality_rating,

        -- ✅ Metadata
        upper(trim(source_system)) as source_system,
        _loaded_at                as loaded_timestamp,
        current_timestamp()       as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned