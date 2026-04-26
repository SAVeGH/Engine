with
steps as(
select
r2.Angle,
(r2.gearAngle + isnull(x.gearAngle, 0)) as GearStepAngle
from
rotations r2
outer apply ( select 
              r.gearAngle 
              from 
			  rotations r 
			  where 
			  cast(r.Angle as int) = cast(r2.Angle as int) - 1 ) as x 
where
(cast(r2.Angle as int) % 2) = 0)
select
s.Angle,
isnull((LEAD(s.GearStepAngle) over (order by s.Angle)), 0) as GearStepAngle
from
steps s
order by s.Angle;
/*
select
*
from
rotations
order by Angle
*/