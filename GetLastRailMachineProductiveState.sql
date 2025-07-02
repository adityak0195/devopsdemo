--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetLastRailMachineProductiveState';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetLastRailMachineProductiveState'))
drop FUNCTION GetLastRailMachineProductiveState;
GO
CREATE FUNCTION GetLastRailMachineProductiveState
	(@machine varchar(255),
	@StatusDate datetime2)
RETURNS bit  
BEGIN;

	DECLARE @getStateDefinitions CURSOR;
	Declare @StatusName varchar(255);
	Declare @Station varchar(255);
	DECLARE @productiveTable table (Id int, StatusName varchar(255), Station varchar(255));
	DECLARE @StatusIdList varchar(max);
	Declare @IsProductive bit;


	SET @getStateDefinitions = CURSOR for 
		SELECT StatusName, Station 
			FROM smartKPIProductiveStateDefinition 
			where Machine = @machine 
			order by Id;

	OPEN @getStateDefinitions;
		FETCH NEXT FROM @getStateDefinitions into @StatusName, @Station;
		WHILE @@FETCH_STATUS = 0
		BEGIN;
			insert into @productiveTable (Id, StatusName, Station)
			select TOP (1) Id, @StatusName, @Station
				FROM [smartKPIMachineStatusData]
				where Status = @StatusName
				and Machine = @Station
				and StatusTime < @StatusDate
				order by StatusTime desc;
						 
			FETCH NEXT FROM @getStateDefinitions into @StatusName, @Station;
		END;
	CLOSE @getStateDefinitions;
	DEALLOCATE @getStateDefinitions;


	set @StatusIdList = NULL;
	Select @StatusIdList=COALESCE(@StatusIdList + ', ' + convert(varchar(20), Id), convert(varchar(20), Id)) 
			From @productiveTable;
	select @IsProductive=dbo.IsRailMachineProductive(@machine, @StatusIdList);

	return @IsProductive;

END;
GO

--select dbo.GetLastRailMachineProductiveState('KBBUD10393-NBH135MachineThing', getutcdate());
