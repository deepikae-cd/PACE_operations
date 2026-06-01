with src as (

select *
from {{ source('bronze','clinical_visit_raw') }}

)

select

    visit_id,

    participant_id,

    provider_id,

    visit_date,

    diagnosis_code,

    procedure_code,

    visit_status,

    current_timestamp() as load_ts

from src