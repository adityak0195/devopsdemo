--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetSAPTimePerPart';
--------------------------------------------------------------
--------------------------------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetSAPTimePerPart'))
drop FUNCTION GetSAPTimePerPart;
GO
CREATE FUNCTION GetSAPTimePerPart
	(@OrderNumber varchar(255))
--RETURNS float
RETURNS @table TABLE ( 
		OperationNumber varchar(255),
		SAPMachine  varchar(255),
		SetupTime float,
		SetupTimeUnit varchar(255),
		SetupTimeInSec float,
		SetupTimeAPO float,
		SetupTimeUnitAPO varchar(255),
		SetupTimeInSecAPO float,
		SetupTimeCO float,
		SetupTimeUnitCO varchar(255),
		SetupTimeInSecCO float,
		TeardownTime float,
		TeardownTimeUnit varchar(255),
		TeardownTimeInSec float,
		tgMaxTime float,
		tgMaxTimeUnit varchar(255),
		tgMaxTimeInSec float,
		ProcessingTime float,
		ProcessingTimeUnit varchar(255),
		ProcessingTimeInSec float,
		ProcessingTimeCO float,
		ProcessingTimeUnitCO varchar(255),
		ProcessingTimeInSecCO float,
		ProcessingTimeAPO float,
		ProcessingTimeUnitAPO varchar(255),
		ProcessingTimeInSecAPO float,
		PlannedNumberOfWorkers float)
BEGIN

	insert into @table (OperationNumber)
		SELECT [TextValue]
		  FROM [smartKPIOrderKeyValueData]
		  where OrderNumber = @OrderNumber
		  and PropertyKey1 = 'Operation'
		  and isnull(Operation,'') != '';
	update @table set SAPMachine = (SELECT [TextValue]
			  FROM [smartKPIOrderKeyValueData]
			  where OrderNumber = @OrderNumber
			  and PropertyKey = 'Line-'+OperationNumber
			  COLLATE database_default); 		
	update @table set SetupTime = FloatValue, 
		SetupTimeUnit = TextValue, 
		SetupTimeInSec =  CASE TextValue
									WHEN 'SEC' THEN [FloatValue]
									WHEN 'MIN' THEN [FloatValue] * 60
									WHEN 'DAY' THEN [FloatValue] * 24 * 60 * 60
									ELSE 0		 
								END 
			  FROM [smartKPIOrderKeyValueData]
			  where OrderNumber = @OrderNumber
			  and PropertyKey = 'SetupTime-'+OperationNumber
			  COLLATE database_default; 		
	update @table set SetupTimeAPO = FloatValue, 
		SetupTimeUnitAPO = TextValue, 
		SetupTimeInSecAPO =  CASE TextValue
									WHEN 'SEC' THEN [FloatValue]
									WHEN 'MIN' THEN [FloatValue] * 60
									WHEN 'DAY' THEN [FloatValue] * 24 * 60 * 60
									ELSE 0		 
								END 
			  FROM [smartKPIOrderKeyValueData]
			  where OrderNumber = @OrderNumber
			  and PropertyKey = 'SetupTimeAPO-'+OperationNumber
			  COLLATE database_default; 		
	update @table set SetupTimeCO = FloatValue, 
		SetupTimeUnitCO = TextValue, 
		SetupTimeInSecCO =  CASE TextValue
									WHEN 'SEC' THEN [FloatValue]
									WHEN 'MIN' THEN [FloatValue] * 60
									WHEN 'DAY' THEN [FloatValue] * 24 * 60 * 60
									ELSE 0		 
								END 
			  FROM [smartKPIOrderKeyValueData]
			  where OrderNumber = @OrderNumber
			  and PropertyKey = 'SetupTimeCO-'+OperationNumber
			  COLLATE database_default; 		
	update @table set ProcessingTime = FloatValue, 
		ProcessingTimeUnit = TextValue, 
		ProcessingTimeInSec =  CASE TextValue
									WHEN 'SEC' THEN [FloatValue]
									WHEN 'MIN' THEN [FloatValue] * 60
									WHEN 'DAY' THEN [FloatValue] * 24 * 60 * 60
									ELSE 0		 
								END 
			  FROM [smartKPIOrderKeyValueData]
			  where OrderNumber = @OrderNumber
			  and PropertyKey = 'ProcessingTime-'+OperationNumber
			  COLLATE database_default; 		
	update @table set ProcessingTimeCO = FloatValue, 
		ProcessingTimeUnitCO = TextValue, 
		ProcessingTimeInSecCO =  CASE TextValue
									WHEN 'SEC' THEN [FloatValue]
									WHEN 'MIN' THEN [FloatValue] * 60
									WHEN 'DAY' THEN [FloatValue] * 24 * 60 * 60
									ELSE 0		 
								END 
			  FROM [smartKPIOrderKeyValueData]
			  where OrderNumber = @OrderNumber
			  and PropertyKey = 'ProcessingTimeCO-'+OperationNumber
			  COLLATE database_default; 		
	update @table set ProcessingTimeAPO = FloatValue, 
		ProcessingTimeUnitAPO = TextValue, 
		ProcessingTimeInSecAPO =  CASE TextValue
									WHEN 'SEC' THEN [FloatValue]
									WHEN 'MIN' THEN [FloatValue] * 60
									WHEN 'DAY' THEN [FloatValue] * 24 * 60 * 60
									ELSE 0		 
								END 
			  FROM [smartKPIOrderKeyValueData]
			  where OrderNumber = @OrderNumber
			  and PropertyKey = 'ProcessingTimeAPO-'+OperationNumber
			  COLLATE database_default; 		
		
	update @table set TeardownTime = FloatValue, 
		TeardownTimeUnit = TextValue, 
		TeardownTimeInSec =  CASE TextValue
									WHEN 'SEC' THEN [FloatValue]
									WHEN 'MIN' THEN [FloatValue] * 60
									WHEN 'DAY' THEN [FloatValue] * 24 * 60 * 60
									ELSE 0		 
								END 
			  FROM [smartKPIOrderKeyValueData]
			  where OrderNumber = @OrderNumber
			  and PropertyKey = 'TeardownTime-'+OperationNumber
			  COLLATE database_default; 		
	update @table set tgMaxTime = FloatValue, 
		tgMaxTimeUnit = TextValue, 
		tgMaxTimeInSec =  CASE TextValue
									WHEN 'SEC' THEN [FloatValue]
									WHEN 'MIN' THEN [FloatValue] * 60
									WHEN 'DAY' THEN [FloatValue] * 24 * 60 * 60
									ELSE 0		 
								END 
			  FROM [smartKPIOrderKeyValueData]
			  where OrderNumber = @OrderNumber
			  and PropertyKey = 'tgMaxTime-'+OperationNumber
			  COLLATE database_default; 		
	update @table set PlannedNumberOfWorkers = FloatValue
			  FROM [smartKPIOrderKeyValueData]
			  where OrderNumber = @OrderNumber
			  and PropertyKey = 'PlannedNumberOfWorkers-'+OperationNumber
			  COLLATE database_default; 	
	update @table set PlannedNumberOfWorkers = 0
		where PlannedNumberOfWorkers is null;


		
	return;
END;

GO

--select * from GetSAPTimePerPart('35153577');
