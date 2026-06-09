with base as (

    select *
    from {{ ref('enterprise_silver_meal_delivery') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by delivery_id
               order by loaded_timestamp desc
           ) as _rn
    from base

)

select *
from deduplicated
where _rn = 1