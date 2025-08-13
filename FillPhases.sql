select *
from
phases
order by
angle
/*
update
phases
set
Exhaust = NULL,
Blow = NULL,
Intake = NULL
*/

update
phases
set
Intake = 1
where
volumePartRotor <= 0.392224990706319

update
phases
set
Exhaust = 1
where
volumePartRotor >= 0.638317801467341

update
phases
set
Blow = 1
where
volumePartRotor >= 0.796046697014558