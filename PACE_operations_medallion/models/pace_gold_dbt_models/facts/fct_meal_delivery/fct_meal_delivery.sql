select

    delivery_id,
    participant_id,

    delivery_date,
    meal_type,

    case when delivered = true then 1 else 0 end as delivered_flag

from {{ ref('staging_meal_delivery') }}