
/*
  ENTERPRISE_SILVER_MEAL_DELIVERY
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ source('bronze_meal_delivery', 'RAW_MEAL_DELIVERY') }}
  Purpose : Cleanse, cast, deduplicate meal-delivery records.
  ──────────────────────────────────────────────────────────────────────────────
*/

with source as (

    select * from {{ source('bronze_meal_delivery', 'RAW_MEAL_DELIVERY') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by meal_delivery_id
               order by _loaded_at desc
           ) as _rn
    from source
    where meal_delivery_id is not null
      and participant_id   is not null
      and meal_date        is not null

),

cleaned as (

    select
        sha2(concat_ws('||', meal_delivery_id, cast(_loaded_at as varchar))) as meal_delivery_sk,
        trim(upper(meal_delivery_id))     as meal_delivery_id,
        trim(upper(participant_id))       as participant_id,

        -- ✅ SAFE (date casting is okay)
        try_cast(meal_date as date)       as meal_date,

        trim(upper(center_id))            as center_id,
        trim(upper(meal_plan_id))         as meal_plan_id,

        -- Type
        case
            when upper(trim(meal_type)) in
                ('BREAKFAST','LUNCH','DINNER','SNACK') then upper(trim(meal_type))
            when meal_type is null then 'UNKNOWN'
            else 'UNKNOWN'
        end as meal_type,

        trim(dietary_restriction) as dietary_restriction,

        -- Numeric cast ✅ safe
        coalesce(try_cast(calorie_count as number(6,0)), 0) as calorie_count,

        case
            when upper(trim(delivery_type)) in
                ('HOME_DELIVERY','CENTER_SERVED','FAMILY_PROVIDED')
            then upper(trim(delivery_type))
            when delivery_type is null then 'UNKNOWN'
            else 'OTHER'
        end as delivery_type,

        case
            when upper(trim(delivery_status)) in
                ('DELIVERED','NOT_DELIVERED','REFUSED','PARTIAL')
            then upper(trim(delivery_status))
            when delivery_status is null then 'UNKNOWN'
            else 'UNKNOWN'
        end as delivery_status,

        (upper(trim(delivery_status)) = 'DELIVERED') as is_delivered,

        trim(refused_reason) as refused_reason,

        -- ✅ ✅ FIX: REMOVED timestamp casting
        delivered_at,

        trim(upper(delivery_caregiver_id)) as delivery_caregiver_id,
        trim(upper(vendor_id))             as vendor_id,

        -- Temperature compliance
        (upper(trim(temperature_on_delivery)) not like '%NON%'
         and upper(trim(temperature_on_delivery)) not like '%FAIL%'
         and temperature_on_delivery is not null
        ) as temperature_compliant,

        case
            when upper(trim(participant_acceptance)) in
                ('ACCEPTED','REFUSED','PARTIAL')
            then upper(trim(participant_acceptance))
            else 'UNKNOWN'
        end as participant_acceptance,

        trim(notes) as notes,

        upper(trim(source_system)) as source_system,
        _loaded_at as loaded_at,
        current_timestamp() as dbt_updated_at

    from deduplicated
    where _rn = 1

)

select * from cleaned