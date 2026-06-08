{% snapshot snap_participant %}

{{
    config(
        target_schema = 'SNAPSHOTS_PARTICIPANT',
        unique_key = 'participant_id',
        strategy = 'check',
        check_cols = [
            'program_status',
            'center_id',
            'primary_diagnosis',
            'preferred_language',
            'disenrollment_date',
            'address_line1',
            'zip_code',
            'phone_number'
        ],
        invalidate_hard_deletes = true
    )
}}

SELECT
    participant_id,
    center_id,
    program_status,
    primary_diagnosis,
    preferred_language,
    disenrollment_date,
    address_line1,
    zip_code,
    phone_number,
    _loaded_at
FROM {{ ref('staging_participant') }}

{% endsnapshot %}
