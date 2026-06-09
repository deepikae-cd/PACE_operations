with base as (

    select
        meal_delivery_id as delivery_id,   
        participant_id,
        scheduled_delivery_date as delivery_date,

        delivery_status,
        _loaded_at

    from {{ ref('enterprise_silver_meal_delivery') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by delivery_id
               order by _loaded_at desc
           ) as _rn
    from base

)

select
    delivery_id,
    participant_id,
    delivery_date,
    delivery_status,

    case 
        when delivery_status = 'DELIVERED' then 1
        else 0
    end as delivered_flag

from deduplicated
where _rn = 1