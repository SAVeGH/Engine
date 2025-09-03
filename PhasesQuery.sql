select
*
from
phases
order by angle 


select
angle,
angle * (51.1523727680347 / 180.0) as bladeAngle,
Exhaust,
Blow,
Intake
from
phases
order by angle 