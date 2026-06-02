{% snapshot participant_snapshot %}

{{
    config(
        target_schema='SNAPSHOTS',
        unique_key='participant_id',
        strategy='check',
        check_cols='all'
    )
}}

select *
from {{ ref('participant') }}

{% endsnapshot %}
