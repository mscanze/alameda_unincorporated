
--------------------------------------------------------------


--need to create a new table 

drop table if exists generated.tdg_sidewalk_proj;

create table generated.tdg_sidewalk_proj(
	id SERIAL PRIMARY KEY,
	geom GEOMETRY(multilinestring, 26910),
	roadway varchar,
	"to" varchar,
	"from" varchar,
	proj_length_mi decimal,

	
	crash_count_sev decimal,
	crash_count_oth decimal,
	crash_weight_mile decimal,
	crash_tier decimal,
	crash_score decimal,
	

	park_half decimal,
	park_mile decimal,
	senior_half decimal,
	senior_mile decimal,
	p_l_s_score decimal,
	gov_count_quarter decimal,
	gov_count_eighth decimal,
	gov_score decimal,

	transit_count_quarter decimal,	
	transit_score decimal,
	
	school_count_quarter decimal,
	school_count_half decimal,
	school_count_threequart decimal,
	school_score decimal,
	
	retail_quarter decimal,
	retail_score decimal,
	
	coc_score decimal,
	bus_stop_score decimal,
	total_score decimal,
	rank decimal);



insert into generated.tdg_sidewalk_proj (geom, "roadway", "to", "from") 	
select 
	st_multi(st_union(b.geom)),

	"roadway",
	"seg_to",
	"seg_from"

from generated.missing_sw as b
where overlap is null
group by 
	"roadway",
	 "seg_to",
	 "seg_from"
	
;

update generated.tdg_sidewalk_proj
set proj_length_mi = st_length(geom)/1609.34
;

--========================================================

--   CRASHES

--=======================================================

--Count crashes within 300ft
UPDATE generated.tdg_sidewalk_proj as p 
SET crash_count_sev = (			-- severe crashes
  SELECT count(id)
  FROM collisions_2006_2016 as bc
  WHERE ST_DWithin(p.geom, bc.geom, 91.44)
  AND (bc.date_ like '%2009' or
		bc.date_ like '%2010' or
		bc.date_ like '%2011' or
		bc.date_ like '%2012' or
		bc.date_ like '%2013')
  AND (bc.crashsev in (1,2)) 
  AND (bc.biccol = 'Y' or bc.pedcol= 'Y')
);


UPDATE generated.tdg_sidewalk_proj as p 
SET crash_count_oth = (			-- other crashes
  SELECT count(id)
  FROM collisions_2006_2016 as bc
  WHERE ST_DWithin(p.geom, bc.geom, 91.44)  --300 feet = 91.44 meters
  AND (bc.date_ like '%2009' or
		bc.date_ like '%2010' or
		bc.date_ like '%2011' or
		bc.date_ like '%2012' or
		bc.date_ like '%2013')
  AND bc.crashsev in (3,4)
  AND (bc.biccol = 'Y' or bc.pedcol= 'Y')
);


UPDATE    generated.tdg_sidewalk_proj
SET       crash_count_sev = 0
WHERE     crash_count_sev IS NULL
;


UPDATE    generated.tdg_sidewalk_proj
SET       crash_count_oth = 0
WHERE     crash_count_oth IS NULL
;

-- --calculate # crashes, weighted by severity, per mile
 UPDATE generated.tdg_sidewalk_proj
 SET crash_weight_mile = ((5 * crash_count_sev) + (3* crash_count_oth))/proj_length_mi
 ;


-- --calculate tier of crash 

UPDATE generated.tdg_sidewalk_proj
SET crash_tier = CASE WHEN crash_weight_mile < 14 THEN 3
			WHEN crash_weight_mile >=14 and crash_weight_mile <48 THEN 2
			WHEN crash_weight_mile >=48 THEN 1
			END;



UPDATE generated.tdg_sidewalk_proj
SET crash_score = CASE WHEN crash_weight_mile < 14 THEN 1
			WHEN crash_weight_mile >=14 and crash_weight_mile <48 THEN 2
			WHEN crash_weight_mile >=48 THEN 3
			END;

UPDATE generated.tdg_sidewalk_proj
SET crash_score = 0 
WHERE crash_weight_mile = 0 
;



		     
  --=======================================================================
  --  Schools
  --=======================================================================
 --quarter mile count
  UPDATE      generated.tdg_sidewalk_proj as p
  SET         school_count_quarter = (
    SELECT    count(id)
    FROM      generated.schools s
    WHERE     ST_DWithin(p.geom, s.geom, 402.336)
  );

  
 --greater than quarter, less than half mile count
  UPDATE      generated.tdg_sidewalk_proj as p
  SET         school_count_half = (
    SELECT    count(id)
    FROM      generated.schools s
    WHERE     ST_DWithin(p.geom, s.geom, 804.672)
	AND s.id NOT IN (
		SELECT (id)
		FROM      generated.schools s
		WHERE     ST_DWithin(p.geom, s.geom, 402.336)
		)
  );

--greater than half, less than 3/4
UPDATE      generated.tdg_sidewalk_proj as p
  SET         school_count_threequart = (
    SELECT    count(id)
    FROM      generated.schools s
    WHERE     ST_DWithin(p.geom, s.geom, 1207.01)
	AND s.id NOT IN (
		SELECT (id)
		FROM      generated.schools s
		WHERE     ST_DWithin(p.geom, s.geom, 402.336)
		)
	AND s.id NOT IN (
		SELECT (id)
		FROM      generated.schools s
		WHERE     ST_DWithin(p.geom, s.geom, 804.672)
		)
  );


  -- school score

  UPDATE generated.tdg_sidewalk_proj as p
  SET school_score = CASE WHEN school_count_quarter >0 then 3
			  WHEN school_count_half >0 and school_count_quarter =0 then 2
			   WHEN school_count_threequart >0 and school_count_quarter =0 and school_count_half = 0 then 1
			   ELSE 0

			END;

-------------------------------------
--Crash score bonus points if school within 1/2 mile
------------------------------------
---add two points if there is at least one crash and school is within 1/4 mile

UPDATE generated.tdg_sidewalk_proj
SET crash_score = crash_score + 2.0
 WHERE (crash_count_sev >=1 OR crash_count_oth >= 1) AND school_count_quarter >0 
;

  --=======================================================================
  --  Parks/Library/Senior Center half mi

  --=======================================================================
 --parks within half
  UPDATE      generated.tdg_sidewalk_proj as p
  SET         park_half = (
    SELECT    count(s.id) 
    FROM      
		generated.parks s
		
    WHERE     ST_DWithin(p.geom, s.geom, 804.672)
	)
	;
-- parks within mile
	UPDATE      generated.tdg_sidewalk_proj as p
  SET         park_mile = (
    SELECT    count(s.id) 
    FROM      
		generated.parks s
		
    WHERE     ST_DWithin(p.geom, s.geom, 1609.34)
		AND s.id NOT IN (
		SELECT (id)
		FROM      generated.parks b
		WHERE     ST_DWithin(p.geom, b.geom, 804.672)
		)
	)
	;

	
--lib/senior within half
  UPDATE      generated.tdg_sidewalk_proj as p
  SET         senior_half = (
    SELECT    count(s.id) 
    FROM      
		generated.library_senior s
		
    WHERE     ST_DWithin(p.geom, s.geom, 804.672)
	)
	;
-- lib/senior within mile
UPDATE      generated.tdg_sidewalk_proj as p
  SET         senior_mile = (
    SELECT    count(s.id) 
    FROM      
		generated.library_senior s
		
    WHERE     ST_DWithin(p.geom, s.geom, 1609.34)
		AND s.id NOT IN (
		SELECT (id)
		FROM      generated.library_senior b
		WHERE     ST_DWithin(p.geom, b.geom, 804.672)
		)
	)
	;
 
 
 --p_l_s_score
 update generated.tdg_sidewalk_proj as p
 set p_l_s_score = CASE WHEN senior_half > 0 or park_half > 0 then 3
							WHEN (senior_mile >0 or park_mile >0) and senior_half =0 and park_half = 0 then 2
							ELSE 0
							END;						
							
 
 
 
   
--=======================================================================
  --  gov office score
  --=======================================================================
 --gov office eighth
  UPDATE      generated.tdg_sidewalk_proj as p
  SET         gov_count_eighth = (
    SELECT    count(s.id) 
    FROM      
		generated.office_government s
		
    WHERE     ST_DWithin(p.geom, s.geom, 201)
	)
	;
-- gov office quarter
	UPDATE      generated.tdg_sidewalk_proj as p
  SET         gov_count_quarter = (
    SELECT    count(s.id) 
    FROM      
		generated.office_government s
		
    WHERE     ST_DWithin(p.geom, s.geom, 400)
		AND s.id NOT IN (
		SELECT (id)
		FROM      generated.office_government s
		WHERE     ST_DWithin(p.geom, s.geom, 201)
		)
	)
	;
 --gov office score
 update generated.tdg_sidewalk_proj as p
 set gov_score = CASE WHEN gov_count_eighth >0 THEN 5
							WHEN gov_count_quarter > 0 then 2
							ELSE 0
							END;
--=======================================================================
  --  Transit stops qua mi
  --=======================================================================
UPDATE      generated.tdg_sidewalk_proj as p
  SET         transit_count_quarter = (
    SELECT    count(s.id) 
    FROM     
		generated.transit s
		
    WHERE     ST_DWithin(p.geom, s.geom, 402.336)
	)
	;
	
UPDATE generated.tdg_sidewalk_proj as p_l_s_score
SET transit_score = CASE WHEN transit_count_quarter >0 then 3
					ELSE 0
					END;
--=======================================================================
  --  Retail corridors quart mi
  --=======================================================================
  UPDATE      generated.tdg_sidewalk_proj as p
  SET         retail_quarter = (
    SELECT    count(s.id) 
    FROM      
		generated.retail_corridor s
		
    WHERE     ST_DWithin(p.geom, s.geom, 402.336)
	)
	;
	
UPDATE generated.tdg_sidewalk_proj as p_l_s_score
SET retail_score = CASE WHEN retail_quarter >0 then 4
					ELSE 0
					END;
  
--=======================================================================
  --  Intersects COC
  --=======================================================================
  UPDATE generated.tdg_sidewalk_proj p
  SET coc_score = 4
  FROM generated.communities_concern c
  WHERE st_intersects(p.geom, c.geom)
  AND coc_flag_2 = 1;
  
  UPDATE generated.tdg_sidewalk_proj p
  SET coc_score = 0
  WHERE coc_score is null;

--=======================================================================
  --  Within 500 ft of cnty bus stop
  --=======================================================================
with t1 as (SELECT    count(s.stp_identi) as count, p.id as id
		FROM    generated.bus_stps_cnty s,
			generated.tdg_sidewalk_proj as p
		WHERE     ST_DWithin(s.geom, p.geom, 152)
		and ((s.on_80 = 1 and s.on_80 is not null )or (s.off_80 = 1 and s.off_80 is not null))
		group by p.id)
UPDATE      generated.tdg_sidewalk_proj as p
  SET         bus_stop_score = CASE WHEN t1.count >=1 then 2
				ELSE 0
				END
from t1
where t1.id = p.id
	;

update generated.tdg_sidewalk_proj
set bus_stop_score = 0
where bus_stop_score is null; 

  
--=======================================================================
  --  Final Score
  --=======================================================================  
  
with t1 as (select "roadway", "to", "from",
AVG(crash_score + p_l_s_score + transit_score + school_score + retail_score + coc_score + bus_stop_score + gov_score) as avg
from tdg_sidewalk_proj
group by "roadway", "to", "from")

update tdg_sidewalk_proj as b
set total_score = t1.avg
from t1
where b.roadway = t1.roadway
and b.to = t1.to 
and b.from = t1.from;



with t4 as (select dense_rank() over (order by total_score desc) as order, id as id, total_score
		from generated.tdg_sidewalk_proj as p
		order by total_score asc)
UPDATE generated.tdg_sidewalk_proj as p
SET rank = t4.order
FROM t4
WHERE t4.id=p.id
;

--DELETE
--FROM
--    tdg_sidewalk_proj a 
  --      USING tdg_sidewalk_proj b
--WHERE
  --  a.id < b.id
    --AND a.roadway = b.roadway
    --and a.to = b.to
    --and a.from = b.from;
    
select * from tdg_sidewalk_proj ORDER BY rank desc;

