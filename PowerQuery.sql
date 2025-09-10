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
declare @cylinderRelation float = 1.1; -- средний диаметр шестарни вала 40 мм. Передаточное к передачам цилиндров 2. Тогда средний радиус передачи цилиндра 40 (диаметр 80)
                                       -- средний радиус камер 44 ((38 + 50) / 2).
                                       -- Отсюда соотношение 44 / 40 = 1.1

declare @atmP float = 100000.0; -- давление Па
declare @atmT float = 300.0; -- температура атмосферы (К)
declare @topT float = 2300.0; -- температура сгорания в ВМТ (К)


-- степень сжатия - 10
-- начальный объем 49 см^3. = 4.9 * 10^-4 м^3 - полный объем включая выхлоп

declare @PI float = PI();
declare @Rad float = @PI / 180.0
declare @compressionRatio float = 8.5;
declare @coldCompressionRatio float = 1.5; --  давление в холодной камере при сжатии (на входе в горячую) 

declare @pistonDiffAngle float = 51.1523727680347;

declare @diffScale float = @pistonDiffAngle / 180.0; -- сколько градусов хода лопастей соответсвует грудусу на диаграмме фаз

--declare @exhaustAngle float = (180.0 - (select max(Angle) from phases where Exhaust is NULL and round(Angle,2) < 180.0)) * @diffScale;
--declare @blowAngle float = (180.0 - (select max(Angle) from phases where Blow is NULL and round(Angle,2) < 180.0)) * @diffScale;
--declare @intakeAngle float = (180.0 - (select min(Angle) from phases where Intake is NULL and round(Angle,2) < 180.0)) * @diffScale;

declare @hotEngVolume float = 0.000049  -- полный объем обоих горячих камер м^3 - 49 см^3 - объем включая окно выхлопа и камеру сгорания (объем в НМТ)
-- проценты пересчитаны для роторного двигателя по доле пройденного объема. Т.е. если выхлоп занимает 38% (68 градусов на сторону т.е. из 180)
-- и открывается при 112 градусах для поршневого, то для роторного такая же доля объема будет только при 130 градусах.
-- Т.е. доля пройденного объема в обоих случаях 0.806291793711013

-- Так как сумма углов перепуск + впуск должна быть меньше или равна углу выхлопа то приняты следующие углы:
-- выхлоп 14 градусов - 14 / 60 = 0.23... Это доля объема на котором откроется выхлоп
-- перепуск 7 градусов - 0.116...
-- впуск 7 градусов
--declare @exhaustVPart float = @exhaustAngle / @pistonDiffAngle; -- 60 градусов - разница хода лопастей. Т.е. ход лопастей не включает камеру сгорания. Т.е. весь 
                                                                -- объем горячей камеры это ход лопастей + объем камеры сгорания. 14/60 это доля от хода лопастей, а не всей камеры горячей.

--declare @exhaustVPart float = 1.0 - (select max(volumePartRotor) from phases where Angle < 180.0 and Exhaust is NULL);

--declare @blowVPart float = 1.0 - (select max(volumePartRotor) from phases where Angle < 180.0 and Blow is NULL);
--declare @blowVPart float = @blowAngle / @pistonDiffAngle;
--declare @intakeVPart float = @intakeAngle / @pistonDiffAngle;
--declare @intakeVPart float = (select min(volumePartRotor) from phases where Angle < 180.0 and Intake is NULL);



declare @exhaustVPart float = 1.0 - (select max(volumePartRotor) from phases where Angle < 180.0 and Exhaust is NULL);
declare @blowVPart float = 1.0 - (select max(volumePartRotor) from phases where Angle < 180.0 and Blow is NULL);
declare @intakeVPart float = (select min(volumePartRotor) from phases where Angle < 180.0 and Intake is NULL);

declare @exhaustAngle float = @exhaustVPart * @pistonDiffAngle;
declare @blowAngle float = @blowVPart * @pistonDiffAngle;
declare @intakeAngle float = @intakeVPart * @pistonDiffAngle;


-- т.е. если размер камеры сжигания x то сжимаемая часть это (x * @compressionRatio - x) и равна она (1.0 - @exhaustVPart) - доле изменяемого объема проходимого лопастью при сжатии 
declare @hotChamberV float = @hotEngVolume / 2.0; -- вся горячая камера вместе с выхлопом (НМТ) и камерой сгорания
declare @hotTopChamberV float;-- = ((1.0 - @exhaustVPart) / (@compressionRatio - 1)) * @hotChamberV;

--select @hotTopChamberV * (@compressionRatio - 1) / (1.0 - @exhaustVPart)

-- вся горячая камера состоит из:
-- камеры сгорания: x
-- весь сжатый объем в разжатом состоянии это x * @compressionRatio. Тогда размер сжимаемого пространства (без зоны выхлопа): x * (@compressionRatio - 1)
-- т.е. при степени сжатия 10 одна часть объема это камера сгорания и 9 частей сжимаемая часть объема
-- Тогда часть проходимая лопастью при сжатии это x * (@compressionRatio - 1) = (1 - @exhaustVPart)
-- отсюда пропорция: x * (@compressionRatio - 1) это (1 - @exhaustVPart)
--                                 y             это        1
-- тогда y = x * (@compressionRatio - 1) / (1 - @exhaustVPart) - это весь объем проходимый лопастью включая выхлоп
-- тогда объем проходимый при выхлопе это: (x * (@compressionRatio - 1) / (1 - @exhaustVPart)) * @exhaustVPart
-- получаем уравнение:
-- @hotChamberV = x + x * (@compressionRatio - 1) + (x * (@compressionRatio - 1) / (1 - @exhaustVPart)) * @exhaustVPart
-- отсюда x + x * (cmp - 1) + (x * (cmp - 1) / (1 - ext)) * ext = a
-- отношение (ext / (1 - ext)) это n 
-- x + x * (cmp - 1) + x * (cmp - 1) * n = a
-- откроем скобки в первой части выражения
-- x + x * cmp - x + x * (cmp - 1) * n = a
-- x * cmp + x * (cmp - 1) * n = a
-- выносим x
-- x * (cmp + (cmp - 1) * n) = a
-- x = a / (cmp + (cmp - 1) * n)

-- Т.е. x (@hotTopChamberV) это:
set @hotTopChamberV = @hotChamberV / (@compressionRatio + (@compressionRatio - 1) * (@exhaustVPart / (1 - @exhaustVPart)));

-- весь объем проходимый лопастью (сжимаемый объем без камеры сгорания + выхлоп) = x * (cmp - 1) / (1 - ext)
declare @bladePassV float = (@hotTopChamberV * (@compressionRatio - 1) / (1 - @exhaustVPart));
declare @exhaustPassV float = @bladePassV * @exhaustVPart;
-- объем который проходит лопасть сжимая камеру после перекрытия вхлопа
declare @compressionHotChamberV float = @bladePassV - @exhaustPassV;
-- весь сжимаемый объем включая камеру сгорания после перекрытия вхлопа
declare @compressableHotChamberV float = @compressionHotChamberV + @hotTopChamberV;

declare @blowPassV float = @bladePassV * @blowVPart;
declare @intakePassV float = @bladePassV * @intakeVPart;

-- в холодной камере сжимается такой же объем как и в горячей т.к. сумма перепуск + впуск равна вхлопу (для 2 атм)
declare @compressionColdChamberV float = @compressionHotChamberV * (1.0 / (@coldCompressionRatio - 1.0)); 
-- перед открытием перепуска объем сжатой холодной камеры будет @compressionColdChamberV т.к. давление в ней будет 2 атм.
-- (т.е. сжали такой же объем как остался). Но лопасть еще будет двигаться 7 градусов на сжатие
-- После полного прохода лопасти на сжатие размер холодной камеры будет @compressionColdChamberV - @blowPassV
declare @coldFullChamberV float = @compressionColdChamberV - @blowPassV + @bladePassV;

-- объем проходимый лопастью - это @bladePassV и составляет он @pistonDiffAngle
declare @volumePerAngle float = @bladePassV / @pistonDiffAngle
--select @volumePerAngle
-- отсюда угол камеры сгорания - это объем камеры сгорания деленный на удельный объем на угол
declare @hotTopChamberAngle float = @hotTopChamberV / @volumePerAngle;

declare @coldFullChamberAngle float = @coldFullChamberV / @volumePerAngle;

-- в 180 градусах 2 поршня одна камера сгорания и одна холодная камера
declare @pistonAngle float = (180.0 - (@hotTopChamberAngle + @coldFullChamberAngle)) / 2.0;

--select @pistonAngle

declare @pistonV float = @volumePerAngle * @pistonAngle;

declare @minColdChamberV float = @compressionColdChamberV - @blowPassV;

declare @minColdChamberAngle float = @compressionColdChamberV / @volumePerAngle - (@exhaustAngle / 2.0);

--select @minColdChamberAngle

-- весь объем тора для двигателя
declare @fullV float = @pistonV * 4.0 + 2.0 * (@coldFullChamberV + @hotTopChamberV);

declare @compressableColdChamberV float = @coldFullChamberV - @blowPassV;

--------------------------------------------------------------------------------------------------------------------------------
declare @k float = 7.0 / 5.0; -- постоянная адиабаты = 7/5 - для двухатомного газа
declare @angleStep float = 1.0; -- шаг поворота вала

-- для горячей камеры

-- константа цикла на момент закрытия выхлопа (перед сжатием) т.е. для объема без учета выхлопа
declare @lowCycleConstant float = @atmP * POWER(@compressableHotChamberV, @k); -- P(V^k) = const
-- надо найти давление после зажигания
declare @hotCompressionP float = @lowCycleConstant / POWER(@hotTopChamberV, @k);
-- константа на момент закрытия выхлопа (перед сжатием)
declare @compressionConstantH float = @atmP * (@compressableHotChamberV) / @atmT; -- PV / T = const

declare @hotCompressionT float = @hotCompressionP * @hotTopChamberV / @compressionConstantH;

declare @burnP float = @compressionConstantH * @topT / @hotTopChamberV;
-- константа на момент зажигания
declare @highCycleConstant float = @burnP * POWER(@hotTopChamberV, @k);

-- для холодной камеры

-- константа цикла на момент закрытия впуска
declare @coldCompressionCycleConstant float = @atmP * POWER(@compressableColdChamberV, @k); -- P(V^k) = const

-- константа на момент закрытия впуска (перед сжатием)
declare @compressionConstantC float = @atmP * (@compressableColdChamberV) / @atmT; -- PV / T = const

-- константа цикла на момент закрытия перепускного окна
declare @coldDecompressionCycleConstant float = @atmP * POWER(@compressionColdChamberV, @k); -- P(V^k) = const

-- константа на момент закрытия перепускного окна перед разрежением
declare @decompressionConstantC float = @atmP * (@compressionColdChamberV) / @atmT; -- PV / T = const




declare @cycleConstant float = @highCycleConstant;

declare @currentAngle float = 0.0; -- это угол в ВМТ в градусах
declare @currentAngleRad float = 0.0; -- это угол в ВМТ в радианах

declare @phase bit = 0;
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

------------------------------------------------------------------------------------------------

-- для ускорения расчета берем посчитанные  заранее длины единичного эллипса
declare @ellipseLen float = (select len from elen where round(n,2) = round(@n,2)); --(select dbo.EllipseLen(@n));

declare @ellipseR float = @ellipseLen / (2.0 * @PI); -- какому раудиусу круга соответсвует длина эллипса шестерни
declare @midCylinderR float = @ellipseLen * @relation / (2.0 * @PI); -- средний радиус передачи цилиндров
declare @axisDistance float = @ellipseR + @midCylinderR; -- межцентровое расстояние

declare @cylinderMomentArm float = @midCylinderR * @cylinderRelation; -- плечо момента цилиндра

set @currentAngle = 0;

while @currentAngle <= 90.0 
begin

	declare @arm1 float;
	declare @arm2 float;

	select @arm1 = arm1, @arm2 = arm2 
	from @srcEllipseArms 
	where Angle = round(@currentAngle,2);

	declare @cylArm1 float = IIF(@axisDistance - @arm1 <= 0, 0, @axisDistance - @arm1);
	declare @cylArm2 float = IIF(@axisDistance - @arm2 <= 0, 0, @axisDistance - @arm2);
	declare @forceRelation1 float = IIF(@cylArm1 = 0, 0 , @cylinderMomentArm / @cylArm1);
	declare @forceRelation2 float = IIF(@cylArm2 = 0, 0 , @cylinderMomentArm / @cylArm2);

	-- коэффициенты передачи момента цилиндров на шестерни
	-- они не меняются при приведении к 1
	update @srcEllipseArms
	set 
	forceRelation1 = @forceRelation1, 
	forceRelation2 = @forceRelation2
	where
	Angle = round(@currentAngle,2)

	set @currentAngle = @currentAngle + @angleStep;

end

--select ea.*, @axisDistance, @cylinderMomentArm,@shift from @srcEllipseArms ea
--return
------------------------------------------------------------------------------------------------

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

declare @arms table(Angle float, arm float, delta float, deltaSum float, armPart float, vPart float, arm1 float, arm2 float, forceRelation1 float, forceRelation2 float);

insert into @arms(Angle, arm, delta, arm1, arm2, forceRelation1, forceRelation2)
select round(Angle,2), arm , delta, arm1, arm2, forceRelation1, forceRelation2
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
				a.arm2, 
				a.forceRelation1, 
				a.forceRelation2
				from
				@arms a)
insert into @arms(Angle, arm, delta, deltaSum, armPart, vPart, arm1, arm2, forceRelation1, forceRelation2)
select
Angle, 
arm, 
delta, 
deltaSum, 
armPart, vPart, 
arm1, 
arm2, 
forceRelation1, 
forceRelation2
from
reverseData
where
Angle > 180
order by Angle;

--select a.*--, a.forceRelation2 / a.forceRelation1
--from @arms a
--order by Angle
--return
------------------------------------------------------------------------------------------------------------------------------
declare @unit float = 0.02148 -- размер единицы в м

declare @pistonS float = 0.000574733352173298 -- площадь поршня м^2 (574 мм^2)
set @currentAngle = 0;
set @phase = 0; -- рабочий ход
set @cycleConstant = @highCycleConstant; -- рабочий ход

declare @exhaustAngleStart float = (select min(Angle) from phases where Exhaust = 1);
declare @blowAngleStart float = (select min(Angle) from phases where Blow = 1);
declare @exhaustAngleEnd float = (select max(Angle) from phases where Exhaust = 1 and Angle < 181);
declare @blowAngleEnd float = (select max(Angle) from phases where Blow = 1 and Angle < 181);
declare @volumePartExhaust float;
declare @IsExhaust bit = 0;
declare @IsBlow bit = 0; 

declare @arm float;
declare @volumePart float;
declare @stepArm1 float;
declare @stepArm2 float;
declare @stepRelation1 float;
declare @stepRelation2 float;
declare @stepWork float;

declare @stepVolume float;
declare @stepP float;
declare @stepT float;

declare @stepF float;

declare @mMinus float;
declare @mPlus float;
declare @stepM float;
declare @pDiff float;
declare @tDiff float;

--select * from @arms order by angle

-- Cycle для горячей камеры
while @currentAngle <= 360.0 
begin
	
	select
	@arm = arm,
	@volumePart = vPart,
	@stepArm1 = arm1,
	@stepArm2 = arm2,
	@stepRelation1 = forceRelation1,
	@stepRelation2 = forceRelation2
	from @arms 
	where Angle = round(@currentAngle,2);

	set @IsExhaust = isnull((select Exhaust from phases where Angle = @currentAngle), 0);
	set @IsBlow = isnull((select Blow from phases where Angle = @currentAngle), 0); 
	
	set @stepVolume = @bladePassV * @volumePart + @hotTopChamberV;
	
	set @stepP = @cycleConstant / POWER(@stepVolume, @k);
	
	set @stepT = @stepP * @stepVolume / @compressionConstantH;

	if(@IsExhaust = 1 and @IsBlow = 0 and @phase = 0)
	begin

		if(@pDiff is NULL)
		begin		
			set @pDiff = @stepP - @atmP;
			set @tDiff = @stepT - @atmT;
		end
	-- открылся выхлоп но продувка еще закрыта. Давление падает от начала выхлопа до начала впуска
		set @stepP = (@atmP + @pDiff * ((@blowAngleStart - @currentAngle) / (@blowAngleStart - @exhaustAngleStart))); 
		set @stepT = (@atmT + @tDiff * ((@blowAngleStart - @currentAngle) / (@blowAngleStart - @exhaustAngleStart))); 
	end
	else if(@IsBlow = 1 or @IsExhaust = 1)
	begin
	-- открылась продувка. Давление атмосферное
	-- или еще открыт выхлоп
		set @stepP = @atmP;
		set @stepT = @atmT;		
	end

	set @stepF = @pistonS /*м^2*/ * @stepP /* Па  (Н/м^2)*/; -- сила действующая на поршень (H) 
	
	if(round(@currentAngle,2) = 180.0)
	begin
		set @phase = 1; -- сжатие
		set @cycleConstant = @lowCycleConstant; -- такт сжатия
	end
	
	-- @stepArm1 - относительное плечо 0..1
	-- @stepArm1 * @stepRelation1 - относительное эффективное плечо
	-- @stepArm1 * @stepRelation1 * @unit - реальное эффективное плечо в м
	-- @angleStep * @Rad - шаг интегрирования в радианах (т.к. работа находится умножением на угол в радианах)
	-- @stepF - сила в Н
	set @mMinus = @stepArm1 /*м*/ * @stepF /*H*/ * @stepRelation1 * /*@angleStep * @Rad */ @unit ; -- момент опорного ротора Н*м
	set @mPlus = @stepArm2 * @stepF * @stepRelation2 * /*@angleStep * @Rad */ @unit; -- момент ведущего ротора
	set @stepM = @mPlus - @mMinus; -- результирующий момент
	set @stepWork = @stepM * @angleStep * @Rad; -- Ватт 

	declare @vp1 float;
	select @vp1 = volumePartRotor from phases where round(Angle,2) = @currentAngle 
	
	insert into @resultHot(phase, angle, stepP, stepV, stepT, stepF, stepM,  stepWork, volumePart)
	values(@phase, round(@currentAngle,2), @stepP, @stepVolume, @stepT, @stepF, @stepM, @stepWork, @volumePart)
	
	set @currentAngle = @currentAngle + @angleStep;
end

--select * from @resultHot order by angle
/*
select
((select sum(stepWork) from @resultHot where angle < 181) - 
(select sum(stepWork) from @resultHot where angle > 180))
*/
--return


--------------------------------------------------------------------------------------------------------------------------------------------------------------------
declare @volumePartBlow float;

set @currentAngle = 0;
set @cycleConstant = @coldCompressionCycleConstant; -- холодный ход. При Angle = 0 в холодной камере начинается сжатие. После 180 градусов - разрежение.

declare @IsIntake bit = 0;
declare @cycleConstantC float = @compressionConstantC; 
declare @stepAtmF float;

-- Cycle для холодной камеры
while @currentAngle <= 360.0 
begin
	
	select
	@arm = arm,
	@volumePart = 1.0 - vPart, -- в холодной камере обратное соотношение
	@stepArm1 = arm1,
	@stepArm2 = arm2,
	@stepRelation1 = forceRelation1,
	@stepRelation2 = forceRelation2
	from @arms 
	where Angle = round(@currentAngle, 2);

	set @IsIntake = isnull((select Intake from phases where Angle = @currentAngle), 0);
	set @IsBlow = isnull((select Blow from phases where Angle = @currentAngle), 0); 
	
	set @stepVolume = @bladePassV * @volumePart + @minColdChamberV;
	
	set @stepP = @cycleConstant / POWER(@stepVolume, @k);
	
	set @stepT = @stepP * @stepVolume / @cycleConstantC;

	if(round(@currentAngle,2) >= 180.0)
	begin
		set @phase = 1; -- сжатие
		set @cycleConstant = @coldDecompressionCycleConstant; 
		set @cycleConstantC = @decompressionConstantC;
		set @stepP = @atmP + (@atmP - @stepP);
	end

	
	if(@IsIntake = 1 or @IsBlow = 1)
	begin
		set @stepP = @atmP;
		set @stepT = @atmT;
	end

	set @stepF = @pistonS /*м^2*/ * @stepP /* Па  (Н/м^2)*/; -- сила действующая на поршень (H)

	set @stepAtmF = @pistonS /*м^2*/ * @atmP;

	if(round(@currentAngle,2) = 180.0)
	begin
		set @phase = 1; -- сжатие
		set @cycleConstant = @coldDecompressionCycleConstant; -- такт сжатия
		set @cycleConstantC = @decompressionConstantC;
	end
	
	set @mMinus = @stepArm1 /*м*/ * @stepF /*H*/ * @stepRelation1 * /*@angleStep * @Rad */ @unit; -- момент опорного ротора Н*м
	set @mPlus = @stepArm2 * @stepF * @stepRelation2 * /*@angleStep * @Rad */ @unit; -- момент ведущего ротора
	set @stepM = @mPlus - @mMinus; -- результирующий момент
	set @stepWork = @stepM * @angleStep * @Rad;
	
	insert into @resultCold(phase, angle, stepP, stepV, stepT,  stepF,  stepM,  stepWork)
	values(@phase, round(@currentAngle,2), @stepP, @stepVolume, @stepT,  @stepF, @stepM, @stepWork)
	
	set @currentAngle = @currentAngle + @angleStep;
end
--------------------------------------------------------------------------------------------------------------------------

--select * from @resultCold order by angle
--return


declare @resultM table(angle float, stepM float)

insert into @resultM(angle, stepM)
select
rh.angle,
IIF(rh.angle < 180, rh.stepM - rc.stepM, rh.stepM + rc.stepM)
from
@resultHot rh
inner join @resultCold rc on ROUND(rh.angle, 2) = ROUND(rc.angle, 2);

--select * from @resultM

--return



---------------------------------------------------------------------------------------------------
declare @hotExpansionWork float;
declare @hotCompressionWork float;
declare @coldWork float;

select 
@hotExpansionWork = sum(stepWork) 
from 
@resultHot hw 
inner join phases p on hw.angle = p.Angle
where 
hw.angle < 181
and
isnull(p.Exhaust,  0) = 0;

select 
@hotCompressionWork = sum(stepWork) 
from 
@resultHot hw 
inner join phases p on hw.angle = p.Angle
where 
hw.angle > 180
and
isnull(p.Exhaust,  0) = 0;

select 
@coldWork = sum(stepWork) 
from 
@resultCold cw
inner join phases p on cw.angle = p.Angle
where
isnull(p.Blow, 0) != 1
and
isnull(p.Intake, 0) != 1

declare @coldWork1 float
declare @coldWork2 float

select 
@coldWork1 = sum(stepWork) 
from 
@resultCold cw
inner join phases p on cw.angle = p.Angle
where
cw.Angle < 181
and
(
isnull(p.Blow, 0) != 1
and
isnull(p.Intake, 0) != 1)

select 
@coldWork2 = sum(stepWork) 
from 
@resultCold cw
inner join phases p on cw.angle = p.Angle
where
cw.Angle > 180
and
(
isnull(p.Blow, 0) != 1
and
isnull(p.Intake, 0) != 1)

select @hotExpansionWork as HotWork, @hotCompressionWork as HotCompressionWork, @coldWork as ColdWork, @coldWork1 as ColdCompressionWork, @coldWork2 as ColdExpansionWork, (@hotExpansionWork - (@hotCompressionWork + @coldWork)) * 2.0 as ResultWork

--return

--select sum(stepWork) from @resultHot where angle < 181
--select sum(stepWork) from @resultHot where angle > 180
--select sum(stepWork) from @resultCold

--select * from @resultCold
--return
--end

--select sum(stepWork) from @resultCold--order by angle
--select * from @resultCold order by angle
--select sum(stepWork) from @resultCold
/*
select
(((select sum(stepWork) from @resultHot where angle < 181) - 
(select sum(stepWork) from @resultHot where angle > 180)) - (select sum(stepWork) from @resultCold)) * 2.0
*/

--0,158258180179584 -- на одну камеру
-- 0,316516360359169 -- на обе камеры


--select sum(stepM) from @result where angle < 181
--select sum(stepM) from @result where angle > 180
/*
select
((select sum(stepM) from @result where angle < 181) - 
(select sum(stepM) from @result where angle > 180)),
(select max(stepM) from @result)
*/

--GO


