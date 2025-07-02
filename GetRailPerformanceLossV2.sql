--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetRailPerformanceLossV2';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetRailPerformanceLossV2'))
drop FUNCTION GetRailPerformanceLossV2;
GO
CREATE FUNCTION GetRailPerformanceLossV2
	(@StartDateTime DateTime2,
	@EndDateTime DateTime2,
	@machine varchar(255))
RETURNS float  
BEGIN;
	declare @getKPIs cursor;
	declare @MachineTimeInSec float;
	declare @ProductionTime datetime2;
	declare @OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted float;
	declare @PerformanceLoss float = 0;

	declare @StartDateTimeSlot datetime2 = @StartDateTime;
	declare @EndDateTimeSlot datetime2;

	SET @getKPIs = CURSOR FOR 
		select MachineTimeInSec, ProductionTime from GetRailPerformanceLossV2Detail(@StartDateTime, @EndDateTime, @machine);
				
	
	OPEN @getKPIs;
		FETCH NEXT FROM @getKPIs into @MachineTimeInSec, @ProductionTime;
		WHILE @@FETCH_STATUS = 0
		BEGIN;
			set @EndDateTimeSlot = @ProductionTime;
			select @OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted=KPIFloatValue from GetDowntimeV2RailWorker(@StartDateTimeSlot, @EndDateTimeSlot, @machine)
				where KPIName = 'OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted'

			if (@OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted-@MachineTimeInSec > 0)
				set @PerformanceLoss = @PerformanceLoss + @OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted-@MachineTimeInSec;

			set @StartDateTimeSlot = @ProductionTime;
			
			--print @OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted-@MachineTimeInSec;
			--print @PerformanceLoss;

			FETCH NEXT FROM @getKPIs into @MachineTimeInSec, @ProductionTime;
		END;
	CLOSE @getKPIs;
	DEALLOCATE @getKPIs;

	select @OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted=KPIFloatValue from GetDowntimeV2RailWorker(@StartDateTimeSlot, @EndDateTime, @machine)
		where KPIName = 'OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted'

	if (@OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted-@MachineTimeInSec > 0)
		set @PerformanceLoss = @PerformanceLoss + @OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted-@MachineTimeInSec;
	
	--print @OperatingtimeWithoutMachineLoadingTimeV2ShiftAdjusted-@MachineTimeInSec;
	--print @PerformanceLoss;
	
	return @PerformanceLoss;

END;
GO
