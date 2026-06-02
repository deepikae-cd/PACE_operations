
  
    



create or replace transient  table PACE_DW.GOLD.service_utilization
    
    
    
    
    as (select
    service_type,

    count(*) as total_usage,

    sum(completed_flag) as successful_services,

    round(
        100.0 * sum(completed_flag) / nullif(count(*),0), 2
    ) as success_rate_pct,

    current_timestamp() as load_ts

from PACE_DW.SILVER.appointment
group by service_type
    )
;



  