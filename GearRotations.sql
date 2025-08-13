/*
расчет для  @diffRelation = 2,7
*/
declare @angleStep float = 1.0; -- шаг поворота вала

declare @PI float = PI();
declare @Rad float = @PI / 180.0;
declare @Grad float = 180.0 / PI();

declare @currentAngle float = 0.0; -- это угол в ВМТ в градусах
declare @currentAngleRad float = 0.0; -- это угол в ВМТ в радианах

declare @r float = 1.0; -- радиус шестерни вала
declare @n float = 0.86; -- элилпсность
declare @relation float = 2.0 -- сколько оборотов делает вал для одного оборота передачи
declare @unit float = 21.48

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
declare @diffRelation float = 2.7 --2.696; -- макс. передаточное отношение
declare @shift float = @n * @r * (@diffRelation - 1.0) / (@diffRelation + 1.0) -- смещение при радиусе шестерни 1.0
declare @r2 float = POWER(@r, 2);

-- для ускорения расчета берем посчитанные  заранее длины единичного эллипса
declare @ellipseLen float = (select len from elen where round(n,2) = 0.86); --(select dbo.EllipseLen(@n));

declare @ellipseR float = @ellipseLen / (2.0 * @PI); -- какому раудиусу круга соответсвует длина эллипса шестерни
declare @midCylinderR float = @ellipseLen * @relation / (2.0 * @PI); -- средний радиус передачи цилиндров
declare @axisDistance float = @ellipseR + @midCylinderR; -- межцентровое расстояние

/*
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
решая уравнение для заданного угла f получаем две x координаты точек пересечения линии пересекающей y в заданной точке с эллипсом
координаты y находим подствляя полученные x координаты в уравнение линии
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

declare @srcEllipseArms table(Angle float, arm1 float, arm2 float, len1 float, len2 float, rarm1 float, rarm2 float, rangle1 float, rangle2 float);
-- расстояния от точек контакта линии и эллипса до оси поворота линии
-- т.е. величина плеч
insert into @srcEllipseArms(Angle, arm1, arm2)
select
ec.Angle,
SQRT(POWER(x1,2) + POWER(@shift + y1, 2)),
SQRT(POWER(x2,2) + POWER(@shift + y2, 2))
from
@ellipseCrosses ec;

update a
set
a.rarm1 = @axisDistance - a.arm1,
a.rarm2 = @axisDistance - a.arm2
from 
@srcEllipseArms a

-- расстояния пройденные по малому и большому ходу
update a
set
a.len1 = isnull(x.len1, 0),
a.len2 = isnull(x.len2, 0)
from 
@srcEllipseArms a
inner join(
select
ax.angle,
SQRT(POWER(ax.arm1, 2) + POWER((LAG(ax.arm1) over (order by ax.angle)), 2) - 2.0 * abs(ax.arm1) * abs(LAG(ax.arm1) over (order by ax.angle)) * COS(@angleStep * @Rad)) as len1,
SQRT(POWER(ax.arm2, 2) + POWER((LAG(ax.arm2) over (order by ax.angle)), 2) - 2.0 * abs(ax.arm2) * abs(LAG(ax.arm2) over (order by ax.angle)) * COS(@angleStep * @Rad)) as len2
--abs(ax.arm1 - LAG(ax.arm1) over (order by ax.angle)) as len1,
--abs(ax.arm2 - LAG(ax.arm2) over (order by ax.angle)) as len2
from 
@srcEllipseArms ax) as x on x.Angle = a.Angle;

-- углы поворота передачи на каждый шаг
update a
set
a.rangle1 = x.angle1 * 1.01269193985761,
a.rangle2 = x.angle2 * 1.01269193985761
from 
@srcEllipseArms a
inner join(
select
ax.angle,
isnull(ACOS((POWER(ax.rarm1, 2) + POWER((LAG(ax.rarm1) over (order by ax.angle)), 2) - POWER(ax.len1, 2)) / (2.0 * ax.rarm1 * (LAG(ax.rarm1) over (order by ax.angle)))) * @Grad, 0)  as angle1,
isnull(ACOS((POWER(ax.rarm2, 2) + POWER((LAG(ax.rarm2) over (order by ax.angle)), 2) - POWER(ax.len2, 2)) / (2.0 * ax.rarm2 * (LAG(ax.rarm2) over (order by ax.angle)))) * @Grad, 0)  as angle2
from 
@srcEllipseArms ax) as x on x.Angle = a.Angle;




select @shift * @unit, @axisDistance * @unit --9,77357701907229, 59,9983131494111

select 
(sum(rangle1) * 2.0) as shortRun, 
(sum(rangle2) * 2.0) as longRun, 
((sum(rangle1) + sum(rangle2)) * 2.0) as fullRun,
90.0 / (sum(rangle1) + sum(rangle2)) from @srcEllipseArms

/*
select 
* 
from @srcEllipseArms
*/

declare @rotations table(Angle float, rangle1 float, rangle2 float);

insert @rotations (Angle, rangle1 , rangle2)
select
Angle, rangle1 , rangle2
from
@srcEllipseArms
order by Angle

insert @rotations(Angle, rangle1 , rangle2)
select
90 + (90 - Angle) + 1,
rangle1, 
rangle2
from
@rotations;

delete @rotations where Angle > 180;

declare @gearAngles table(Angle float, gearAngle float);

insert into @gearAngles(Angle, gearAngle)
select
Angle,
rangle1
from @rotations
order by Angle;

insert into @gearAngles(Angle, gearAngle)
select
180 + (180.0 - Angle) + 1,
rangle2
from @rotations
order by Angle;

delete @gearAngles where Angle > 360;

select * from @gearAngles order by Angle