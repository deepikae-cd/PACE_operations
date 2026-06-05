/*
  STAGING_MEAL_DELIVERY
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_meal_delivery', 'RAW_MEAL_DELIVERY') }}
  Purpose : Thin staging layer — select, rename, and basic null filtering only.
            No business logic. Materialised as view to avoid storage cost.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select
        -- Keys
        meal_delivery_id,
        participant_id,
        meal_plan_id,
        delivery_caregiver_id,
        vendor_id,
        center_id,

        -- Meal descriptors (raw — no business logic here)
        meal_type,
        dietary_restriction,
        calorie_count,
        delivery_type,
        delivery_status,
        refused_reason,
        temperature_on_delivery,
        participant_acceptance,
        notes,

        -- Dates & timestamps
        meal_date,
        delivered_at,

        -- Metadata
        source_system,
        _loaded_at,
        _source_file

    from {{ source('bronze_meal_delivery', 'RAW_MEAL_DELIVERY') }}

),

filtered as (

    -- Drop records that can never be meaningful downstream
    select *
    from source
    where meal_delivery_id is not null
      and participant_id   is not null

)

select * from filtered