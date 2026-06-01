with source_data as (

    select *
    from {{ source('bronze','participant_raw') }}

),

cleaned as (

    select

        participant_id,

        upper(trim(first_name)) as first_name,

        upper(trim(last_name)) as last_name,

        lower(trim(email)) as email,

        regexp_replace(phone,'[^0-9]','') as phone,

        gender,

        case
            when status is null then 'ACTIVE'
            else upper(status)
        end as status,

        cast(created_ts as timestamp) as created_ts,

        current_timestamp() as load_ts

    from source_data

)

select *
from cleaned
qualify row_number()
over (
partition by participant_id
order by created_ts desc
)=1