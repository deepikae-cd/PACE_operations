/*
  MODEL: FCT_MEAL_DELIVERY
  ───────────────────────────────────────────────────────────────
  PURPOSE:
    This model creates the core fact table for meal delivery events.
    It captures delivery outcomes, operational KPIs, and compliance metrics.

  GRAIN:
    1 row per delivery_id (latest record only)

  LOGIC:
    1. Source data from enterprise_silver_meal_delivery
    2. Incremental load based on loaded_timestamp
    3. Deduplicate using row_number (latest per delivery_id)
    4. Generate surrogate key
    5. Standardize KPI flags and metrics

  USED FOR:
    - Delivery performance dashboards
    - Compliance reporting
    - Caregiver/vendor analysis
    - SLA tracking (late deliveries)

  NOTES:
    - Incremental logic ensures only new data is processed
    - Clustered for Snowflake performance optimization
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

        -- KPI flags from silver layer
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

    {% if is_incremental() %}
        -- Only process new records
        where loaded_timestamp > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    /*
      Deduplicate records:
      Keep latest record per delivery_id based on loaded_timestamp
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

    /*
      Surrogate Key:
      Ensures uniqueness across versions of the same delivery_id
    */
    sha2(concat_ws('||', delivery_id, cast(loaded_timestamp as varchar))) as meal_delivery_sk,

    -- Business Keys
    delivery_id,
    participant_id,
    delivery_caregiver_id,
    vendor_id,

    -- Dimensions
    meal_type,
    delivery_status,
    delivery_type,
    temperature_on_delivery,

    -- Dates
    delivery_date,
    delivered_at,

    -- Metrics
    calorie_count,
    hours_after_meal_date,

    /*
      KPI FLAGS:
      Defaulted to FALSE for consistency
    */
    coalesce(is_delivered_flag, false) as is_delivered_flag,
    coalesce(is_not_delivered_flag, false) as is_not_delivered_flag,
    coalesce(is_refused_flag, false) as is_refused_flag,
    coalesce(is_partial_delivery_flag, false) as is_partial_delivery_flag,
    coalesce(is_delivery_compliant_flag, false) as is_delivery_compliant_flag,
    coalesce(is_temperature_noncompliant_flag, false) as is_temperature_noncompliant_flag,
    coalesce(is_late_delivery_flag, false) as is_late_delivery_flag,
    coalesce(is_accepted_flag, false) as is_accepted_flag,
    coalesce(is_participant_refused_flag, false) as is_participant_refused_flag,

    /*
      Backward compatibility metric
    */
    case
        when delivery_status = 'DELIVERED' then 1
        else 0
    end as delivered_flag,

    -- Metadata
    loaded_timestamp,
    current_timestamp() as dbt_loaded_at

from deduplicated
where row_num = 1