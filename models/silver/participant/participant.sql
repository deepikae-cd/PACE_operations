select
    participant_id,
    first_name,
    last_name,
    dob,
    gender,
    status,
    created_ts
from {{ source('bronze','participant_raw') }}