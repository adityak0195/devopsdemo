--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetCIPKPIsRailWorker';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetCIPKPIsRailWorker'))
drop FUNCTION GetCIPKPIsRailWorker;
GO
CREATE FUNCTION GetCIPKPIsRailWorker
	(@StartDateTime DateTime2,
	@EndDateTime DateTime2,
	@machine varchar(255))
RETURNS @table TABLE ( 
	Machine varchar(255), 
	KPIName varchar(255), 
	KPICalculationBase varchar(255), 
	KPIDateTime DateTime2,  
	KPIDateTimeEndOfCalculation DateTime2,
	KPIFloatValue float)  
BEGIN;
	if (@EndDateTime > getutcdate())
		SET @EndDateTime = getutcdate();

	-- OEE 1.0
	declare @CalculationPeriodInMinutes bigint = DATEDIFF_BIG(minute, @StartDateTime, @EndDateTime);
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select [Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue] 
			from dbo.GetUtilizationOeeRail(@StartDateTime,@CalculationPeriodInMinutes,1,'flex', 'GetCIPKPIsRail', @machine);
	
	-- OEE 2.0
	declare @CalendarTime float;
	set @CalendarTime = datediff(second, @StartDateTime, @EndDateTime);
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'CalendarTimeV2', 'flex', @StartDateTime, @EndDateTime, @CalendarTime;
		
	declare @PlannedProductionTime float;
	select @PlannedProductionTime=dbo.GetWorkingTimeRailInSecondsV2(@StartDateTime, @EndDateTime, @machine);
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'PlanningLossV2', 'flex', @StartDateTime, @EndDateTime, @CalendarTime-@PlannedProductionTime;
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'PlannedProductionTimeV2', 'flex', @StartDateTime, @EndDateTime, @PlannedProductionTime;
	
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select [Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue] 
			from dbo.GetDowntimeV2RailWorker(@StartDateTime,@EndDateTime, @machine);
	declare @DownTime float; 
	select @DownTime=KPIFloatValue from @table where KPIName = 'DowntimeV2ShiftAdjusted';
	
	declare @PerformanceLoss float;
	select @PerformanceLoss = dbo.GetRailPerformanceLossV2(@StartDateTime, @EndDateTime, @machine);
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'PerformanceLossV2', 'flex', @StartDateTime, @EndDateTime, @PerformanceLoss;
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'NetOperatingtimeV2', 'flex', @StartDateTime, @EndDateTime, @PlannedProductionTime-@DownTime-@PerformanceLoss;

	declare @QualityLoss float;
	select @QualityLoss=dbo.GetRailQualityLossV2(@StartDateTime, @EndDateTime, @machine);
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'QualityLossV2', 'flex', @StartDateTime, @EndDateTime, @QualityLoss;
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'ProductiveTimeV2', 'flex', @StartDateTime, @EndDateTime, @PlannedProductionTime-@DownTime-@PerformanceLoss-@QualityLoss;

	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'OEEV2', 'flex', @StartDateTime, @EndDateTime, CASE WHEN @PlannedProductionTime = 0 THEN 0 ELSE (@PlannedProductionTime-@DownTime-@PerformanceLoss-@QualityLoss)/@PlannedProductionTime * 100 END; --ToDo: devision by zero
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'UtilizationV2', 'flex', @StartDateTime, @EndDateTime, CASE WHEN @CalendarTime = 0 THEN 0 ELSE (@PlannedProductionTime-@DownTime-@PerformanceLoss-@QualityLoss)/@CalendarTime * 100 END; --ToDo: devision by zero

	-- OEE 2.1
/*
	declare @RunTimeV21 float;
	select @RunTimeV21=dbo.GetRailRunTimeV21(@StartDateTime, @EndDateTime, @machine);
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'RunTimeV21', 'flex', @StartDateTime, @EndDateTime, @RunTimeV21;
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'OEEV21', 'flex', @StartDateTime, @EndDateTime, CASE WHEN @PlannedProductionTime = 0 THEN 0 ELSE (@RunTimeV21)/@PlannedProductionTime * 100 END; --ToDo: devision by zero
	insert into @table ([Machine], [KPIName], [KPICalculationBase], [KPIDateTime], KPIDateTimeEndOfCalculation, [KPIFloatValue]) 
		select @machine, 'UtilizationV21', 'flex', @StartDateTime, @EndDateTime, CASE WHEN @CalendarTime = 0 THEN 0 ELSE (@RunTimeV21)/@CalendarTime * 100 END; --ToDo: devision by zero
*/
return;
END;
GO

