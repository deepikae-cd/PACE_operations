
with snapshot_data as (

    select *
    from {{ ref('snap_participant') }}

),

current_records as (

    --  Keep only active/latest record
    select *
    from snapshot_data
    where dbt_valid_to is null

),

final as (

    select

        --  Business key
        participant_id,

        -- Attributes
        center_id,
        program_status,
        primary_diagnosis,
        preferred_language,
        disenrollment_date,

        -- Address
        address_line1,
        zip_code,

        -- Contact
        phone_number,

        -- Metadata
        dbt_valid_from as record_start_date,
        current_timestamp as record_loaded_at

    from current_records

)

select * from final
