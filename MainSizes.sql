-- начальный объем 49 см^3. = 4.9 * 10^-4 м^3 - полный объем включая выхлоп

declare @PI float = PI();
declare @Rad float = @PI / 180.0
declare @hotCompressionRatio float = 8.5; -- это реальная степень сжатия после перекрытия выхлопа до ВМТ
declare @coldCompressionRatio float = 1.5; -- степень сжатия в холодной камере при сжатии (на входе в горячую) 

declare @pistonDiffAngle float = 51.1523727680347; -- это полное раскрытие лопастей (разность хода т.е. 180 на диагармме фаз)
                                                   -- Угол камеры сгорания не содержится в ходе лопастей

declare @diffScale float = @pistonDiffAngle / 180.0; -- сколько градусов хода лопастей соответсвует грудусу на диаграмме фаз

declare @exhaustAngle float = (180.0 - (select max(Angle) from phases where Exhaust is NULL and round(Angle,2) < 180.0)) * @diffScale;
declare @blowAngle float = (180.0 - (select max(Angle) from phases where Blow is NULL and round(Angle,2) < 180.0)) * @diffScale;
declare @intakeAngle float = (180.0 - (select min(Angle) from phases where Intake is NULL and round(Angle,2) < 180.0)) * @diffScale;

declare @hotEngVolume float = 0.000049;

declare @exhaustVPart float = @exhaustAngle / @pistonDiffAngle;  -- 60 градусов - разница хода лопастей. Т.е. ход лопастей не включает камеру сгорания. Т.е. весь 
                                                                 -- объем горячей камеры это ход лопастей + объем камеры сгорания. 
																 -- 14/60 это доля от хода лопастей, а не всей камеры горячей.

declare @blowVPart float = @blowAngle / @pistonDiffAngle;
declare @intakeVPart float = @intakeAngle / @pistonDiffAngle;

--select @exhaustVPart return 
declare @hotChamberV float = @hotEngVolume / 2.0; -- вся горячая камера вместе с выхлопом (НМТ) и камерой сгорания
declare @hotTopChamberV float;

--select @hotTopChamberV * (@hotCompressionRatio - 1) / (1.0 - @exhaustVPart)

-- вся горячая камера состоит из:
-- камеры сгорания: x
-- весь сжатый объем в разжатом состоянии это x * @hotCompressionRatio. Тогда размер сжимаемого пространства (без зоны выхлопа): x * (@hotCompressionRatio - 1)
-- т.е. при степени сжатия 10 одна часть объема это камера сгорания и 9 частей сжимаемая часть объема
-- т.е. если размер камеры сгорания x то сжимаемая часть это (x * @hotCompressionRatio - x) и равна она (1.0 - @exhaustVPart) - доле изменяемого объема проходимого лопастью при сжатии 
-- Тогда часть проходимая лопастью при сжатии это x * (@hotCompressionRatio - 1) = (1 - @exhaustVPart)
-- отсюда пропорция: x * (@hotCompressionRatio - 1) это (1 - @exhaustVPart)
--                                 y             это        1
-- тогда y = x * (@hotCompressionRatio - 1) / (1 - @exhaustVPart) - это весь объем проходимый лопастью включая выхлоп
-- тогда объем проходимый при выхлопе это: (x * (@hotCompressionRatio - 1) / (1 - @exhaustVPart)) * @exhaustVPart
-- получаем уравнение:
-- @hotChamberV = x + x * (@hotCompressionRatio - 1) + (x * (@hotCompressionRatio - 1) / (1 - @exhaustVPart)) * @exhaustVPart
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
set @hotTopChamberV = @hotChamberV / (@hotCompressionRatio + (@hotCompressionRatio - 1) * (@exhaustVPart / (1 - @exhaustVPart)));

-- весь объем проходимый лопастью (сжимаемый объем без камеры сгорания + выхлоп) = x * (cmp - 1) / (1 - ext)
declare @bladePassV float = (@hotTopChamberV * (@hotCompressionRatio - 1) / (1 - @exhaustVPart));
declare @exhaustPassV float = @bladePassV * @exhaustVPart;
-- объем который проходит лопасть сжимая камеру после перекрытия вхлопа
declare @compressionHotChamberV float = @bladePassV - @exhaustPassV;
-- весь сжимаемый объем включая камеру сгорания после перекрытия выхлопа
declare @compressableHotChamberV float = @compressionHotChamberV + @hotTopChamberV;

declare @blowPassV float = @bladePassV * @blowVPart;
declare @intakePassV float = @bladePassV * @intakeVPart;

--select @blowVPart,@intakeVPart,@exhaustVPart return

-- в холодной камере сжимается такой же объем как и в горячей 
declare @compressionColdChamberV float = @compressionHotChamberV * (1.0 / (@coldCompressionRatio - 1.0)); 
-- перед открытием перепуска объем сжатой холодной камеры будет @compressionColdChamberV  (т.е. @compressionHotChamberV увеличенный на @coldCompressionRatio)
-- Но лопасть еще будет двигаться несколько градусов на сжатие
-- После полного прохода лопасти на сжатие размер холодной камеры будет @compressionColdChamberV - @blowPassV
-- сжатая камера минус ход в 7 градусов плюс ход лопасти (впуск покрывается ходом лопасти - поэтому не вычитается )
declare @coldFullChamberV float = @compressionColdChamberV - @blowPassV + @bladePassV;


-- объем проходимый лопастью - это @bladePassV и составляет он @pistonDiffAngle
declare @volumePerAngle float = @bladePassV / @pistonDiffAngle
--select @volumePerAngle
-- отсюда угол камеры сгорания - это объем камеры сгорания деленный на удельный объем на угол
declare @hotTopChamberAngle float = @hotTopChamberV / @volumePerAngle;

declare @coldFullChamberAngle float = @coldFullChamberV / @volumePerAngle;

-- в 180 градусах 2 поршня одна камера сгорания и одна холодная камера
declare @pistonAngle float = (180.0 - (@hotTopChamberAngle + @coldFullChamberAngle)) / 2.0;



select 
@pistonAngle as basePistonAngle, 
@hotTopChamberAngle as hotTopChamberAngle,  
@coldFullChamberAngle as coldFullChamberAngle,
(@pistonAngle * 2.0 + @hotTopChamberAngle + @coldFullChamberAngle) as AnglesSum




declare @pistonV float = @volumePerAngle * @pistonAngle;

declare @minColdChamberV float = @compressionColdChamberV - @blowPassV;

--declare @minColdChamberAngle float = @compressionColdChamberV / @volumePerAngle - (@exhaustAngle / 2.0);

--select @minColdChamberAngle

-- весь объем тора для двигателя
declare @fullV float = @pistonV * 4.0 + 2.0 * (@coldFullChamberV + @hotTopChamberV);

--declare @blowVPart float = @exhaustVPart / 2.0; -- половина от 14 градусов
--declare @intakeVPart float = @exhaustVPart / 2.0; -- половина от 14 градусов



declare @sideSize float = 0.012 -- 12 мм высота камеры (м)
declare @sideR float = @sideSize / 2.0;

declare @pistonRS float = @PI * POWER(@sideR, 2); -- площадь закруглений лопасти

declare @internalR float = 0.01 -- радиус 10 мм - внутренний радиус камеры сгорания начальный
declare @rStep float = 0.001 -- 1 мм шаг расчета

declare @sizes table(internalR float, externalR float, h float, fullSize float, relation float, fullRelation float, S float, pistonAngle float, channelWidth float, channelAngle float);
--declare @sizes table(internalR float, externalR float, h float, fullSize float, relation float, fullRelation float, S float);

while round(@internalR,3) <= 0.05
begin

	declare @externalR float = @internalR + @sideSize; -- внешний радиус камеры
	declare @pathR float = @internalR + (@sideSize / 2.0) -- радиус средней линии камер
	declare @pathLen float = 2.0 * @PI * @pathR; -- длина средней линии
	declare @torV float = @pathLen * @pistonRS; -- объем занятый закруглениями (площадь закруглений умножить на длину средней линии)
	declare @restV float = @fullV - @torV; -- остаток объема
	declare @restS float = @restV / @pathLen; -- площадь вдоль средней линии
	declare @h float = @restS / @sideSize; -- длина камеры т.к. площадь остаточного объема это прямоугольник a * b
	declare @s float = @restS + @pistonRS;
	
	declare @pAngle float;
	declare @channelWidth float;
	declare @channelAngle float;
	select 
	@pAngle = pistonAngle,
	@channelWidth = channelWidth,
	@channelAngle = channelAngle
	from 
	dbo.GetPistonAngle(@internalR, @volumePerAngle, @pistonAngle);
	
	insert into @sizes(internalR, externalR, h, fullSize /*габаритный размер*/, relation, fullRelation /*отношение габаритов*/, s /*площадь поршня*/, pistonAngle, channelWidth, channelAngle)
	values(@internalR, @externalR, @h, @h + @sideSize,(@h / @sideSize), ((@h + @sideSize) / @sideSize), @s, @pAngle, @channelWidth, @channelAngle)
	
	
	set @internalR = @internalR + @rStep;
end

select * from @sizes

-- высота камеры сгорания 12 мм

-- размер камер общий
-- internalR	externalR	h	                fullSize	        relation	        fullRelation        S                       pistonAngle         channelWidth         channelAngle
-- 0,038	    0,05	  0,0384696680536721	0,0504696680536721	3,20580567113934	4,20580567113934	0,000574733352173298	37,4110049828676	0,00537561409614254  60,0514349355843

-- угловой размер камеры сгорания
-- 4.35742434690666

-- угловой размер лопасти
-- 37.4110049828676

-- угол начала канала продувки от кромки лопасти при полностью раскрытой холоной камере
--10.3856030845143



-- свеча 10 x 8.6 (под ключ 14, резьба M10)
-- диаметр расточки 1,155 * 14 = 16,7
