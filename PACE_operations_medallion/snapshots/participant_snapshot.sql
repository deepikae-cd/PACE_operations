{% snapshot participant_snapshot %}

{{
    config(
        target_schema='SNAPSHOTS',
        strategy='check',
        unique_key='participant_id',
        check_cols=['record_hash'],
        invalidate_hard_deletes=True
    )
}}

select
    participant_id,
    first_name,
    last_name,
    gender,
    email,
    phone,
    participant_status,
    source_created_ts,
    load_ts,
    source_system,
    record_hash
from {{ ref('participant') }}

{% endsnapshot %}
