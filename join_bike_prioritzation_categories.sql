--join bike prioritization subscores to tdg_network

alter table tdg_network
  
  add column facility_score double precision,
  
 add column  crash_score double precision,
 
  add column conn2existing_score double precision,

  add column conn2planned_score double precision,
 
  add column p_l_s_score double precision,
 
  add column transit_score double precision,
  
add column school_score double precision,

  add column retail_score double precision,
  add column coc_score double precision

  ;

  
 update tdg_network a
 set  facility_score = b.facility_score,
  
   crash_score = b.crash_score,
 
  conn2existing_score = b.conn2existing_score,

   conn2planned_score = b.conn2planned_score,
 
  p_l_s_score = b.p_l_s_score,
 
   transit_score = b.transit_score,
  
 school_score = b.school_score,

   retail_score = b.retail_score,
   coc_score = b.coc_score
 from  proj_score b
 where cast(a.project_id AS integer) = b.proj_num
 ;




 