{% snapshot snap_caregiver %}

{{
    config(
        target_schema  = 'snapshots_caregiver',
        unique_key     = 'caregiver_id',
        strategy       = 'check',
        check_cols     = [
            'employment_status',
            'center_id',
            'license_expiry_date',
            'is_license_expired_flag',
            'supervisor_id',
            'max_participant_load'
        ],
        invalidate_hard_deletes = true
    )
}}

select * from {{ ref('enterprise_silver_caregiver') }}

{% endsnapshot %}
