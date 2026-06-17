/*
  MODEL: GOLD_MEAL_DELIVERY_PERFORMANCE
  ───────────────────────────────────────────────────────────────
  PURPOSE:
    Aggregated fact (mart) providing daily delivery performance metrics.
    Designed for BI dashboards and reporting.

  GRAIN:
    1 row per delivery_date

  METRICS:
    - total_deliveries        → total number of deliveries per day
    - delivered_count         → successfully delivered meals
    - avg_delay               → average delivery delay (hours)
    - late_deliveries         → count of late deliveries

  SOURCE:
    {{ ref('fct_meal_delivery') }}

  BUSINESS VALUE:
    - Monitor delivery efficiency trends
    - Track SLA violations (late deliveries)
    - Measure operational performance over time

  NOTES:
    - Built on top of curated fact table (fct_meal_delivery)
    - Optimized for dashboard consumption
*/

with daily_metrics as (

    select
        -- Grain: delivery_date
        delivery_date,

        -- Total number of deliveries
        count(*) as total_deliveries,

        -- Successful deliveries (binary flag aggregation)
        sum(delivered_flag) as delivered_count,

        -- Average delay in hours
        avg(hours_after_meal_date) as avg_delay,

        -- Late deliveries count (SLA violation)
        sum(
            case 
                when is_late_delivery_flag then 1 
                else 0 
            end
        ) as late_deliveries

    from {{ ref('fct_meal_delivery') }}

    group by delivery_date

)

select * from daily_metrics