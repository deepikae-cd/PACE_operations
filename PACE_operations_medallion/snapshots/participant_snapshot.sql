{% snapshot participant_snapshot %}

{{
    config(
        schema='SNAPSHOTS',
        strategy='timestamp',
        unique_key='participant_id',
        updated_at='source_created_ts'
    )
}}

select
    participant_id,
    first_name,
    last_name,
    gender,
    participant_status,
    source_created_ts
from {{ ref('participant') }}

{% endsnapshot %}