--------------------------------------------------------------
--------------------------------------------------------------
print '-- IsRailMachineProductive';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'IsRailMachineProductive'))
drop FUNCTION IsRailMachineProductive;
GO
CREATE FUNCTION IsRailMachineProductive
	(@machine varchar(255),
	@ListOfIds varchar(max))
RETURNS bit  
BEGIN;

	DECLARE @isProductive bit = 0;
	DECLARE @target int = 0;
	DECLARE @actual int = 0;
	

	select @actual=count(*) from
		(select smartKPIMachineStatusData.Id from smartKPIProductiveStateDefinition, smartKPIMachineStatusData
		where smartKPIMachineStatusData.Id in (SELECT convert(int, value) FROM STRING_SPLIT(@ListOfIds, ','))
		and smartKPIProductiveStateDefinition.StatusName = smartKPIMachineStatusData.Status
		and smartKPIProductiveStateDefinition.StatusValue = smartKPIMachineStatusData.SubStatus
		and smartKPIProductiveStateDefinition.StatusComparer = '='
		and smartKPIProductiveStateDefinition.Machine = @machine
		and smartKPIProductiveStateDefinition.Station = smartKPIMachineStatusData.Machine
	union
		select smartKPIMachineStatusData.Id from smartKPIProductiveStateDefinition, smartKPIMachineStatusData
		where smartKPIMachineStatusData.Id in (SELECT convert(int, value) FROM STRING_SPLIT(@ListOfIds, ','))
		and smartKPIProductiveStateDefinition.StatusName = smartKPIMachineStatusData.Status
		and smartKPIProductiveStateDefinition.StatusValue != smartKPIMachineStatusData.SubStatus
		and smartKPIProductiveStateDefinition.StatusComparer = '!='
		and smartKPIProductiveStateDefinition.Machine = @machine
		and smartKPIProductiveStateDefinition.Station = smartKPIMachineStatusData.Machine
		) x;

	SELECT @target=count(*) FROM STRING_SPLIT(@ListOfIds, ',');
	
	if (@target=@actual)
		set @isProductive = 1;
	else
		set @isProductive = 0;
	
	return @isProductive;
END;
GO