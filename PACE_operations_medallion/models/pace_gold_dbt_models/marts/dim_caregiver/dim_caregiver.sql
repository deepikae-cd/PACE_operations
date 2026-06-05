/*
  DIM_CAREGIVER  –  SCD Type-2 Dimension
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('snap_caregiver') }}
  Tracked : employment_status, center_id, license_expiry_date,
            supervisor_id, max_participant_load
  ──────────────────────────────────────────────────────────────────────────────
*/

with snapshot as (

    select * from {{ ref('snap_caregiver') }}

)

select
    sha2(concat_ws('||', caregiver_id, dbt_scd_id))   as caregiver_hk,
    sha2(caregiver_id)                                 as caregiver_sk,
    caregiver_id,

    dbt_valid_from                                     as valid_from,
    dbt_valid_to                                       as valid_to,
    (dbt_valid_to is null)                             as is_current,

    -- Tracked
    employment_status,
    center_id,
    license_expiry_date,
    is_license_expired,
    supervisor_id,
    max_participant_load,

    -- Stable
    full_name,
    first_name,
    last_name,
    caregiver_type,
    license_number,
    license_state,
    specialty,
    hire_date,
    termination_date,
    source_system,
    dbt_updated_timestamp,
    loaded_timestamp

from snapshot
