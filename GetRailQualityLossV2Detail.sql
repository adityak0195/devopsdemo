--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetRailQualityLossV2Detail';
--------------------------------------------------------------
--------------------------------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetRailQualityLossV2Detail'))
drop FUNCTION GetRailQualityLossV2Detail;
GO
CREATE FUNCTION GetRailQualityLossV2Detail
	(@StartDateTime DateTime2,
	@EndDateTime DateTime2,
	@machine varchar(255))
RETURNS @table TABLE (SAPOrderNumber varchar(255), SAPOperationNumber varchar(255), numberOfParts int, MachineLoadingTimeInSec float, MachineTimeInSec float)  
BEGIN;
	
	insert into @table (SAPOrderNumber, SAPOperationNumber, numberOfParts)
		select [OrderNumber], SUBSTRING('0000'+SAPOperationNumber,LEN('0000'+SAPOperationNumber)-3,4), [numberOfParts]
		from [smartKPI]
		where Machine = @machine
		and isPartOK = 0
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
	
	return;

END;
GO