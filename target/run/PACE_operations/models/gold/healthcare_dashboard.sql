
  
    



create or replace transient  table PACE_DW.GOLD.healthcare_dashboard
    
    
    
    
    as (with appt as (
    select * from PACE_DW.SILVER.appointment
),

meal as (
    select * from PACE_DW.SILVER.meal_delivery
),

visit as (
    select * from PACE_DW.SILVER.clinical_visit
)

select

    (select count(*) from appt) as total_appointments,
    (select count(*) from meal) as total_meals,
    (select count(*) from visit) as total_clinical_visits,

    (select sum(completed_flag) from appt) as completed_appointments,
    (select sum(cancelled_flag) from appt) as cancelled_appointments,

    round(
        100.0 * (select sum(completed_flag) from appt)
        / nullif((select count(*) from appt),0), 2
    ) as overall_completion_rate,

    current_timestamp() as load_ts
    )
;



  