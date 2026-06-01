with src as (

select *
from {{ source('bronze','appointment_raw') }}

)

select

    appointment_id,

    participant_id,

    provider_id,

    appointment_date,

    appointment_type,

    case
        when status is null then 'SCHEDULED'
        else upper(status)
    end as appointment_status,

    current_timestamp() as load_ts

from src