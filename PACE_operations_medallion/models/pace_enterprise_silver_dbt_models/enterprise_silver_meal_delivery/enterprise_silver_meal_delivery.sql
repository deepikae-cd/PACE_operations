/*
  ENTERPRISE_SILVER_MEAL_DELIVERY
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('staging_meal_delivery') }}
  Purpose : Cleanse, deduplicate and enrich meal delivery records.
            Adds surrogate key, standardised vocabularies, computed flags
            for delivery compliance, temperature safety, participant
            acceptance, and on-time delivery metrics.
  ──────────────────────────────────────────────────────────────────────────────
*/


with source as (

    select * from {{ ref('staging_meal_delivery') }}

    {% if is_incremental() %}
        where _loaded_at > (select max(loaded_timestamp) from {{ this }})
    {% endif %}

),

deduplicated as (

    select *,
           row_number() over (
               partition by meal_delivery_id
               order by _loaded_at desc
           ) as _rn
    from source

),

cleaned as (

    select
        -- Surrogate key
        sha2(concat_ws('||', meal_delivery_id, cast(_loaded_at as varchar))) as meal_delivery_sk,

        -- Natural keys (normalised)
        trim(upper(meal_delivery_id))        as meal_delivery_id,
        trim(upper(participant_id))          as participant_id,
        trim(upper(meal_plan_id))            as meal_plan_id,
        trim(upper(delivery_caregiver_id))   as delivery_caregiver_id,
        trim(upper(vendor_id))               as vendor_id,
        trim(upper(center_id))               as center_id,

        -- Meal type (controlled vocabulary)
        case
            when upper(trim(meal_type)) in
                ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK')
            then upper(trim(meal_type))
            when meal_type is null then 'UNKNOWN'
            else 'OTHER'
        end as meal_type,

        -- Dietary restriction (controlled vocabulary)
        case
            when upper(trim(dietary_restriction)) in (
                'LOW_SODIUM', 'DIABETIC', 'PUREED', 'KOSHER',
                'HALAL', 'VEGETARIAN', 'VEGAN', 'RENAL', 'LOW_FAT'
            ) then upper(trim(dietary_restriction))
            when dietary_restriction is null then 'NO_RESTRICTION'
            else 'OTHER'
        end as dietary_restriction,

        -- Special dietary need flag (requires specific meal prep)
        (
            upper(trim(dietary_restriction)) in (
                'PUREED', 'RENAL', 'DIABETIC', 'LOW_SODIUM'
            )
        ) as is_clinical_dietary_need_flag,

        calorie_count,

        -- Calorie range flag (typical adult 400-900 per meal)
        case
            when calorie_count is null                          then 'UNKNOWN'
            when calorie_count < 200                           then 'VERY_LOW'
            when calorie_count between 200 and 399             then 'LOW'
            when calorie_count between 400 and 900             then 'NORMAL'
            when calorie_count > 900                           then 'HIGH'
        end as calorie_range,

        -- Delivery type (controlled vocabulary)
        case
            when upper(trim(delivery_type)) in
                ('HOME_DELIVERY', 'CENTER_SERVED', 'FAMILY_PROVIDED')
            then upper(trim(delivery_type))
            when delivery_type is null then 'UNKNOWN'
            else 'OTHER'
        end as delivery_type,

        -- Delivery status (controlled vocabulary)
        case
            when upper(trim(delivery_status)) in
                ('DELIVERED', 'NOT_DELIVERED', 'REFUSED', 'PARTIAL')
            then upper(trim(delivery_status))
            when delivery_status is null then 'UNKNOWN'
            else 'OTHER'
        end as delivery_status,

        -- Boolean delivery status flags
        (upper(trim(delivery_status)) = 'DELIVERED')     as is_delivered_flag,
        (upper(trim(delivery_status)) = 'NOT_DELIVERED') as is_not_delivered_flag,
        (upper(trim(delivery_status)) = 'REFUSED')       as is_refused_flag,
        (upper(trim(delivery_status)) = 'PARTIAL')       as is_partial_delivery_flag,

        -- Delivery compliance flag (DELIVERED or CENTER_SERVED = compliant)
        (
            upper(trim(delivery_status)) = 'DELIVERED'
            or upper(trim(delivery_type)) = 'CENTER_SERVED'
        ) as is_delivery_compliant_flag,

        trim(refused_reason) as refused_reason,

        -- Participant acceptance (controlled vocabulary)
        case
            when upper(trim(participant_acceptance)) in
                ('ACCEPTED', 'REFUSED', 'PARTIAL')
            then upper(trim(participant_acceptance))
            when participant_acceptance is null then 'UNKNOWN'
            else 'OTHER'
        end as participant_acceptance,

        -- Boolean acceptance flags
        (upper(trim(participant_acceptance)) = 'ACCEPTED') as is_accepted_flag,
        (upper(trim(participant_acceptance)) = 'REFUSED')  as is_participant_refused_flag,
        (upper(trim(participant_acceptance)) = 'PARTIAL')  as is_partial_acceptance_flag,

        -- Temperature compliance (food safety)
        case
            when upper(trim(temperature_on_delivery)) in
                ('HOT', 'COLD', 'AMBIENT')
            then upper(trim(temperature_on_delivery))
            when temperature_on_delivery is null then 'UNKNOWN'
            else 'OTHER'
        end as temperature_on_delivery,

        -- Temperature non-compliance flag (anything not HOT/COLD/AMBIENT is suspect)
        (
            temperature_on_delivery is not null
            and upper(trim(temperature_on_delivery)) not in ('HOT', 'COLD', 'AMBIENT')
        ) as is_temperature_noncompliant_flag,

        trim(notes) as notes,

        -- Dates & timestamps
        meal_date,
        delivered_at,

        -- Delivery delay in hours vs expected noon delivery window
        -- (PACE standard: meals delivered by 12:00 for lunch, 17:00 for dinner)
        case
            when delivered_at is not null and meal_date is not null
            then datediff('hour', meal_date::timestamp, delivered_at)
        end as hours_after_meal_date,

        -- Late delivery flag (delivered more than 2 hours after meal date start)
        case
            when delivered_at is not null and meal_date is not null
             and datediff('hour', meal_date::timestamp, delivered_at) > 2
            then true
            else false
        end as is_late_delivery_flag,

        -- Vendor-delivered flag (vs caregiver or center)
        (vendor_id is not null) as is_vendor_delivery_flag,

        -- Metadata
        upper(trim(source_system))  as source_system,
        _loaded_at                  as loaded_timestamp,
        _source_file                as source_file,
        current_timestamp()         as dbt_updated_timestamp

    from deduplicated
    where _rn = 1

)

select * from cleaned