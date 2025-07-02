--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetPlannedProductionRailWorker';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetPlannedProductionRailWorker'))
drop FUNCTION GetPlannedProductionRailWorker;
GO
CREATE FUNCTION GetPlannedProductionRailWorker
	(@StartDateTime DateTime2,
	@CalculationPeriodInMinutes bigint,
	@CalculateNumerOfCycles int,
	@CalculationBase varchar(255),
	@JobName varchar(255),
	@machines varchar(255),
	@doTraceLogging Bit)
RETURNS @table TABLE ( 
	Machine varchar(255), 
	KPIName varchar(255), 
	KPICalculationBase varchar(255), 
	KPIDateTime DateTime2, 
	KPIDateTimeEndOfCalculation DateTime2,
	KPIFloatValue float,
	LoggingStatus varchar(512),
	LoggingData varchar(512),
	LoggingIsProductive Bit,
	LoggingIsShift Bit,
	LoggingSecondsInStatus bigint,
	LoggingSumSeconds float)  
BEGIN;
	Declare @StartDateTimeFromProcInput DateTime2;
	set @StartDateTimeFromProcInput = @StartDateTime;

	declare @LogText varchar(1024);


	Declare @KPIName varchar(255);
	Set @KPIName = 'PlannedProduction';
	Declare @KPINameIO varchar(255);
	Set @KPINameIO = @KPIName + 'IO';
	Declare @KPINameNIO varchar(255);
	Set @KPINameNIO = @KPIName + 'NIO';
	Declare @KPICalculationBase varchar(255);

	Declare @KPINameCore varchar(255);
	Set @KPINameCore = 'PlannedProductionCore';
	Declare @KPINameIOCore varchar(255);
	Set @KPINameIOCore = @KPIName + 'IOCore';
	Declare @KPINameNIOCore varchar(255);
	Set @KPINameNIOCore = @KPIName + 'NIOCore';


	Declare @StartDatePerCalculationCycle DateTime2;
	Declare @EndDatePerCalculationCycle DateTime2;
	Declare @EndDatePerCalculationCycleFull DateTime2;
	Declare @CurrentCycles int;
	Declare @currentRow int;
	Declare @KPI float;
	Declare @KPICore float;
	Declare @KPIct bigint;
	Declare @KPIpt bigint;
	Declare @KPIptCore bigint;
	Declare @getMachines CURSOR;
	Declare @machineName varchar(255);
	Declare @SAPWorkcenterNumber varchar(255);
	

	set @CurrentCycles = 0;
	
	
	set @StartDatePerCalculationCycle = datetimefromparts(
		DATEPART(year, @StartDateTimeFromProcInput),
		DATEPART(month, @StartDateTimeFromProcInput),
		DATEPART(day, @StartDateTimeFromProcInput),
		DATEPART(hour, @StartDateTimeFromProcInput),
		DATEPART(minute, @StartDateTimeFromProcInput),
		0,0);

	set @EndDatePerCalculationCycle = DATEADD(minute, @CalculationPeriodInMinutes, @StartDatePerCalculationCycle);
	set @EndDatePerCalculationCycleFull = @EndDatePerCalculationCycle;
	if (@EndDatePerCalculationCycle > getutcdate())
	BEGIN
		set @EndDatePerCalculationCycle = getutcdate();
	END;


	WHILE (@CurrentCycles<@CalculateNumerOfCycles)
	BEGIN




		SET @getMachines = CURSOR FOR 
			SELECT Machine, [TextValue]
			  FROM [smartKPIMachineKeyValueData]
			  where Machine = @machines
			  and PropertyKey = 'SAPWorkcenterNumber'
			  and [TextValue] is not null
			  and [TextValue] != '';



		OPEN @getMachines;
			FETCH NEXT FROM @getMachines into @machineName, @SAPWorkcenterNumber
			WHILE @@FETCH_STATUS = 0
			BEGIN;

				if (@doTraceLogging = 1)
				BEGIN
					insert into @table (Machine, KPIName, KPICalculationBase, KPIDateTime, KPIDateTimeEndOfCalculation, KPIFloatValue, 
						LoggingStatus, LoggingData, LoggingIsProductive, LoggingIsShift, LoggingSecondsInStatus, LoggingSumSeconds) 
						select @machineName, @KPIName, 'TraceLogging', KPIDateTimeStart, KPIDateTimeEnd, NULL,
							'Shift Calendar', NULL, NULL, NULL, KPIFloatValue, NULL
							from dbo.GetWorkingTimeRailInSeconds1(@SAPWorkcenterNumber, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle);
				END;

				select @KPIpt=dbo.GetWorkingTimeRailInSeconds1Extended(@StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @machines);
				select @KPIptCore=dbo.GetWorkingTimeRailInSeconds1Core(@StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @machines);
				select @KPIct=DATEDIFF_BIG(second, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle);

						
				set @KPI = 0.0;
				IF (@KPIct > 0)
				BEGIN
					set @KPI = convert(float,@KPIpt) / convert(float,@KPIct) * 100.0;
				END;

				set @KPICore = 0.0;
				IF (@KPIct > 0)
				BEGIN
					set @KPICore = convert(float,@KPIptCore) / convert(float,@KPIct) * 100.0;
				END;


				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPIName, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPI);

				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameIO, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIpt);

				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameNIO, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIct - @KPIpt);

				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameCore, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPICore);

				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameIOCore, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIptCore);

				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameNIOCore, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIct - @KPIptCore);

				FETCH NEXT FROM @getMachines into @machineName, @SAPWorkcenterNumber;
			END;
		CLOSE @getMachines;
		DEALLOCATE @getMachines;

		set @StartDatePerCalculationCycle = DATEADD(minute, -1* @CalculationPeriodInMinutes, @StartDatePerCalculationCycle);
		set @EndDatePerCalculationCycleFull = DATEADD(minute, -1* @CalculationPeriodInMinutes, @EndDatePerCalculationCycleFull);
		set @EndDatePerCalculationCycle = @EndDatePerCalculationCycleFull;
		set @CurrentCycles = @CurrentCycles + 1;
	END;
	return;
END;

GO

--declare @dt as DateTime2 = datetimefromparts(2018,11,8,12,0,0,0);
--select * from dbo.GetPlannedProductionRailWorker(@dt,15,1,'Quarter', 'GetPlannedProduction', 'KBLisLaa6MachineThing', 0);
--GO 
