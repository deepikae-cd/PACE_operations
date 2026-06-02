with src as (

    select *
    from PACE_DW.BRONZE.clinical_visit_raw

)

select

    visit_id,

    participant_id,

    provider_id,

    visit_date,

    upper(trim(service_type)) as service_type,

    upper(trim(diagnosis_code)) as diagnosis_code,

    upper(coalesce(status,'COMPLETED')) as visit_status,

    created_ts,

    current_timestamp() as load_ts

from src

qualify row_number()
over (
    partition by visit_id
    order by created_ts desc
) = 1