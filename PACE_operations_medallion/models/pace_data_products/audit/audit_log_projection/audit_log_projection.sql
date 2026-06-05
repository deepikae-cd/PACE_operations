/*
===============================================================================
Model       : gold_audit_log_projection
Layer       : Gold
Description : 
  Read-optimized audit log projection for fast UI queries. Fully denormalized,
  precomputes event descriptions, and adds partitioning for high-performance
  filtering by participant and date.

Source:
  - {{ ref('enterprise_silver_audit_log') }}

Key Features:
  - No joins required at query time
  - Precomputed event descriptions for UI
  - Partition-ready (event_date)
  - Optimized for participant + date filtering

===============================================================================
*/

with

-- ============================================================
-- Source: Silver audit log
-- Incremental load using updated_at
-- ============================================================
source as (

    select *
    from {{ ref('enterprise_silver_audit_log') }}

    {% if is_incremental() %}
    where updated_at > (
        select coalesce(max(updated_at), '1900-01-01')
        from {{ this }}
    )
    {% endif %}

),

-- ============================================================
-- Precompute UI-friendly descriptions
-- ============================================================
enriched as (

    select

        -- ─────────────────────────────────────────────
        -- Keys
        -- ─────────────────────────────────────────────
        audit_log_id,
        participant_id,
        actor_id,

        -- ─────────────────────────────────────────────
        -- Actor details (already denormalized from bronze)
        -- ─────────────────────────────────────────────
        actor_name,
        actor_role,
        actor_type,

        -- ─────────────────────────────────────────────
        -- Core event attributes
        -- ─────────────────────────────────────────────
        action,
        entity_type,
        entity_id,
        event_category,

        -- ─────────────────────────────────────────────
        -- ✅ Precomputed event description (UI CRITICAL)
        -- ─────────────────────────────────────────────
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

        -- ─────────────────────────────────────────────
        -- Timestamp fields
        -- ─────────────────────────────────────────────
        event_timestamp,
        event_date,   -- ✅ already derived in silver (partition key)

        -- ─────────────────────────────────────────────
        -- Change tracking (optional for UI detail views)
        -- ─────────────────────────────────────────────
        field_changed,
        old_value,
        new_value,
        change_reason,

        -- ─────────────────────────────────────────────
        -- Flags (important for compliance filtering)
        -- ─────────────────────────────────────────────
        is_phi_access,
        is_sensitive,

        -- ─────────────────────────────────────────────
        -- Context
        -- ─────────────────────────────────────────────
        module,
        center_id,

        -- ─────────────────────────────────────────────
        -- Technical metadata
        -- ─────────────────────────────────────────────
        ip_address,
        user_agent,
        session_id,
        request_id,

        -- ─────────────────────────────────────────────
        -- Source lineage
        -- ─────────────────────────────────────────────
        source_system,
        updated_at,

        current_timestamp as gold_loaded_at

    from source
)

-- ============================================================
-- Final Output
-- ============================================================
select * from enriched