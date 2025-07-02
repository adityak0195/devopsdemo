--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetUtilizationOeeRailWorker';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetUtilizationOeeRailWorker'))
drop FUNCTION GetUtilizationOeeRailWorker;
GO
CREATE FUNCTION GetUtilizationOeeRailWorker
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


	Declare @KPINameUtilization varchar(255);
	Declare @KPINameOee varchar(255);
	Declare @KPINameOeeCore varchar(255);
	Set @KPINameUtilization = 'UtilizationRail';
	Set @KPINameOee = 'OeeRail';
	Set @KPINameOeeCore = 'OeeRailCore';
	declare @KPINameRQIO varchar(255) = 'RQIO';
	declare @KPINamePlannedProductionIO varchar(255) = 'PlannedProductionIO';
	declare @PlannedProductionNIO varchar(255) = 'PlannedProductionNIO';
	declare @KPINamePlannedProductionIOCore varchar(255) = 'PlannedProductionIOCore';
	declare @PlannedProductionNIOCore varchar(255) = 'PlannedProductionNIOCore';


	Declare @StartDatePerCalculationCycle DateTime2;
	Declare @EndDatePerCalculationCycle DateTime2;
	Declare @CurrentCycles int;
	Declare @currentRow int;
	Declare @KPIOee float;
	Declare @KPIOeeCore float;
	Declare @KPIUtilization float;
	Declare @getMachines CURSOR;
	Declare @machineName varchar(255);
	Declare @timeBaseOee float;
	Declare @timeBaseOeeCore float;
	Declare @timeBaseUtilization float;
	Declare @KPIRQRailIO float;
	Declare @KPIProdIO float;
	Declare @KPIProdNIO float;
	Declare @KPIProdIOCore float;
	Declare @KPIProdNIOCore float;
	

	set @CurrentCycles = 0;
	
	
	set @StartDatePerCalculationCycle = datetimefromparts(
		DATEPART(year, @StartDateTimeFromProcInput),
		DATEPART(month, @StartDateTimeFromProcInput),
		DATEPART(day, @StartDateTimeFromProcInput),
		DATEPART(hour, @StartDateTimeFromProcInput),
		DATEPART(minute, @StartDateTimeFromProcInput),
		0,0);

	set @EndDatePerCalculationCycle = DATEADD(minute, @CalculationPeriodInMinutes, @StartDatePerCalculationCycle);


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
						from dbo.GetRqAndOutputWorker(@StartDatePerCalculationCycle,@CalculationPeriodInMinutes,1,@CalculationBase, @JobName, @machineName, @doTraceLogging);

				select @KPIRQRailIO=[KPIFloatValue] from @table
							where [Machine] = @machineName
							and [KPIName] = @KPINameRQIO 
							and [KPICalculationBase] = @CalculationBase
							and [KPIDateTime] = @StartDatePerCalculationCycle; 
				select @KPIProdIO=[KPIFloatValue] from @table 
							where [Machine] = @machineName
							and [KPIName] = @KPINamePlannedProductionIO 
							and [KPICalculationBase] = @CalculationBase
							and [KPIDateTime] = @StartDatePerCalculationCycle; 
				select @KPIProdNIO=[KPIFloatValue] from @table 
							where [Machine] = @machineName
							and [KPIName] = @PlannedProductionNIO 
							and [KPICalculationBase] = @CalculationBase
							and [KPIDateTime] = @StartDatePerCalculationCycle; 
				select @KPIProdIOCore=[KPIFloatValue] from @table 
							where [Machine] = @machineName
							and [KPIName] = @KPINamePlannedProductionIOCore 
							and [KPICalculationBase] = @CalculationBase
							and [KPIDateTime] = @StartDatePerCalculationCycle; 
				select @KPIProdNIOCore=[KPIFloatValue] from @table 
							where [Machine] = @machineName
							and [KPIName] = @PlannedProductionNIOCore 
							and [KPICalculationBase] = @CalculationBase
							and [KPIDateTime] = @StartDatePerCalculationCycle; 
							
				
				
				set @timeBaseUtilization = @KPIProdNIO + @KPIProdIO;
				set @timeBaseOee = @KPIProdIO;
				set @timeBaseOeeCore = @KPIProdIOCore;
						
				set @KPIUtilization = 0.0;
				IF ((@timeBaseUtilization) > 0.0)
				BEGIN
					set @KPIUtilization = convert(float,@KPIRQRailIO) / convert(float,@timeBaseUtilization) * 100.0;
				END;
				set @KPIOee = 0.0;
				IF ((@timeBaseOee) > 0.0)
				BEGIN
					set @KPIOee = convert(float,@KPIRQRailIO) / convert(float,@timeBaseOee) * 100.0;
				END;
				set @KPIOeeCore = 0.0;
				IF ((@timeBaseOeeCore) > 0.0)
				BEGIN
					set @KPIOeeCore = convert(float,@KPIRQRailIO) / convert(float,@timeBaseOeeCore) * 100.0;
				END;

				if (@KPIUtilization is null)
					set @KPIUtilization = 0;
				if (@KPIOee is null)
					set @KPIOee = 0;
				if (@KPIOeeCore is null)
					set @KPIOeeCore = 0;
				
				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameUtilization, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIUtilization);
					
				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameOee, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIOee);

				insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
					values (@machineName, @KPINameOeeCore, @CalculationBase, @StartDatePerCalculationCycle, @EndDatePerCalculationCycle, @KPIOeeCore);

				FETCH NEXT FROM @getMachines into @machineName;
			END;
		CLOSE @getMachines;
		DEALLOCATE @getMachines;

		set @StartDatePerCalculationCycle = DATEADD(minute, -1* @CalculationPeriodInMinutes, @StartDatePerCalculationCycle);
		set @EndDatePerCalculationCycle = DATEADD(minute, -1* @CalculationPeriodInMinutes, @EndDatePerCalculationCycle);
		set @CurrentCycles = @CurrentCycles + 1;
	END;
	return;
END;

GO
