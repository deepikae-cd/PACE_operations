with src as (

select *
from {{ source('bronze','caregiver_raw') }}

)

select
    caregiver_id,
    participant_id,
    upper(caregiver_name) as caregiver_name,
    relationship,
    regexp_replace(phone,'[^0-9]','') as phone,
    current_timestamp() as load_ts
from src
qualify row_number()
over(
partition by caregiver_id
order by caregiver_id
)=1