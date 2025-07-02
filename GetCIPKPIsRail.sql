--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetCIPKPIsRail';
--------------------------------------------------------------
--------------------------------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetCIPKPIsRail'))
drop FUNCTION GetCIPKPIsRail;
GO
CREATE FUNCTION GetCIPKPIsRail
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
	insert into @table (Machine, 
	KPIName, 
	KPICalculationBase, 
	KPIDateTime,  
	KPIDateTimeEndOfCalculation,
	KPIFloatValue) select Machine, 
	KPIName, 
	KPICalculationBase, 
	KPIDateTime,  
	KPIDateTimeEnd,
	KPIFloatValue from smartKPIValues
	where Machine = @machine
	and KPIDateTime = @StartDateTime
	and KPIDateTimeEnd = @EndDateTime
	and KPICalculationBase = 'GetCIPKPIsRailWorker';
	
	if (select count(*) from @table) = 0
		insert into @table (Machine, 
		KPIName, 
		KPICalculationBase, 
		KPIDateTime,  
		KPIDateTimeEndOfCalculation,
		KPIFloatValue) select Machine, 
		KPIName, 
		KPICalculationBase, 
		KPIDateTime,  
		KPIDateTimeEndOfCalculation,
		KPIFloatValue from GetCIPKPIsRailWorker(@StartDateTime,
		@EndDateTime,
		@machine);

return;
END;
GO

--declare @dt1 as DateTime2 = datetimefromparts(2019,7,2,0,0,0,0);
--declare @dt2 as DateTime2 = datetimefromparts(2019,7,2,12,0,0,0);
--select * from dbo.GetCIPKPIsRail(@dt1,@dt2, 'KBBUD10424-NBH170MachineThing');

