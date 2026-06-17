/*
===============================================================================
Model: fct_medication
Purpose:
  Captures medication prescription and lifecycle data for participants.

Grain:
  One row per medication_id
===============================================================================
*/

with source as (

    select *
    from {{ ref('staging_medication') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by medication_id
               order by _loaded_at desc
           ) as _rn
    from source

),

final as (

    select

        -- 🔑 Keys
        trim(upper(medication_id)) as medication_id,
        trim(upper(participant_id)) as participant_id,
        trim(upper(provider_id)) as provider_id,
        trim(upper(center_id)) as center_id,
        trim(upper(visit_id)) as visit_id,

        -- 💊 Drug identity
        trim(upper(medication_name)) as medication_name,
        trim(upper(generic_name)) as generic_name,
        trim(upper(drug_class)) as drug_class,

        -- 💉 Dosage
        dosage,
        dosage_unit,
        frequency,
        route_of_administration,

        -- 📅 Lifecycle
        prescribed_date,
        start_date,
        end_date,

        date_trunc('day', prescribed_date) as prescribed_day,

        trim(upper(medication_status)) as medication_status,

        days_supply,
        dispensed_quantity,

        -- 🔁 refill metrics
        refills_authorized,
        refills_remaining,
        last_refill_date,

        -- 🚩 Flags
        coalesce(is_controlled_substance, false) as is_controlled_substance,
        coalesce(prior_authorization_required, false) as is_pa_required,
        coalesce(is_pace_formulary, false) as is_formulary,

        -- Derived flags
        (refills_remaining = 0) as is_refill_required_flag,

        -- 💰 Cost
        cost_per_unit,
        total_cost,

        -- Metadata
        source_system,
        _loaded_at as loaded_timestamp,
        current_timestamp() as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from final