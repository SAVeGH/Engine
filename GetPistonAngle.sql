USE [Eng]
GO

/****** Object:  UserDefinedFunction [dbo].[GetPistonAngle]    Script Date: 11.08.2025 13:27:40 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create or alter  function [dbo].[GetPistonAngle]
(
@internalR float,
@volumePerAngle float,
@pistonAngle float
)
returns 
@result table(pistonAngle float, channelS float, channelWidth float, channelAngle float)
as
begin

declare @sideSize float = 0.012;
declare @externalR float = @internalR + @sideSize; -- внешний радиус камеры
declare @pathR float = @internalR + (@sideSize / 2.0); -- радиус средней линии камер
declare @pathLen float = 2.0 * PI() * @pathR; -- длина средней линии
declare @pistonDiffAngle float = 51.1523727680347; -- это полное раскрытие лопастей (разность хода т.е. 180 на диагармме фаз)

-- часть объема при которой происходит продувка
declare @blowVolumePart float = 1.0 - (select min(volumePartRotor) from phases where Angle < 180.0 and Blow = 1);
-- все раскрытие камеры 51 градус. Сколько будет занимать угол продувки
declare @blowChаmberAngle float = @pistonDiffAngle * @blowVolumePart;

-- сколько боковой площали (сектор в одни градус какой площади) приходится на один градус
declare @sPerAngle float = (POWER(@externalR, 2.0) * PI() - POWER(@internalR , 2.0) * PI()) / 360.0;

-- сколько градусов
-- площадь канала
declare @blowS float = @sPerAngle * @blowChаmberAngle;
declare @channelWidth float = @blowS / @sideSize;

-- тор площади сечения @blowS
declare @blowFullV float = @blowS * @pathLen;

declare @blowVPerAngle float = @blowFullV / 360.0;

declare @angleStep float = 0.1;
declare @channelAngle float = 0.0;
declare @actualPistonAngle float = @pistonAngle;

while @channelAngle < (@actualPistonAngle + (@blowChаmberAngle * 2.0))
begin

	declare @pistonPushV float = @volumePerAngle * @angleStep;
	declare @channelIncAngle float = @pistonPushV / (@blowVPerAngle * @angleStep);
	
	set @channelAngle = @channelAngle + @channelIncAngle;
	
	set @actualPistonAngle = @actualPistonAngle + @angleStep;

end

insert into @result(pistonAngle, channelS, channelWidth, channelAngle)
values(@actualPistonAngle, @blowS, @channelWidth, @channelAngle);

return;

end
GO


