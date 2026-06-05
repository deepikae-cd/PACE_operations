/*
===============================================================================
Model       : gold_home_care_task_breakdown
Layer       : Gold
Description :
  Calculates percentage distribution of home-care task categories,
  including medication assistance versus other tasks.

Grain:
  - program_year + task_category

Key Features:
  - Aggregates task duration by category
  - Calculates percentage contribution to total program time
  - Safe division using NULLIF to prevent divide-by-zero errors
  - Adds category grouping for simplified reporting

===============================================================================
*/

with base as (

    select
        program_year,
        task_category,
        actual_duration_minutes
    from {{ ref('int_home_care_task_breakdown') }}

),

-- ============================================================
-- Aggregate total minutes per category
-- ============================================================
aggregated as (

    select
        program_year,
        task_category,
        sum(actual_duration_minutes) as total_minutes
    from base
    group by program_year, task_category

),

-- ============================================================
-- Compute total minutes per program_year
-- ============================================================
totals as (

    select
        program_year,
        sum(total_minutes) as grand_total_minutes
    from aggregated
    group by program_year

),

-- ============================================================
-- Final output with percentage calculation
-- ============================================================
final as (

    select
        a.program_year,
        a.task_category,
        a.total_minutes,
        t.grand_total_minutes,

        -- ✅ Safe percentage calculation
        (a.total_minutes / nullif(t.grand_total_minutes, 0)) * 100
            as pct_of_total_minutes,

        -- ✅ Optional grouping (useful for dashboards)
        case
            when a.task_category = 'MEDICATION_ASSISTANCE'
                then 'medication'
            else 'other'
        end as category_group

    from aggregated a

    join totals t
        on a.program_year = t.program_year

)

-- ============================================================
-- Final Output
-- ============================================================
select * from final;