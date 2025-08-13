/*
расчет для @diffRelation = 2,7
*/

declare @angleStep float = 1.0; -- шаг поворота вала

declare @PI float = PI();
declare @Rad float = @PI / 180.0

declare @currentAngle float = 0.0; -- это угол в ВМТ в градусах
declare @currentAngleRad float = 0.0; -- это угол в ВМТ в радианах

declare @r float = 1.0; -- радиус шестерни вала
declare @n float = 0.86; -- элилпсность


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
declare @diffRelation float = 2.7; --2.696; -- макс. передаточное отношение
declare @shift float = @n * @r * (@diffRelation - 1.0) / (@diffRelation + 1.0) -- смещение при радиусе шестерни 1.0
declare @r2 float = POWER(@r, 2);

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

declare @srcEllipseArms table(Angle float, arm1 float, arm2 float, len1 float, len2 float);
-- расстояния от точек контакта линии и эллипса до оси поворота линии
-- т.е. величина плеч
insert into @srcEllipseArms(Angle, arm1, arm2)
select
ec.Angle,
SQRT(POWER(x1,2) + POWER(@shift + y1, 2)),
SQRT(POWER(x2,2) + POWER(@shift + y2, 2))
from
@ellipseCrosses ec;

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

--select * from @srcEllipseArms order by angle
declare @anglePerLen float;
declare @lenLong float;
declare @lenShort float;
-- соотношение малого и большого хода
select
@lenShort = (sum(len1) * 2.0),
@lenLong = (sum(len2) * 2.0)
from
@srcEllipseArms;


set @anglePerLen = 180.0 / (@lenLong + @lenShort);

declare @LongAngle float;
declare @ShortAngle float;

select 
@LongAngle = (@anglePerLen * @lenLong), 
@ShortAngle = (@anglePerLen * @lenShort)

select 
@LongAngle as LongAngle, 
@ShortAngle as ShortAngle, 
(@ShortAngle / @LongAngle) as AnglesRelation, 
(@LongAngle - @ShortAngle) as AngelsDiff

-- LongAngle	    ShortAngle	        AnglesRelation
-- 64,4238136159827	115,576186384017	0,557414253157012

--select @shift * 21.48 -- 8,4875027027027