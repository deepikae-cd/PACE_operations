{% snapshot participant_snapshot %}

select
    participant_id,
    first_name,
    last_name,
    gender,
    date_of_birth,
    participant_status,
    source_created_ts
from {{ ref('participant') }}

{% endsnapshot %}