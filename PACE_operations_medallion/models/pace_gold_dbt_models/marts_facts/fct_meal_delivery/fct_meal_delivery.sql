select


    meal_delivery_id as delivery_id,
    participant_id,

    --  date column
    meal_date as delivery_date,
    meal_type,
    case 
        when delivery_status = 'delivered' then 1 
        else 0 
    end as delivered_flag

from {{ ref('stagig_meal_delivery') }}
