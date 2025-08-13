/*
расчет данных для роторного двигателя
*/
--create or alter function [dbo].[EngineData_2T](@n float, @relation float, @cylinderRelation float)
-- @n - это оношение в уравнении эллипса (x/a)^2 + (y/(n*a))^2 = r^2 (эллипсность)
-- @relation - сколько обротов делает вал ЗКВ для поворота цилиндра на один оборот
-- @cylinderRelation - на сколько нужно умножить радиус средней окружности передачи цилиндра что бы получить расстояние до точки
-- приложения усилия к лопасти

--returns 
declare @resultHot table (phase bit, angle float, stepP float, stepV float, stepT float, stepF float, stepM float, stepWork float, volumePart float);
declare @resultCold table (phase bit, angle float, stepP float, stepV float, stepT float, stepF float, stepM float, stepWork float);
--as
--begin
-- https://ru.wikipedia.org/wiki/Адиабатический_процесс
-- PV^k = const
-- PV/T = const
-- k = 7/5 - для двухатомного газа
-- Начальные условия
-- T = 300K
-- P = 100000 Па
-- степень сжатия - 10
-- начальный объем 49 см^3. = 4.9 * 10^-4 м^3 - полный объем включая выхлоп

declare @n float = 0.86;
declare @relation float = 2.0; 


-- степень сжатия - 10
-- начальный объем 49 см^3. = 4.9 * 10^-4 м^3 - полный объем включая выхлоп

declare @PI float = PI();
declare @Rad float = @PI / 180.0

--------------------------------------------------------------------------------------------------------------------------------

declare @angleStep float = 1.0; -- шаг поворота вала
declare @currentAngle float = 0.0; -- это угол в ВМТ в градусах
declare @currentAngleRad float = 0.0; -- это угол в ВМТ в радианах


declare @r float = 1.0; -- радиус шестерни вала ЗКВ

/*
 * смещение расчитывается следующим образом:
 * при смещении шестерен в противоположные стороны симметрично передаточное отношение будт:
 * b = (r + x)/(r - x) 
 * где x - искомое смещение r - радиус шестерни (тут 1.0) b - передаточное число
 * тогда при заднном отношении b имеем:
 * r + x = b*(r - x) => r = b*(r - x) - x => r = b*r - b*x - x => r - b*r = -b*x - x => перевернём знаки b*x + x = b*r - r
 * выносим x и r за скобки x*(b + 1) = r*(b - 1) отсюда
 * x =  r*(b - 1)/(b + 1)
 */
declare @diffRelation float = 2.7; -- макс. передаточное отношение в положении вала с максимальным физическим плечом
declare @shift float = @n * @r * (@diffRelation - 1)/(@diffRelation + 1) -- смещение центра шестерни от оси ЗКВ при радиусе шестерни 1.0
declare @r2 float = POWER(@r, 2);

/*
Идея расчета в том что бы вращать не эллипс, а линию (ось y) для нахождения точек их пересечения.
уравнение эллипса
(x/a)^2 + (y/b)^2 = r^2
уравнение линии
y = kx - c; 
где 
k - угловой коэффициент (отношение шага по y к шагу по x)
c - смещение по y (тут @shift)
r - у нас 1 (окружность единичного радиуса)
a - то же 1 - единичный делитель по x
b = n * a - делитель по y - насколько ось y эллипса меньше оси x (которая равна 1) n - это @n в коде

подставляем уравнение линии вместо y в уравнение эллипса
(x/a)^2 + ((kx - c)/b)^2 = r^2
(x/a)^2 + ((kx - c)/b)^2 = 1 -- r^2 = 1
(x/a)^2 = x^2/a^2
по формуле сокращенного умножения (a - b)^2 =  a^2 - 2*a*b + b^2 открываем скобки
x^2/a^2 + (k^2*x^2 - 2*k*x*c + c^2)/b^2 = 1
приводим к общему знаменателю a^2*b^2
(b^2*x^2 + a^2*(k^2*x^2 - 2*k*x*c + c^2)) / a^2*b^2 = 1
домножаем на общий знаменатель a^2*b^2
b^2*x^2 + a^2*(k^2*x^2 - 2*k*x*c + c^2) = a^2*b^2
подставляем b = n*a в левую часть (n*a)^2 = n^2*a^2 (уходим от переменной b. Остается только a в уравнении и известный коэффициент n)
n^2*a^2*x^2 + a^2*k^2*x^2 - a^2*2*k*x*c + a^2*c^2 = a^2*b^2
тут a = 1 тогда
n^2*x^2 + k^2*x^2 - 2*k*x*c + c^2 = a^2*b^2
в левой части a^2*b^2 = a^2*n^2*a^2 и т.к. a = 1 то равно n^2
перепишем
n^2*x^2 + k^2*x^2 - 2*k*x*c + c^2 = n^2
выносим за скобки x
x^2(n^2 + k^2) - 2*k*x*c + c^2 = n^2
переносим n^2 и приравниваем к 0
x^2(n^2 + k^2) - 2*k*x*c + c^2 - n^2 = 0
получаем квадратное уравнение вида a*x^2 + b*x + c = 0
где
a = n^2 + k^2
b = -2*k*c
c =  c^2 - n^2
угловой коэффициент k это sin(f)/cos(f) - где f - угол наклона линии
т.е. это tg(f)
тогда можно переписать (связь уравнения с углом поворота линии)
x^2(n^2 + (tg(f))^2) - 2*tg(f)*x*c + c^2 - n^2 = 0
тогда
a = n^2 + (tg(f))^2
b = - 2*tg(f)*c
c =  c^2 - n^2
решая уравнение для заданного угла f получаем две x координаты точек пересечения линии (оси y) с эллипсом.
Координаты y находим подствляя полученные x координаты в уравнение линии
y = k*x - c => y = tg(f) * x - c
*/

declare @ellipseCrosses table(Angle float, x1 float, x2 float, y1 float, y2 float);
-- Cycle
-- расчет координат пересечения линии контакта с эллипсом
while round(@currentAngle,2) <= 90.0 
begin

	set @currentAngleRad = @currentAngle * @Rad;

	declare @tg float = SIN(@currentAngleRad) / IIF(COS(@currentAngleRad) = 0, 1, COS(@currentAngleRad))

	declare @a float = POWER(@n, 2) + POWER(@tg, 2);
	declare @b float = -2.0 * @tg * @shift;
	declare @c float = POWER(@shift, 2) - POWER(@n, 2);

	insert into @ellipseCrosses(Angle, x1, x2, y1, y2)
	select round(@currentAngle,2), x1, x2, (@tg * x1 - @shift), (@tg * x2 - @shift) 
	from dbo.Resolve(@a , @b , @c );

	set @currentAngle = @currentAngle + @angleStep;

end


--select * from @ellipseCrosses

declare @srcEllipseArms table(Angle float, arm1 float, arm2 float, arm float, delta float, forceRelation1 float, forceRelation2 float);
-- расстояния от точек контакта линии и эллипса до оси поворота линии
-- т.е. величина плеч
insert into @srcEllipseArms(Angle, arm1, arm2)
select
ec.Angle,
SQRT(POWER(x1,2) + POWER(@shift + y1, 2)),
SQRT(POWER(x2,2) + POWER(@shift + y2, 2))
from
@ellipseCrosses ec

update @srcEllipseArms
set
arm = arm2 - arm1; -- разница плечей составляет результирующее плечо

--select * from @srcEllipseArms

declare @maxArm float = (select max(arm) from @srcEllipseArms);

update @srcEllipseArms
set
arm = arm * (1.0 / @maxArm), -- приведение плечей к диапазону 0..1
arm1 = arm1 * (1.0 / @maxArm),
arm2 = arm2 * (1.0 / @maxArm);

update am
set
delta = x.delta -- изменение результирующего плеча на каждом шаге от предыдущего до текущего положения
from
@srcEllipseArms am
inner join
(select 
 a.Angle, 
 abs(abs(isnull(abs(a.arm2) - abs(LAG(a.arm2) over (order by a.Angle)), 0)) - abs(isnull(abs(a.arm1) - abs(LAG(a.arm1) over (order by a.Angle)), 0))) as delta
 from
 @srcEllipseArms a
) as x on x.Angle = am.Angle;


--select * from @srcEllipseArms

-- данные после 90 градусов симметричны поэтому можно вставить перевернутую выборку (до 180 градусов)
;with
reverseData as (select
                90 + (90 - Angle) as Angle, 
				arm, LEAD(delta) over (order by Angle) as delta, -- изменение на шаге из 89 в 90 такое же как из 90 в 91  
				arm1, 
				arm2, 
				forceRelation1, 
				forceRelation2
                from
                @srcEllipseArms)
insert into @srcEllipseArms(Angle, arm, delta, arm1, arm2, forceRelation1, forceRelation2)
select 
Angle, 
arm, 
delta, 
arm1, 
arm2, 
forceRelation1, 
forceRelation2 
from reverseData
where
Angle > 90
order by Angle
--return

declare @arms table(Angle float, arm float, delta float, deltaSum float, armPart float, vPart float, arm1 float, arm2 float);

insert into @arms(Angle, arm, delta, arm1, arm2)
select round(Angle,2), arm , delta, arm1, arm2
from @srcEllipseArms
order by Angle

--select * from @arms
--order by Angle

-- объемы проходимые лопастями пропорциональны разности плеч на каждом шаге (delta)
-- поэтому по изменению разности плеч на каждом шаге можно найти долю пройденного объема
-- т.е. на каждом шаге объем меняется на величину изменения результирующего плеча
update am
set
deltaSum = x.deltaSum -- доля объема
from
@arms am
inner join
(select 
 a.Angle,
 (sum(delta) over (order by a.Angle)) as deltaSum -- сумма нарастающим итогом
 from
 @arms a
) as x on x.Angle = am.Angle


--select * from @arms
--order by Angle
--return

declare 
@vUnit float,
@armUnit float;

select
@vUnit = SUM(ABS(delta)), -- объем принятый за единицу
@armUnit = Max(arm) -- рычаг принятый за единицу (1.0)
from @arms

--select @vUnit, @armUnit 

update @arms
set
armPart = arm / @armUnit, -- доля плеча от максимального
vPart = deltaSum / @vUnit; -- доля объема от максиального

--select * from @arms
--order by Angle
--return

-- вставить обратную выборку
;with
reverseData as (select
				180 + (180 - a.Angle) as Angle,
				a.arm,
				LEAD(a.delta) over (order by a.Angle) as delta,
				a.deltaSum,
				a.armPart,
				a.vPart,
				a.arm1, 
				a.arm2
				from
				@arms a)
insert into @arms(Angle, arm, delta, deltaSum, armPart, vPart, arm1, arm2)
select
Angle, 
arm, 
delta, 
deltaSum, 
armPart, vPart, 
arm1, 
arm2
from
reverseData
where
Angle > 180
order by Angle;

select a.*
from @arms a
order by Angle;