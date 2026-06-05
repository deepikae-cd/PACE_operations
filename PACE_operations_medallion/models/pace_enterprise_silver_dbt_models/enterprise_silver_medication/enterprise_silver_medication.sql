/*
  ENTERPRISE_SILVER_MEDICATION
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('staging_medication') }}
  Purpose : Cleanse, deduplicate and enrich medication records.
            Adds surrogate key, standardised vocabularies, computed flags for:
            active/expired prescriptions, refill urgency, controlled substance
            risk, prior auth status, formulary compliance, interaction alerts,
            and cost classification.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ ref('staging_medication') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by medication_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||', medication_id, cast(_loaded_at as varchar))) as medication_sk,

        -- Keys
        trim(upper(medication_id))   as medication_id,
        trim(upper(participant_id))  as participant_id,
        trim(upper(provider_id))     as provider_id,
        trim(upper(visit_id))        as visit_id,
        trim(upper(pharmacy_id))     as pharmacy_id,
        trim(upper(center_id))       as center_id,

        -- Drug identity
        initcap(trim(medication_name)) as medication_name,
        initcap(trim(generic_name))    as generic_name,
        initcap(trim(brand_name))      as brand_name,
        trim(upper(ndc_code))          as ndc_code,
        initcap(trim(drug_class))      as drug_class,

        -- Dosage
        trim(dosage)                         as dosage,
        trim(upper(dosage_unit))            as dosage_unit,
        trim(upper(frequency))              as frequency,
        trim(upper(route_of_administration)) as route_of_administration,

        -- ✅ DATE fields (consistent)
        to_date(prescribed_date) as prescribed_date,
        to_date(start_date)      as start_date,
        to_date(end_date)        as end_date,

        -- ✅ KEEP TIMESTAMP (DO NOT CAST)
        last_refill_date,

        -- Status
        case
            when upper(trim(medication_status)) in (
                'ACTIVE','DISCONTINUED','COMPLETED',
                'ON_HOLD','CANCELLED','EXPIRED'
            ) then upper(trim(medication_status))
            when medication_status is null then 'UNKNOWN'
            else 'OTHER'
        end as medication_status,

        -- Flags
        (upper(trim(medication_status)) = 'ACTIVE')       as is_active_flag,
        (upper(trim(medication_status)) = 'DISCONTINUED') as is_discontinued_flag,
        (upper(trim(medication_status)) = 'ON_HOLD')      as is_on_hold_flag,

        -- ✅ DATE-based lifecycle logic
        case
            when start_date is not null
             and (end_date is null or end_date >= current_date())
             and upper(trim(medication_status)) = 'ACTIVE'
            then true else false
        end as is_currently_active_flag,

        case
            when end_date is not null
             and end_date < current_date()
             and upper(trim(medication_status)) = 'ACTIVE'
            then true else false
        end as is_stale_active_flag,

        case
            when end_date is not null and end_date >= current_date()
            then datediff('day', current_date(), end_date)
        end as days_until_expiry,

        -- Refills
        refills_authorized,
        refills_remaining,
        days_supply,
        dispensed_quantity,

        (refills_remaining = 0) as is_refills_exhausted_flag,

        -- ✅ Safe usage of timestamp
        case
            when last_refill_date is not null
             and days_supply is not null
             and datediff('day', last_refill_date::date, current_date()) >= (days_supply - 7)
            then true else false
        end as is_refill_due_soon_flag,

        -- Pharmacy
        initcap(trim(pharmacy_name)) as pharmacy_name,
        trim(upper(pharmacy_npi))    as pharmacy_npi,
        trim(pharmacy_phone)         as pharmacy_phone,
        trim(pharmacy_address)       as pharmacy_address,

        -- Controlled substance
        coalesce(is_controlled_substance, false) as is_controlled_substance_flag,
        trim(upper(dea_schedule)) as dea_schedule,

        (
            is_controlled_substance = true
            and upper(trim(dea_schedule)) = 'II'
        ) as is_high_risk_controlled_flag,

        -- Prior auth
        coalesce(prior_authorization_required, false) as is_prior_auth_required_flag,

        case
            when upper(trim(prior_authorization_status)) in
                ('APPROVED','PENDING','DENIED','NOT_REQUIRED')
            then upper(trim(prior_authorization_status))
            when prior_authorization_required = false then 'NOT_REQUIRED'
            when prior_authorization_status is null then 'UNKNOWN'
            else 'OTHER'
        end as prior_authorization_status,

        (
            prior_authorization_required = true
            and upper(trim(prior_authorization_status)) in ('PENDING','DENIED')
        ) as is_prior_auth_at_risk_flag,

        -- Clinical safety
        (trim(coalesce(adverse_reactions, '')) != '') as has_adverse_reactions_flag,
        (trim(coalesce(contraindications, '')) != '') as has_contraindications_flag,
        (trim(coalesce(interaction_alerts, '')) != '') as has_interaction_alerts_flag,

        trim(adverse_reactions)           as adverse_reactions,
        trim(contraindications)           as contraindications,
        trim(interaction_alerts)          as interaction_alerts,
        trim(administration_instructions) as administration_instructions,
        trim(special_handling_notes)      as special_handling_notes,

        -- Formulary
        coalesce(is_pace_formulary, false) as is_pace_formulary_flag,
        trim(upper(formulary_tier)) as formulary_tier,

        (coalesce(is_pace_formulary, false) = false) as is_off_formulary_flag,

        -- Cost
        cost_per_unit,
        total_cost,

        case
            when total_cost is null then 'UNKNOWN'
            when total_cost = 0 then 'ZERO_COST'
            when total_cost < 50 then 'LOW'
            when total_cost <= 500 then 'MEDIUM'
            else 'HIGH'
        end as cost_tier,

        case
            when upper(trim(coverage_type)) in (
                'MEDICARE','MEDICAID','PACE_PLAN',
                'PATIENT_PAY','GRANT','UNINSURED'
            ) then upper(trim(coverage_type))
            when coverage_type is null then 'UNKNOWN'
            else 'OTHER'
        end as coverage_type,

        -- Metadata
        upper(trim(source_system)) as source_system,
        _loaded_at                as loaded_timestamp,
        _source_file              as source_file,
        current_timestamp()       as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned
