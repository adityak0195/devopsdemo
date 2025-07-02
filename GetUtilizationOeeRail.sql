--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetUtilizationOeeRail';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetUtilizationOeeRail'))
drop FUNCTION GetUtilizationOeeRail;
GO
CREATE FUNCTION GetUtilizationOeeRail
	(@StartDateTime DateTime2,
	@CalculationPeriodInMinutes bigint,
	@CalculateNumerOfCycles int,
	@CalculationBase varchar(255),
	@JobName varchar(255),
	@machines varchar(255))
RETURNS @table TABLE ( 
	Machine varchar(255), 
	KPIName varchar(255), 
	KPICalculationBase varchar(255), 
	KPIDateTime DateTime2, 
	KPIDateTimeEndOfCalculation DateTime2,
	KPIFloatValue float)  
BEGIN;
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
	select [Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]
		from GetUtilizationOeeRailWorker(@StartDateTime, @CalculationPeriodInMinutes, @CalculateNumerOfCycles, @CalculationBase, @JobName, @machines, 0);
	return;
END;

GO

--declare @dt as DateTime2 = datetimefromparts(2018,11,8,12,0,0,0);
--EXECUTE CalculateUtilizationOeeRail @StartDateTime = @dt, @CalculationPeriodInMinutes = 15, @CalculateNumerOfCycles = 1, @CalculationBase = 'test', @JobName = 'CalculateKpiUtilizationOeeRail';  
--GO 
