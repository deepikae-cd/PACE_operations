/*
  DIM_GOVERNANCE_RULES
  ──────────────────────────────────────────────────────────────────────────────
  Source  : {{ ref('enterprise_silver_governance_rules') }}
  Purpose : Conformed dimension for governance rules.

            Provides a stable, business-friendly representation of rules
            with standardized attributes and lifecycle flags.

  Grain   : 1 row per rule_id (latest active version)
  ──────────────────────────────────────────────────────────────────────────────
*/

with base as (

    select *
    from {{ ref('enterprise_silver_governance_rules') }}

)

select
    -- Surrogate key
    rule_sk,

    -- Natural key
    rule_id,

    -- Business attributes
    rule_name,
    rule_description,
    rule_category,
    rule_subcategory,
    applies_to_domain,

    -- Enforcement classification
    enforcement_level,
    enforcement_rank,
    is_hard_block_flag,
    is_soft_warning_flag,
    is_audit_only_flag,

    -- Regulatory classification
    is_regulatory_flag,

    -- Lifecycle
    rule_status,
    is_currently_enforceable_flag,
    is_expiring_soon_flag,
    rule_age_days,

    -- Dates
    effective_date,
    expiry_date

from base
where is_currently_enforceable_flag = true