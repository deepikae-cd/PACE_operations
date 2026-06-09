with base as (

    select *
    from {{ ref('enterprise_silver_appointment') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by appointment_id
               order by loaded_timestamp desc
           ) as _rn
    from base

)

select *
from deduplicated
where _rn = 1