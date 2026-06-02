with src as (

    select *
    from {{ source('bronze', 'meal_delivery_raw') }}
    where meal_id        is not null
      and participant_id is not null
      and delivery_date  is not null
      and status         is not null

)

select
    meal_id                       as meal_delivery_id,
    participant_id,
    delivery_date,
    upper(trim(meal_type))        as meal_type,
    upper(trim(status))           as meal_status,
    created_ts                    as source_created_ts,
    current_timestamp()           as load_ts,
    'meal_delivery'               as source_system,
    md5(concat(
        coalesce(cast(meal_id        as string), ''),
        coalesce(cast(participant_id as string), ''),
        coalesce(cast(delivery_date  as string), ''),
        coalesce(upper(trim(meal_type)),         ''),
        coalesce(upper(trim(status)),            '')
    ))                            as record_hash

from src

qualify row_number() over (
    partition by meal_id
    order by created_ts desc
) = 1