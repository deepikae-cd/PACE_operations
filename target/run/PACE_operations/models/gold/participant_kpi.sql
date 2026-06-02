
  
    



create or replace transient  table PACE_DW.GOLD.participant_kpi
    
    
    
    
    as (select
    count(*) as total_participants
from PACE_DW.SILVER.participant
    )
;



  