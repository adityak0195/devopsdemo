--------------------------------------------------------------
--------------------------------------------------------------
print '--GetCurrentShiftFunction';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetCurrentShiftFunction'))
drop FUNCTION GetCurrentShiftFunction;
GO
CREATE FUNCTION GetCurrentShiftFunction
	(@Machine varchar(255),
	@ShiftStart DateTime2)
RETURNS @table TABLE ( 
	CurrentName varchar(255),
	CurrentStartTime DateTime2,
	CurrentEndTime DateTime2)  

BEGIN

	DECLARE @CurrentName varchar(255);
	DECLARE @CurrentStartTime datetime2;
	DECLARE @CurrentEndTime datetime2;
	
	 
	insert into @table (CurrentName, CurrentStartTime, CurrentEndTime)
	select top(1) CurrentName, CurrentStartTime, CASE WHEN @ShiftStart < CurrentStartTime THEN CurrentStartTime ELSE @ShiftStart END from
		(select CurrentStartTime, CurrentName from TEMP_SmartKPIFullShift
		where @ShiftStart >= CurrentStartTime
		and CurrentEndTime > @ShiftStart
		and Machine = @Machine
		union 
		select CurrentStartTime, CurrentName from 
		(select top(1) CurrentStartTime, CurrentName  from TEMP_SmartKPIFullShift
		 where CurrentStartTime >= @ShiftStart 
		 and Machine = @Machine
		 order by CurrentStartTime)y)x
		 order by CurrentStartTime;

	return;
	
END;

GO