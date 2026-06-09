with source_data as (

    select
        meal_delivery_id as delivery_id,
        participant_id,
        meal_type,
        delivery_caregiver_id,
        vendor_id,
        meal_date as delivery_date,
        delivery_status,
        loaded_timestamp
    from {{ ref('enterprise_silver_meal_delivery') }}

),

deduplicated as (

    select
        delivery_id,
        participant_id,
        meal_type,
        delivery_caregiver_id,
        vendor_id,
        delivery_date,
        delivery_status,
        loaded_timestamp,

        row_number() over (
            partition by delivery_id
            order by
                loaded_timestamp desc,
                participant_id,
                meal_type
        ) as row_num

    from source_data

)

select
    delivery_id,
    participant_id,
    meal_type,
    delivery_caregiver_id,
    vendor_id,
    delivery_date,
    delivery_status,

    case
        when delivery_status = 'DELIVERED' then 1
        else 0
    end as delivered_flag,
    loaded_timestamp   

from deduplicated
where row_num = 1
