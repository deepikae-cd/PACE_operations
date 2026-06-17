/*
  MODEL: FCT_MEAL_DELIVERY
  ───────────────────────────────────────────────────────────────
  PURPOSE:
    Builds a fact table for meal delivery events for analytics and reporting.

  GRAIN:
    1 row per delivery_id (latest record only)

  LOGIC:
    1. Read from enterprise_silver_meal_delivery
    2. Deduplicate using latest loaded_timestamp
    3. Generate surrogate key
    4. Standardize KPI flags

  NOTES:
    - Rebuilds fully on every run
*/

with source_data as (

    select
        -- Natural Keys
        meal_delivery_id as delivery_id,
        participant_id,
        delivery_caregiver_id,
        vendor_id,

        -- Attributes
        meal_type,
        delivery_status,
        delivery_type,
        temperature_on_delivery,

        -- Dates
        meal_date as delivery_date,
        delivered_at,

        -- Metrics
        calorie_count,
        hours_after_meal_date,

        -- KPI Flags (from silver)
        is_delivered_flag,
        is_not_delivered_flag,
        is_refused_flag,
        is_partial_delivery_flag,
        is_delivery_compliant_flag,
        is_temperature_noncompliant_flag,
        is_late_delivery_flag,
        is_accepted_flag,
        is_participant_refused_flag,

        -- Metadata
        loaded_timestamp

    from {{ ref('enterprise_silver_meal_delivery') }}

),

deduplicated as (

    /*
      Deduplicate:
      Keep latest record per delivery_id
    */
    select
        *,
        row_number() over (
            partition by delivery_id
            order by loaded_timestamp desc
        ) as row_num
    from source_data

)

select

    -- ✅ Surrogate Key
    sha2(concat_ws('||', delivery_id, cast(loaded_timestamp as varchar))) as meal_delivery_sk,

    -- ✅ Business Keys
    delivery_id,
    participant_id,
    delivery_caregiver_id,
    vendor_id,

    -- ✅ Dimensions
    meal_type,
    delivery_status,
    delivery_type,
    temperature_on_delivery,

    -- ✅ Dates
    delivery_date,
    delivered_at,

    -- ✅ Metrics
    calorie_count,
    hours_after_meal_date,

    -- ✅ KPI FLAGS (default false)
    coalesce(is_delivered_flag, false) as is_delivered_flag,
    coalesce(is_not_delivered_flag, false) as is_not_delivered_flag,
    coalesce(is_refused_flag, false) as is_refused_flag,
    coalesce(is_partial_delivery_flag, false) as is_partial_delivery_flag,
    coalesce(is_delivery_compliant_flag, false) as is_delivery_compliant_flag,
    coalesce(is_temperature_noncompliant_flag, false) as is_temperature_noncompliant_flag,
    coalesce(is_late_delivery_flag, false) as is_late_delivery_flag,
    coalesce(is_accepted_flag, false) as is_accepted_flag,
    coalesce(is_participant_refused_flag, false) as is_participant_refused_flag,

    -- ✅ Simple binary metric
    case
        when delivery_status = 'DELIVERED' then 1
        else 0
    end as delivered_flag,

    -- ✅ Metadata
    loaded_timestamp,
    current_timestamp() as dbt_loaded_at

from deduplicated
where row_num = 1
