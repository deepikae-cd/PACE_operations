/*
  ENTERPRISE_SILVER_ORGANIZATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('staging_organization') }}
  Purpose : Cleanse, deduplicate and enrich organization and service area
            records. Adds surrogate key, standardised vocabularies, computed
            flags for: accreditation status, contract lifecycle, enrollment
            capacity utilisation, audit recency, service capability profile,
            and regulatory compliance signals.
  ──────────────────────────────────────────────────────────────────────────────
  Note    : Organization/center data is low-volume reference data.
            Materialised as table (full refresh) to ensure all downstream
            models always join to a complete and current org profile.
  ──────────────────────────────────────────────────────────────────────────────
*/


with source as (

    select * from {{ ref('staging_organization') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by organization_id, center_id, service_area_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||',
            organization_id,
            center_id,
            coalesce(service_area_id, 'NO_SA'),
            cast(_loaded_at as varchar)
        )) as organization_sa_sk,

        -- Keys
        trim(upper(organization_id))        as organization_id,
        trim(upper(parent_organization_id)) as parent_organization_id,
        trim(upper(center_id))              as center_id,
        trim(upper(service_area_id))        as service_area_id,

        (parent_organization_id is not null) as is_child_organization_flag,

        -- Identity
        initcap(trim(organization_name)) as organization_name,
        trim(upper(organization_type))   as organization_type,
        trim(upper(tax_id))              as tax_id,
        trim(upper(npi_number))          as npi_number,
        trim(upper(cms_certification_number)) as cms_certification_number,
        trim(upper(state_license_number)) as state_license_number,

        -- Accreditation
        case
            when upper(trim(accreditation_status)) in
                ('ACCREDITED','PROVISIONAL','PENDING','EXPIRED','REVOKED')
            then upper(trim(accreditation_status))
            when accreditation_status is null then 'UNKNOWN'
            else 'OTHER'
        end as accreditation_status,

        trim(accreditation_body) as accreditation_body,
        accreditation_expiry_date,

        (upper(trim(accreditation_status)) = 'ACCREDITED') as is_accredited_flag,

        (accreditation_expiry_date is not null
         and accreditation_expiry_date < current_date()) as is_accreditation_expired_flag,

        (accreditation_expiry_date is not null
         and accreditation_expiry_date between current_date() and dateadd('day', 90, current_date()))
        as is_accreditation_expiring_soon_flag,

        -- Center
        initcap(trim(center_name)) as center_name,
        trim(center_address_line1) as center_address_line1,
        trim(center_address_line2) as center_address_line2,
        initcap(trim(center_city)) as center_city,
        trim(upper(center_state))  as center_state,
        trim(center_zip_code)      as center_zip_code,
        initcap(trim(center_county)) as center_county,

        trim(
            center_address_line1
            || case when center_address_line2 is not null
               then ', ' || center_address_line2 else '' end
            || ', ' || initcap(trim(center_city))
            || ', ' || upper(trim(center_state))
            || ' '  || trim(center_zip_code)
        ) as center_full_address,

        trim(center_phone) as center_phone,
        trim(center_fax)   as center_fax,
        trim(lower(center_email)) as center_email,
        trim(center_operating_hours) as center_operating_hours,
        center_capacity,

        case
            when upper(trim(center_status)) in
                ('ACTIVE','INACTIVE','PENDING','SUSPENDED','CLOSED')
            then upper(trim(center_status))
            when center_status is null then 'UNKNOWN'
            else 'OTHER'
        end as center_status,

        (upper(trim(center_status)) = 'ACTIVE') as is_center_active_flag,

        -- Service area
        initcap(trim(service_area_name)) as service_area_name,
        trim(upper(service_area_type))   as service_area_type,
        coverage_radius_miles,
        zip_codes_served,
        counties_served,
        trim(upper(state_served)) as state_served,

        -- Population
        population_served,
        eligible_population,
        enrolled_count,
        enrollment_capacity,

        case
            when enrollment_capacity > 0
            then round(enrolled_count / enrollment_capacity, 4)
        end as enrollment_utilisation_rate,

        case
            when enrollment_capacity is null or enrollment_capacity = 0 then 'UNKNOWN'
            when enrolled_count >= enrollment_capacity then 'AT_CAPACITY'
            when enrolled_count >= enrollment_capacity * 0.9 then 'NEAR_CAPACITY'
            when enrolled_count >= enrollment_capacity * 0.5 then 'MODERATE'
            else 'LOW_UTILISATION'
        end as enrollment_capacity_status,

        (enrolled_count >= enrollment_capacity) as is_at_capacity_flag,

        case
            when eligible_population is not null and enrolled_count is not null
            then eligible_population - enrolled_count
        end as eligible_not_enrolled_count,

        -- Contract
        contract_start_date,
        contract_end_date,

        case
            when upper(trim(contract_status)) in
                ('ACTIVE','PENDING','EXPIRED','TERMINATED','RENEWAL_IN_PROGRESS')
            then upper(trim(contract_status))
            when contract_status is null then 'UNKNOWN'
            else 'OTHER'
        end as contract_status,

        (upper(trim(contract_status)) = 'ACTIVE') as is_contract_active_flag,

        (contract_end_date is not null
         and contract_end_date between current_date() and dateadd('day', 90, current_date()))
        as is_contract_expiring_soon_flag,

        case
            when contract_start_date is not null and contract_end_date is not null
            then datediff('day', contract_start_date, contract_end_date)
        end as contract_duration_days,

        -- Services
        coalesce(transportation_available, false) as is_transportation_available_flag,
        coalesce(meal_service_available, false)   as is_meal_service_available_flag,
        coalesce(pharmacy_on_site, false)         as is_pharmacy_on_site_flag,
        coalesce(adult_day_care, false)           as is_adult_day_care_flag,
        coalesce(home_care_available, false)      as is_home_care_available_flag,
        coalesce(inpatient_partnership, false)    as is_inpatient_partnership_flag,

        (
            coalesce(cast(transportation_available as integer), 0)
          + coalesce(cast(meal_service_available as integer), 0)
          + coalesce(cast(pharmacy_on_site as integer), 0)
          + coalesce(cast(adult_day_care as integer), 0)
          + coalesce(cast(home_care_available as integer), 0)
          + coalesce(cast(inpatient_partnership as integer), 0)
        ) as core_service_count,

        trim(services_offered)   as services_offered,
        trim(specialty_services) as specialty_services,

        -- Contacts
        initcap(trim(primary_contact_name)) as primary_contact_name,
        trim(primary_contact_title)         as primary_contact_title,
        trim(primary_contact_phone)         as primary_contact_phone,
        trim(lower(primary_contact_email))  as primary_contact_email,
        initcap(trim(medical_director_name)) as medical_director_name,
        trim(upper(medical_director_npi))    as medical_director_npi,

        -- Regulatory
        trim(fiscal_intermediary)          as fiscal_intermediary,
        trim(upper(medicare_agreement_id)) as medicare_agreement_id,
        trim(upper(medicaid_agreement_id)) as medicaid_agreement_id,
        trim(upper(funding_model))         as funding_model,
        capitation_rate_monthly,
        last_cms_audit_date,
        last_state_audit_date,

        (last_cms_audit_date is null
         or last_cms_audit_date < dateadd('year', -1, current_date()))
         as is_cms_audit_overdue_flag,

        (last_state_audit_date is null
         or last_state_audit_date < dateadd('year', -1, current_date()))
         as is_state_audit_overdue_flag,

        datediff('day', last_cms_audit_date, current_date()) as days_since_cms_audit,
        datediff('day', last_state_audit_date, current_date()) as days_since_state_audit,

        -- Quality
        quality_rating,
        case
            when quality_rating is null then 'UNRATED'
            when quality_rating >= 4.5 then 'EXCELLENT'
            when quality_rating >= 3.5 then 'GOOD'
            when quality_rating >= 2.5 then 'AVERAGE'
            else 'BELOW_AVERAGE'
        end as quality_rating_tier,

        -- Metadata
        upper(trim(source_system)) as source_system,
        _loaded_at as loaded_timestamp,
        _source_file as source_file,
        current_timestamp() as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned