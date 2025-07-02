--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetDowntimeV2RailWorker';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetDowntimeV2RailWorker'))
drop FUNCTION GetDowntimeV2RailWorker;
GO
CREATE FUNCTION GetDowntimeV2RailWorker
	(@StartDateTime DateTime2,
	@EndDateTime DateTime2,
	@machineName varchar(255))
RETURNS @table TABLE ( 
	Machine varchar(255), 
	KPIName varchar(255), 
	KPICalculationBase varchar(255), 
	KPIDateTime DateTime2,  
	KPIDateTimeEndOfCalculation DateTime2,
	KPIFloatValue float)  
BEGIN;
			
	Declare @SAPMachine varchar(255);
	Declare @MainStation varchar(255);
	Declare @IsProductionRunning bit = 0;
	Declare @LastShiftStart DateTime2;
	Declare @LastShiftEnd DateTime2;
	Declare @IsShiftRunning bit = 0;
	Declare @KPIDateTimeEnd DateTime2;
	DECLARE @StatusId int;
	Declare @KPIFloatValue float;
	Declare @KPIIdentifier varchar(20)
	Declare @SumDateDif bigint;
	Declare @DateDif bigint;
	Declare @SumKPIFloatValueEffi float;
	Declare @KPIDateTimeStart DateTime2;
	Declare @SumDateDifShift bigint;
	Declare @SumKPIFloatValueShiftEffi float;
	Declare @SumDateDifProd bigint;
	Declare @SumKPIFloatValueProdEffi float;
	Declare @SumDateDifShiftProd bigint;
	Declare @SumKPIFloatValueShiftProdEffi float;
	Declare @ResultKPIFloatValueShiftProdEffi float = 0.0;
	Declare @ResultKPIFloatValueProdEffi float = 0.0;
	Declare @getKPIs CURSOR;
	Declare @KPICalculationBase varchar(255) = 'All';
	declare @MachineLoadingTimes table (ProductionTime datetime2, MachineLoadingTimeInSec float);
	declare @SingleMachineLoadingTime float = 0.0;
	declare @MachineLoadingTime float = 0.0;
	declare @MachineLoadingTimeShift float = 0.0;
	declare @isMultiPalletMachine float = 0.0;

	SELECT @MainStation=[TextValue]
		FROM [smartKPIMachineKeyValueData]
		where PropertyKey = 'MainStationForLineStatus'
		and Machine = @machineName;

	SELECT @SAPMachine=[TextValue]
	  FROM [smartKPIMachineKeyValueData]
	  where Machine = @machineName
	  and PropertyKey = 'SAPWorkcenterNumber';
			


	SELECT TOP (1) 
		@IsProductionRunning=case when [Status] = 'KBMaschStatus.1.Productive' then 1
		when [Status] = 'KBMaschStatus.1.PieceChange' then 1
		else 0 end
		FROM [dbo].[smartKPIMachineStatusData]
		where Machine = @MainStation
		and [StatusTime] <= @StartDateTime
		and StatusType = 'Operator Screen'
		order by [StatusTime] desc;

			
	SELECT top(1) @LastShiftStart=[StartTime], @LastShiftEnd=[EndTime]  
		from [shiftCalendar]
		where [shiftCalendar].[Machine] = @SAPMachine
		and [shiftCalendar].[StartTime]  < @StartDateTime
		order by [StartTime] desc;
			
	if (@LastShiftEnd is null or @LastShiftEnd < @StartDateTime)
		set @IsShiftRunning = 0;
	else
		set @IsShiftRunning = 1;
	
	SET @KPIDateTimeStart = @StartDateTime;
	set @SumDateDif = 0;
	set @SumKPIFloatValueEffi = 0;
	set @SumKPIFloatValueShiftEffi = 0;
	set @SumDateDifShift = 0;
	set @SumKPIFloatValueProdEffi = 0;
	set @SumDateDifProd = 0;
	set @SumKPIFloatValueShiftProdEffi = 0;
	set @SumDateDifShiftProd = 0;
	set @ResultKPIFloatValueProdEffi = 0;
	set @ResultKPIFloatValueShiftProdEffi = 0;

	
	insert into @MachineLoadingTimes (ProductionTime, MachineLoadingTimeInSec)
	select ProductionTime, isnull(MachineLoadingTimeInSec,0)
		from GetRailPerformanceLossV2Detail(@StartDateTime, @EndDateTime, @machineName);



	SET @getKPIs = CURSOR FOR 
		select KPIDateTime, Id, KPIFloatValue, Identifier COLLATE database_default from
			(select [CreationTime] CreationTime, [StatusTime] KPIDateTime, Id, case when [Status] = 'KBMaschStatus.1.Productive' then 1 when [Status] = 'KBMaschStatus.1.PieceChange' then 1 else 0 end as KPIFloatValue, 'Prod' COLLATE database_default as Identifier from [smartKPIMachineStatusData]
									where [Machine] = @MainStation 
									and StatusType = 'Operator Screen'
									and [StatusTime] between @StartDateTime and @EndDateTime
			union
			SELECT [StartTime],[StartTime], 1, 1, 'ShiftStart'
								from [shiftCalendar]
								where [shiftCalendar].[Machine] = @SAPMachine  COLLATE database_default
								and [shiftCalendar].[StartTime] between @StartDateTime and @EndDateTime
								and [Qualifier] = 'W'
			union
			SELECT [EndTime],[EndTime], 0, 0, 'ShiftEnd'
								from [shiftCalendar]
								where [shiftCalendar].[Machine] = @SAPMachine  COLLATE database_default
								and [shiftCalendar].[EndTime] between @StartDateTime and @EndDateTime
								and [Qualifier] = 'W'
			) x
		order by KPIDateTime, CreationTime, Id, KPIFloatValue; 					


				
	
	OPEN @getKPIs;
		FETCH NEXT FROM @getKPIs into @KPIDateTimeEnd, @StatusId, @KPIFloatValue, @KPIIdentifier
		WHILE @@FETCH_STATUS = 0
		BEGIN;
		
			--set @logcounter = @logcounter + 1;

			set @DateDif = DATEDIFF_BIG(second, @KPIDateTimeStart, @KPIDateTimeEnd);
			set @SumKPIFloatValueEffi = @SumKPIFloatValueEffi + (@DateDif * 100);
			set @SumDateDif = @SumDateDif + @DateDif;
			
			select @SingleMachineLoadingTime=isnull(sum(MachineLoadingTimeInSec),0) from @MachineLoadingTimes
				where ProductionTime > @KPIDateTimeStart
				and ProductionTime <= @KPIDateTimeEnd;
			set @MachineLoadingTime = @MachineLoadingTime + @SingleMachineLoadingTime;
							
			if (@IsShiftRunning = 1)
			BEGIN
				set @MachineLoadingTimeShift = @MachineLoadingTimeShift + @SingleMachineLoadingTime;
				set @SumKPIFloatValueShiftEffi = @SumKPIFloatValueShiftEffi + (@DateDif * 100);
				set @SumDateDifShift = @SumDateDifShift + @DateDif;
			END;
			if (@IsProductionRunning = 1)
			BEGIN
				set @SumKPIFloatValueProdEffi = @SumKPIFloatValueProdEffi + (@DateDif * 100);
				set @SumDateDifProd = @SumDateDifProd + @DateDif;
			END;
			if (@IsShiftRunning = 1 and @IsProductionRunning = 1)
			BEGIN
				set @SumKPIFloatValueShiftProdEffi = @SumKPIFloatValueShiftProdEffi + (@DateDif * 100);
				set @SumDateDifShiftProd = @SumDateDifShiftProd + @DateDif;
			END;

			IF (@KPIIdentifier = 'ShiftStart')
				set @IsShiftRunning = 1;
			ELSE IF (@KPIIdentifier = 'ShiftEnd')
				set @IsShiftRunning = 0;
			else if (@KPIIdentifier = 'Prod')
				select @IsProductionRunning=convert(bit,@KPIFloatValue);
				
			set @KPIDateTimeStart = @KPIDateTimeEnd;
			FETCH NEXT FROM @getKPIs into @KPIDateTimeEnd, @StatusId, @KPIFloatValue, @KPIIdentifier;
		END;
	CLOSE @getKPIs;
	DEALLOCATE @getKPIs;

	set @DateDif = DATEDIFF_BIG(second, @KPIDateTimeStart, @EndDateTime);
	set @SumKPIFloatValueEffi = @SumKPIFloatValueEffi + (@DateDif * 100);
	set @SumDateDif = @SumDateDif + @DateDif;

	select @SingleMachineLoadingTime=isnull(sum(MachineLoadingTimeInSec),0) from @MachineLoadingTimes
		where ProductionTime > @KPIDateTimeStart
		and ProductionTime <= @EndDateTime;
	set @MachineLoadingTime = @MachineLoadingTime + @SingleMachineLoadingTime;	

	if (@IsShiftRunning = 1)
	BEGIN
		set @MachineLoadingTimeShift = @MachineLoadingTimeShift + @SingleMachineLoadingTime;
		set @SumKPIFloatValueShiftEffi = @SumKPIFloatValueShiftEffi + (@DateDif * 100);
		set @SumDateDifShift = @SumDateDifShift + @DateDif;
	END;
	if (@IsProductionRunning = 1)
	BEGIN
		set @SumKPIFloatValueProdEffi = @SumKPIFloatValueProdEffi + (@DateDif * 100);
		set @SumDateDifProd = @SumDateDifProd + @DateDif;
	END;
	if (@IsShiftRunning = 1 and @IsProductionRunning = 1)
	BEGIN
		set @SumKPIFloatValueShiftProdEffi = @SumKPIFloatValueShiftProdEffi + (@DateDif * 100);
		set @SumDateDifShiftProd = @SumDateDifShiftProd + @DateDif;
	END;
				
	IF (@SumDateDifProd > 0)
		set @ResultKPIFloatValueProdEffi = @SumKPIFloatValueProdEffi / @SumDateDif;
	IF (@SumDateDifShiftProd > 0)
		set @ResultKPIFloatValueShiftProdEffi = @SumKPIFloatValueShiftProdEffi / @SumDateDif;
				

	--Machine loading time only for Multi Pallet Machines!!!
	select @isMultiPalletMachine=FloatValue from smartKPIMachineKeyValueData 
		where Machine = @machineName 
		and PropertyKey = 'isMultiPalletMachine';
	
	if (@isMultiPalletMachine <> 1)
		BEGIN
			set @MachineLoadingTimeShift = 0;
			set @MachineLoadingTime = 0;
		END;



				
	--Effi
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		values (@machineName, 'MachineLoadingTimeV2ShiftAdjusted', @KPICalculationBase, @StartDateTime, @EndDateTime, @MachineLoadingTimeShift);

	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		values (@machineName, 'MachineLoadingTimeV2', @KPICalculationBase, @StartDateTime, @EndDateTime, @MachineLoadingTime);

	--insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
	--	values (@machineName, 'EfficiencyRailV2', @KPICalculationBase, @StartDateTime, @EndDateTime, @ResultKPIFloatValueProdEffi);

	--insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
	--	values (@machineName, 'EfficiencyRailV2ShiftAdjusted', @KPICalculationBase, @StartDateTime, @EndDateTime, @ResultKPIFloatValueShiftProdEffi);

	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		values (@machineName, 'OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted', @KPICalculationBase, @StartDateTime, @EndDateTime, @SumKPIFloatValueShiftProdEffi / 100);

	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		values (@machineName, 'OperatingtimeV2ShiftAdjusted', @KPICalculationBase, @StartDateTime, @EndDateTime, (@SumKPIFloatValueShiftProdEffi / 100)+@MachineLoadingTimeShift);

	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		values (@machineName, 'DowntimeV2ShiftAdjusted', @KPICalculationBase, @StartDateTime, @EndDateTime, @SumDateDifShift - (@SumKPIFloatValueShiftProdEffi / 100) - @MachineLoadingTimeShift);
						
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		values (@machineName, 'OperatingtimeWithoutMachineLoadingTimeV2', @KPICalculationBase, @StartDateTime, @EndDateTime, @SumKPIFloatValueProdEffi / 100);

	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		values (@machineName, 'OperatingtimeV2', @KPICalculationBase, @StartDateTime, @EndDateTime, (@SumKPIFloatValueProdEffi / 100)+@MachineLoadingTime);

	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		values (@machineName, 'DowntimeV2', @KPICalculationBase, @StartDateTime, @EndDateTime, @SumDateDif - (@SumKPIFloatValueProdEffi / 100) - @MachineLoadingTime);


	return;
END;

GO
