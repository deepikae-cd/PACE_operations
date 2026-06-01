with src as (

    select *
    from {{ source('bronze','participant_raw') }}

)

select

    participant_id,

    upper(trim(first_name)) as first_name,

    upper(trim(last_name)) as last_name,

    gender,

    lower(email) as email,

    regexp_replace(phone,'[^0-9]','') as phone,

    coalesce(status,'ACTIVE') as participant_status,

    cast(created_ts as timestamp) as created_ts,

    current_timestamp() as load_ts

from src

qualify row_number()
over(
partition by participant_id
order by created_ts desc
)=1