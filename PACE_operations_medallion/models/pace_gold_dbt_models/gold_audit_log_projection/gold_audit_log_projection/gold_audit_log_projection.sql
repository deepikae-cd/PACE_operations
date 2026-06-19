/*
===============================================================================
MODEL NAME  : gold_audit_log_projection
LAYER       : GOLD
DOMAIN      : AUDIT / COMPLIANCE
OWNER       : DATA ENGINEERING
VERSION     : 1.1

-------------------------------------------------------------------------------
DESCRIPTION:
  Read-optimized audit log projection for high-performance UI queries.

  Features:
    - Fully denormalized (no joins required)
    - Precomputed event descriptions for UI rendering
    - Partition-ready using event_date
    - Optimized for participant and date filtering
    - Incremental load support

  Supports:
    - UC-10: Audit trail UI performance
    - Compliance monitoring
    - PHI access tracking

GRAIN:
  One row per audit_log_id

DEPENDENCIES:
  - enterprise_silver_audit_log
-------------------------------------------------------------------------------
*/


-- ============================================================================
-- STEP 1: SOURCE
-- ============================================================================

with source as (

    select *
    from {{ ref('enterprise_silver_audit_log') }}

    {% if is_incremental() %}
    where event_timestamp > (
        select coalesce(max(event_timestamp), '1900-01-01')
        from {{ this }}
    )
    {% endif %}

),

-- ============================================================================
-- STEP 2: ENRICHMENT
-- ============================================================================

enriched as (

    select

        -- ✅ Surrogate key
        sha2(concat_ws('||', audit_log_id), 256) as audit_projection_sk,

        -- ✅ Keys
        audit_log_id,
        participant_id,
        actor_id,

        -- ✅ Actor info
        actor_name,
        actor_role,
        actor_type,

        -- ✅ Event core
        action,
        entity_type,
        entity_id,
        event_category,

        -- ✅ UI-friendly description
        case
            when action = 'CREATE'
                then concat(actor_name, ' created ', entity_type)
            when action = 'UPDATE'
                then concat(actor_name, ' updated ', entity_type,
                            ' (', coalesce(field_changed, 'field'), ')')
            when action = 'DELETE'
                then concat(actor_name, ' deleted ', entity_type)
            when action = 'VIEW'
                then concat(actor_name, ' viewed ', entity_type)
            when action = 'APPROVE'
                then concat(actor_name, ' approved ', entity_type)
            when action = 'REJECT'
                then concat(actor_name, ' rejected ', entity_type)
            else concat(actor_name, ' performed action on ', entity_type)
        end as event_description_ui,

        -- ✅ Time
        event_timestamp,
        event_date,
        extract(hour from event_timestamp) as event_hour,

        -- ✅ Change tracking
        field_changed,
        old_value,
        new_value,
        change_reason,

        -- ✅ Compliance flags
        is_phi_access,
        is_sensitive,

        -- ✅ Context
        module,
        center_id,

        -- ✅ Technical metadata
        ip_address,
        user_agent,
        session_id,
        request_id,

        -- ✅ Source lineage
        source_system,
        updated_at,

        -- ✅ Metadata
        current_timestamp() as gold_loaded_at

    from source

)

-- ============================================================================
-- FINAL OUTPUT
-- ============================================================================

select *
from enriched