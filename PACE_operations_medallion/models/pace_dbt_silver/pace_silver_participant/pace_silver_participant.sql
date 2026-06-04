with source as (

    select *
    from {{ source('bronze_participant', 'RAW_PARTICIPANT') }}

),

deduplicated as (

    select *,
           row_number() over (
               partition by participant_id
               order by _loaded_at desc
           ) as _rn
    from source
    where participant_id is not null

),

cleaned as (

    select
        sha2(
            concat_ws('||', coalesce(participant_id,'NA'), cast(_loaded_at as varchar)),
            256
        ) as participant_sk,

        trim(upper(participant_id)) as participant_id,

        trim(initcap(coalesce(first_name, ''))) as first_name,
        trim(initcap(coalesce(last_name,  ''))) as last_name,

        try_cast(date_of_birth as date) as date_of_birth,

        upper(trim(coalesce(preferred_language, 'UNKNOWN'))) as preferred_language,

        try_cast(enrollment_date as date) as enrollment_date,
        try_cast(disenrollment_date as date) as disenrollment_date,

        upper(trim(program_status)) as program_status,

        upper(trim(source_system)) as source_system,
        _loaded_at as loaded_at

    from deduplicated
    where _rn = 1

)

select * from cleaned
