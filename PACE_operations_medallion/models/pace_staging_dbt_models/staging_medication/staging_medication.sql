/*
  STAGING_MEDICATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_medication', 'RAW_MEDICATION') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/


with source as (

    select
        -- Keys
        medication_id,
        participant_id,
        provider_id,
        visit_id,
        pharmacy_id,
        center_id,

        -- Drug identity (raw — no normalisation here)
        medication_name,
        generic_name,
        brand_name,
        ndc_code,
        drug_class,

        -- Dosage (raw)
        dosage,
        dosage_unit,
        frequency,
        route_of_administration,

        -- Prescription lifecycle
        prescribed_date,
        start_date,
        end_date,
        medication_status,
        refills_authorized,
        refills_remaining,
        last_refill_date,
        days_supply,
        dispensed_quantity,

        -- Pharmacy
        pharmacy_name,
        pharmacy_npi,
        pharmacy_phone,
        pharmacy_address,

        -- Controlled substance
        is_controlled_substance,
        dea_schedule,

        -- Prior authorisation
        prior_authorization_required,
        prior_authorization_status,

        -- Clinical safety (raw)
        adverse_reactions,
        contraindications,
        interaction_alerts,
        administration_instructions,
        special_handling_notes,

        -- Formulary & cost
        is_pace_formulary,
        formulary_tier,
        cost_per_unit,
        total_cost,
        coverage_type,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_medication', 'RAW_MEDICATION') }}

),

filtered as (

    select *
    from source
    where medication_id  is not null
      and participant_id is not null

)

select * from filtered