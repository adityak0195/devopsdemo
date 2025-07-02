--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetPerformanceRail';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetPerformanceRail'))
drop FUNCTION GetPerformanceRail;
GO
CREATE FUNCTION GetPerformanceRail
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
		from GetPerformanceRailWorker(@StartDateTime, @CalculationPeriodInMinutes, @CalculateNumerOfCycles, @CalculationBase, @JobName, @machines, 0);
	return;
END;

GO


--declare @dt as DateTime2 = datetimefromparts(2018,11,8,12,0,0,0);
--select * from dbo.GetPerformanceRail(@dt,15,1,'Quarter', 'GetPerformanceRail', 'All');
--GO 