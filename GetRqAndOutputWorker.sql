--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetRqAndOutputWorker';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetRqAndOutputWorker'))
drop FUNCTION GetRqAndOutputWorker;
GO
CREATE FUNCTION GetRqAndOutputWorker
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


	Declare @KPINameRQ varchar(255);
	Declare @KPINameOutputIO varchar(255);
	Declare @KPINameOutputNIO varchar(255);
	Set @KPINameRQ = 'RQ';
	Set @KPINameOutputIO = 'OutputIO';
	Set @KPINameOutputNIO = 'OutputNIO';
	Declare @KPICalculationBase varchar(255);
	
	Declare @KPIShiftProdIO float;
	Declare @KPIShiftProdNIO float;

	Declare @StartDatePerCalculationCycle DateTime2;
	Declare @EndDatePerCalculationCycle DateTime2;
	Declare @EndDatePerCalculationCycleFull DateTime2;
	Declare @CurrentCycles int;
	Declare @currentRow int;
	Declare @KPINIO int;
	Declare @KPIIO int;
	Declare @KPIRQ float;
	Declare @getMachines CURSOR;
	Declare @machineName varchar(255);

	Declare @KPIPerformanceRailShiftIO float;
	Declare @KPINamePerformanceRailShiftProdAdjustedIO varchar(255) = 'PerformanceRailShiftProdAdjustedIO';
	Declare @KPINameShiftProdIO varchar(255) = 'RQIO';
	Declare @KPINameShiftProdNIO varchar(255) = 'RQNIO';
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
			SELECT Machine
			  FROM [smartKPIMachineKeyValueData]
			  where Machine = @machines
			  and PropertyKey = 'SAPWorkcenterNumber'
			  and [TextValue] is not null
			  and [TextValue] != '';

		OPEN @getMachines;
			FETCH NEXT FROM @getMachines into @machineName
			WHILE @@FETCH_STATUS = 0
			BEGIN;

				insert into @table (Machine, KPIName, KPICalculationBase, KPIDateTime, KPIDateTimeEndOfCalculation, KPIFloatValue, LoggingStatus, LoggingData, LoggingIsProductive, LoggingIsShift, LoggingSecondsInStatus, LoggingSumSeconds) 
					select Machine, KPIName, KPICalculationBase, KPIDateTime, KPIDateTimeEndOfCalculation, KPIFloatValue, LoggingStatus, LoggingData, LoggingIsProductive, LoggingIsShift, LoggingSecondsInStatus, LoggingSumSeconds
						from dbo.GetPerformanceRailWorker(@StartDatePerCalculationCycle,@CalculationPeriodInMinutes,1,@CalculationBase, @JobName, @machineName, @doTraceLogging);
			    
				select @KPIPerformanceRailShiftIO=[KPIFloatValue] from @table 
							where [Machine] = @machineName
							and [KPIName] = @KPINamePerformanceRailShiftProdAdjustedIO 
							and [KPICalculationBase] = @CalculationBase
							and [KPIDateTime] = @StartDatePerCalculationCycle; 

				select @KPIIO=ISNULL(ok.number,0), @KPINIO=ISNULL(nok.number,0) from 
					(select sum([numberOfParts]) as number from [smartKPI] 
						where Machine = @machineName
						and [ProductionTime] between @StartDatePerCalculationCycle and @EndDatePerCalculationCycle
						and [isPartOK] = 1) ok,
					(select sum([numberOfParts]) as number from [smartKPI] 
						where Machine = @machineName
						and [ProductionTime] between @StartDatePerCalculationCycle and @EndDatePerCalculationCycle
						and [isPartOK] = 0) nok;
						
				set @KPIRQ = 0.0;
				IF ((@KPIIO + @KPINIO) > 0.0)
				BEGIN
					set @KPIRQ = convert(float,@KPIIO) / (convert(float,@KPIIO) + convert(float,@KPINIO)) * 100.0;
				END;

				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameRQ, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIRQ);

				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameOutputIO, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIIO);
				
				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameOutputNIO, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPINIO);

				if (@KPIPerformanceRailShiftIO is null)
					set @KPIPerformanceRailShiftIO = 0;
						
				set @KPIShiftProdIO = @KPIPerformanceRailShiftIO * @KPIRQ / 100;
				set @KPIShiftProdNIO = @KPIPerformanceRailShiftIO - @KPIShiftProdIO;

							
				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameShiftProdIO, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIShiftProdIO);

				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameShiftProdNIO, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIShiftProdNIO);

				FETCH NEXT FROM @getMachines into @machineName;
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
