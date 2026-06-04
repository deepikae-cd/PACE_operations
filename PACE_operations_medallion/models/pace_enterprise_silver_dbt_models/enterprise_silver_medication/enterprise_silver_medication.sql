/*
  ENTERPRISE_SILVER_MEDICATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_medication', 'RAW_MEDICATION') }}

  Purpose : Cleanse, deduplicate, and standardise medication records.
            Normalises drug attributes, pharmacy data, and prescription lifecycle.
            Computes refill, adherence, and cost attributes.

  Grain   : One record per medication_id (latest version)
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ source('bronze_medication', 'RAW_MEDICATION') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by medication_id
               order by _loaded_at desc
           ) as _rn
    from source
    where medication_id  is not null
      and participant_id is not null

),

cleaned as (

    select
        -- Keys
        sha2(concat_ws('||', medication_id, cast(_loaded_at as varchar))) as medication_sk,
        trim(upper(medication_id))   as medication_id,
        trim(upper(participant_id))  as participant_id,
        trim(upper(provider_id))     as provider_id,
        trim(upper(visit_id))        as visit_id,

        -- Medication info
        trim(medication_name) as medication_name,
        trim(generic_name)    as generic_name,
        trim(brand_name)      as brand_name,
        trim(ndc_code)        as ndc_code,
        trim(drug_class)      as drug_class,

        trim(dosage)      as dosage,
        trim(dosage_unit) as dosage_unit,
        trim(frequency)   as frequency,
        trim(route_of_administration) as route,

        -- ✅ FIXED: timestamp → date using TO_DATE
        to_date(prescribed_date) as prescribed_date,
        to_date(start_date)      as start_date,
        to_date(end_date)        as end_date,

        -- Status normalization
        case
            when upper(trim(medication_status)) in
                ('ACTIVE','DISCONTINUED','ON_HOLD','COMPLETED')
            then upper(trim(medication_status))
            else 'UNKNOWN'
        end as medication_status,

        coalesce(refills_authorized, 0) as refills_authorized,
        coalesce(refills_remaining,  0) as refills_remaining,

        -- ✅ keep timestamp as-is (no casting)
        last_refill_date,

        -- Pharmacy info
        trim(pharmacy_name)        as pharmacy_name,
        trim(upper(pharmacy_id))   as pharmacy_id,
        trim(upper(pharmacy_npi))  as pharmacy_npi,
        regexp_replace(pharmacy_phone, '[^0-9+]', '') as pharmacy_phone,
        trim(pharmacy_address)     as pharmacy_address,

        -- Dispensing
        coalesce(dispensed_quantity, 0) as dispensed_quantity,
        coalesce(days_supply, 0)        as days_supply,

        coalesce(is_controlled_substance, false) as is_controlled_substance,
        trim(dea_schedule) as dea_schedule,

        coalesce(prior_authorization_required, false) as prior_auth_required_flag,

        case
            when upper(trim(prior_authorization_status)) in
                ('APPROVED','PENDING','DENIED')
            then upper(trim(prior_authorization_status))
            else 'UNKNOWN'
        end as prior_authorization_status,

        -- Clinical safety
        trim(adverse_reactions)  as adverse_reactions,
        trim(contraindications)  as contraindications,
        trim(interaction_alerts) as interaction_alerts,

        trim(administration_instructions) as administration_instructions,
        trim(special_handling_notes)      as special_handling_notes,

        -- Formulary
        coalesce(is_pace_formulary, false) as is_pace_formulary,
        trim(formulary_tier) as formulary_tier,

        -- Cost
        coalesce(cost_per_unit, 0) as cost_per_unit,
        coalesce(total_cost, 0)    as total_cost,
        trim(coverage_type)        as coverage_type,

        trim(upper(center_id)) as center_id,

        -- Metadata
        upper(trim(source_system)) as source_system,
        _loaded_at                as loaded_timestamp,
        current_timestamp()       as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned