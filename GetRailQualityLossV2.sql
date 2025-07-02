--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetRailQualityLossV2';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetRailQualityLossV2'))
drop FUNCTION GetRailQualityLossV2;
GO
CREATE FUNCTION GetRailQualityLossV2
	(@StartDateTime DateTime2,
	@EndDateTime DateTime2,
	@machine varchar(255))
RETURNS float  
BEGIN;
	declare @returnvalue float;
	select @returnvalue = isnull(sum((MachineLoadingTimeInSec + MachineTimeInSec)* numberOfParts),0) from dbo.GetRailQualityLossV2Detail(@StartDateTime, @EndDateTime, @machine);
	
	return @returnvalue;

END;
GO

--declare @dt1 as DateTime2 = datetimefromparts(2019,7,2,0,0,0,0);
--declare @dt2 as DateTime2 = datetimefromparts(2019,7,2,12,0,0,0);
--select dbo.GetRailQualityLossV2(@dt1,@dt2, 'KBBUD10424-NBH170MachineThing');
