--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetRailPerformanceLossV2Detail';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetRailPerformanceLossV2Detail'))
drop FUNCTION GetRailPerformanceLossV2Detail;
GO
CREATE FUNCTION GetRailPerformanceLossV2Detail
	(@StartDateTime DateTime2,
	@EndDateTime DateTime2,
	@machine varchar(255))
RETURNS @table TABLE (ProductionTime datetime2, SAPOrderNumber varchar(255), SAPOperationNumber varchar(255), timePerPartSec float, numberOfParts int, MachineLoadingTimeInSec float, MachineTimeInSec float)  
BEGIN;
	
	DECLARE @MainStation varchar(255);
	
	SELECT @MainStation=[TextValue]
		FROM [smartKPIMachineKeyValueData]
		where PropertyKey = 'MainStationForLineStatus'
		and Machine = @machine;


	insert into @table (ProductionTime, SAPOrderNumber, SAPOperationNumber, numberOfParts, timePerPartSec)
		select ProductionTime, [OrderNumber], SUBSTRING('0000'+SAPOperationNumber,LEN('0000'+SAPOperationNumber)-3,4), [numberOfParts], timePerPartSec
		from [smartKPI]
		where (Station = @machine or Machine = @machine or Station = @MainStation or Machine = @MainStation)
		and isPartOK = 1
		and ProductionTime between @StartDateTime and @EndDateTime
		and isnull(OrderNumber,'') != ''
		and isnull(SAPOperationNumber,'') != ''
		and numberOfParts > 0;
	
	update @table set MachineLoadingTimeInSec = isnull(CASE TextValue
															WHEN 'SEC' THEN FloatValue
															WHEN 'MIN' THEN FloatValue * 60
															WHEN 'DAY' THEN FloatValue * 24 * 60 * 60
															ELSE 0		 
														END,0)
		from smartKPIOrderKeyValueData
		where OrderNumber = SAPOrderNumber COLLATE database_default
		and Operation = SAPOperationNumber
		and PropertyKey1 = 'MachineLoadingTime';

	update @table set MachineTimeInSec = isnull(CASE TextValue
															WHEN 'SEC' THEN FloatValue
															WHEN 'MIN' THEN FloatValue * 60
															WHEN 'DAY' THEN FloatValue * 24 * 60 * 60
															ELSE 0		 
														END,0)
		from smartKPIOrderKeyValueData
		where OrderNumber = SAPOrderNumber COLLATE database_default
		and Operation = SAPOperationNumber
		and PropertyKey1 = 'MachineTime';
		
		update @table set MachineTimeInSec = 0 where MachineTimeInSec is null;
		update @table set MachineLoadingTimeInSec = 0 where MachineLoadingTimeInSec is null;
	
	return;

END;
GO
