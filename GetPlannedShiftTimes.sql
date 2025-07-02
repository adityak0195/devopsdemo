--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetPlannedShiftTimes';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetPlannedShiftTimes'))
drop FUNCTION GetPlannedShiftTimes;
GO
CREATE FUNCTION GetPlannedShiftTimes(@StartTime DateTime2,
	@EndTime DateTime2,
	@machine varchar(255))
RETURNS @table TABLE( 
	StatusType varchar(255),
	StatusNameLevel1 varchar(255),
	StatusNameLevel2 varchar(255),
	TimeSumInMinutes float,
	TimeSumInSeconds bigint,
	Occurrences int,
	Time1 datetime2,
	Time2 datetime2)  

BEGIN	
	declare @lastStatusLevel1 varchar(255);
	declare @lastStatusLevel2 varchar(255);
	declare @lastStatusLevel1ForInsert varchar(255);
	declare @lastStatusLevel2ForInsert varchar(255);
	declare @lastStatusTime datetime2 = @StartTime;
	declare @StatusTime1 datetime2 = @StartTime;
	declare @StatusTime2 datetime2 = @StartTime;
	declare @StatusLevel1 varchar(255);
	declare @StatusLevel2 varchar(255);
	declare @StatusType varchar(255);
	declare @MachineName varchar(255);
	declare @lastOperatorTime datetime2 = @StartTime;
	declare @lastShiftQualifier varchar(10);
	declare @lastShiftType varchar(10);
	declare @lastShiftTime datetime2;
	declare @isWorkingTime Bit = 0;
	declare @SAPMachine varchar(255);
	declare @lastproductiveStatusLevel1 varchar(255);
	declare @lastproductiveStatusLevel2 varchar(255);
	declare @lastStatusType varchar(255) = 'Shift Calendar';
	declare @lastTimeToSet datetime2;

	declare @StatusChanges CURSOR;
	
	SELECT @SAPMachine=[TextValue]
	  FROM [smartKPIMachineKeyValueData]
	  where Machine = @Machine
	  and PropertyKey = 'SAPWorkcenterNumber';

	select top(1) @lastShiftTime=[Time]
			,@lastShiftQualifier=[Qualifier]
			,@lastShiftType=Type from 
		(SELECT [StartTime] as [Time]
			,[Qualifier]
			,'start' as Type
			FROM [shiftCalendar]
			where Machine = @SAPMachine
			and [StartTime] <= @StartTime
		union
		SELECT [EndTime]
			,[Qualifier]
			,'end'
			FROM [shiftCalendar]
			where Machine = @SAPMachine
			and [EndTime] <= @StartTime	) x	
	order by 1 desc, 3 desc;	
	
	set @lastShiftTime = @StartTime;
	
	if (@lastShiftType = 'start')
	BEGIN
		set @isWorkingTime = 1;
	END;
			
	set @lastStatusLevel1 = @lastShiftQualifier;
	set @lastStatusLevel2 = @lastShiftType;
	
			
	SET @lastStatusLevel1ForInsert = @lastStatusLevel1;
	SET @lastStatusLevel2ForInsert = @lastStatusLevel2;

	SET @StatusChanges = CURSOR FOR 
	
	SELECT StatusTime1, StatusTime2, StatusLevel1, StatusLevel2, StatusType from
		(select StatusTime1, StatusTime2, StatusLevel1, StatusLevel2, StatusType from
			(SELECT [StartTime] as StatusTime1
				,[StartTime] as StatusTime2
				,[Qualifier] as StatusLevel1
				,'start' as StatusLevel2
				,'Shift Calendar' as StatusType
				FROM [shiftCalendar]
				where Machine = @SAPMachine
				and [StartTime] > @StartTime	
				and [StartTime] < @EndTime		
			union
			SELECT [EndTime]
				,[EndTime]
				,[Qualifier]
				,'end'
				,'Shift Calendar'
				FROM [shiftCalendar]
				where Machine = @SAPMachine
				and [EndTime] > @StartTime	
				and [EndTime] < @EndTime		
			
			) x 		
			)  y 
			-- filter out the status comming at the same time as last produced part
			where y.StatusTime1 not in (select ProductionTime as StatusTime1 from 
			(Select ProductionTime,CurrentPartNumber, oldPartNumber, oldProductionTime FROM 
				(SELECT ProductionTime, PartNumber as CurrentPartNumber,lag(PartNumber,1) OVER (ORDER BY ProductionTime desc) as oldPartNumber,lag(ProductionTime,1) OVER (ORDER BY ProductionTime desc) as oldProductionTime  FROM  smartKPI 
				where  Machine=@Machine and  ProductionTime between @StartTime and @EndTime) c where  CurrentPartNumber<>oldPartNumber)d)
				order by 1, 4;

	
	
	OPEN @StatusChanges;
	
	FETCH NEXT FROM @StatusChanges into @StatusTime1, @StatusTime2, @StatusLevel1, @StatusLevel2, @StatusType;
		WHILE @@FETCH_STATUS = 0
			BEGIN;
			--Pre 
			if (@lastStatusType = 'Operator Screen')
			BEGIN
				set @lastproductiveStatusLevel1 = @lastStatusLevel1;
				set @lastproductiveStatusLevel2 = @lastStatusLevel2;
			END;
			
			if (@lastStatusType = 'Shift Calendar' and @lastStatusLevel2 = 'start')
			BEGIN
				set @isWorkingTime = 1;
			END;
			if (@lastStatusType = 'Shift Calendar' and @lastStatusLevel2 = 'end')
			BEGIN
				set @isWorkingTime = 0;
			END;
			
			if (@isWorkingTime = 0)
			BEGIN
				set @lastStatusLevel1ForInsert = 'Unplanned';
				set @lastStatusLevel2ForInsert = 'Unplanned';
			END;
			ELSE
			BEGIN
				set @lastStatusLevel1ForInsert = @lastproductiveStatusLevel1;
				set @lastStatusLevel2ForInsert = @lastproductiveStatusLevel2;
			END;
			BEGIN
			
				insert into @table (StatusType, StatusNameLevel1, StatusNameLevel2, Time1, Time2, Occurrences)
					select 'Temp1', @lastStatusLevel1ForInsert, @lastStatusLevel2ForInsert, @lastStatusTime, @StatusTime1, 13;


				insert into @table (StatusType, StatusNameLevel1, StatusNameLevel2, Time1, Time2, Occurrences)
					select 'Temp1', '-', @lastStatusLevel1ForInsert, @lastStatusTime, @StatusTime1, 14;
					
			END;
			--Post
			if (@StatusType != 'newPart')
			BEGIN
				if (@lastStatusType = 'Shift Calendar')
				BEGIN
					SET @lastShiftTime = @StatusTime1;
					set @lastShiftQualifier = @StatusLevel1;
					set @lastShiftType = @StatusLevel2;
				END;
				ELSE
				BEGIN
					SET @lastOperatorTime = @StatusTime1;
				END;

			END;
			SET @lastStatusLevel1 = @StatusLevel1;
			SET @lastStatusLevel2 = @StatusLevel2;
			SET @lastStatusType = @StatusType;
		
			SET @lastStatusTime = @StatusTime1;
			
				
			
			FETCH NEXT FROM @StatusChanges into @StatusTime1, @StatusTime2, @StatusLevel1, @StatusLevel2, @StatusType;
			END;
	CLOSE @StatusChanges;
	DEALLOCATE @StatusChanges;


	if (@lastStatusType = 'Shift Calendar' and @lastStatusLevel2 = 'start')
	BEGIN
		set @isWorkingTime = 1;
	END;
	if (@lastStatusType = 'Shift Calendar' and @lastStatusLevel2 = 'end')
	BEGIN
		set @isWorkingTime = 0;
	END;
	
	if (@isWorkingTime = 0)
	BEGIN
		set @lastStatusLevel1ForInsert = 'Unplanned';
		set @lastStatusLevel2ForInsert = 'Unplanned';
	END;
	ELSE
	BEGIN
		set @lastStatusLevel1ForInsert = @lastproductiveStatusLevel1;
		set @lastStatusLevel2ForInsert = @lastproductiveStatusLevel2;
	END;
	
	set @lastTimeToSet = @EndTime;

	BEGIN
	
		insert into @table (StatusType, StatusNameLevel1, StatusNameLevel2, Time1, Time2, Occurrences)
			select 'Temp1', @lastStatusLevel1ForInsert, @lastStatusLevel2ForInsert, @lastStatusTime, @lastTimeToSet, 23;
			

		insert into @table (StatusType, StatusNameLevel1, StatusNameLevel2, Time1, Time2, Occurrences)
			select 'Temp1', '-', @lastStatusLevel1ForInsert, @lastStatusTime, @lastTimeToSet, 24;
		
	END;
--*************************************************************************************************************	
	update @table set Time2 = Time1 where Time1 > Time2;			
	update @table set TimeSumInSeconds = DATEDIFF_BIG(ms,Time1, Time2) where StatusType = 'Temp1';
		
	insert into @table (StatusType, StatusNameLevel1, StatusNameLevel2, TimeSumInSeconds, Occurrences)
		select 'Temp2', StatusNameLevel1, StatusNameLevel2, sum(TimeSumInSeconds), count(*)
			from @table
			where StatusType = 'Temp1'
			group by StatusNameLevel1, StatusNameLevel2;

	delete from @table where StatusType = 'Temp1';
	
	update @table set StatusType = 'Plan' where StatusType = 'Temp2' and StatusNameLevel2 = 'Unplanned';
	update @table set StatusType = 'Time Actual' where StatusType = 'Temp2' and StatusNameLevel2 != 'Unplanned';

	insert into @table (StatusType, StatusNameLevel1, TimeSumInSeconds)
		SELECT 'Temp3', Qualifier, sum(DATEDIFF_BIG(ms,StartTime, EndTime))
			FROM [shiftCalendar]
			where Machine = @SAPMachine
			and [StartTime] >= @StartTime 
			and EndTime <= @EndTime
			group by Qualifier;

	insert into @table (StatusType, StatusNameLevel1, TimeSumInSeconds)
		SELECT 'Temp3', Qualifier, sum(DATEDIFF_BIG(ms,StartTime, @EndTime))
			FROM [shiftCalendar]
			where Machine = @SAPMachine
			and [StartTime] >= @StartTime 
			and EndTime > @EndTime
			and [StartTime] < @EndTime
			group by Qualifier;
		
	insert into @table (StatusType, StatusNameLevel1, TimeSumInSeconds)
		SELECT 'Temp3', Qualifier, sum(DATEDIFF_BIG(ms,@StartTime, EndTime))
			FROM [shiftCalendar]
			where Machine = @SAPMachine
			and [StartTime] < @StartTime 
			and EndTime <= @EndTime
			and [EndTime] > @StartTime 
			group by Qualifier;
		
	insert into @table (StatusType, StatusNameLevel1, TimeSumInSeconds)
		SELECT 'Temp3', Qualifier, sum(DATEDIFF_BIG(ms,@StartTime, @EndTime))
			FROM [shiftCalendar]
			where Machine = @SAPMachine
			and [StartTime] < @StartTime 
			and EndTime > @EndTime
			group by Qualifier;
	
	insert into @table (StatusType, StatusNameLevel1, TimeSumInSeconds)
		select 'Plan', StatusNameLevel1, sum(TimeSumInSeconds)
			from @table
			where StatusType = 'Temp3'
			group by StatusNameLevel1;

	delete from @table where StatusType = 'Temp3';
	delete from @table where StatusType = 'Plan' and StatusNameLevel1 = '-';

	update @table set StatusNameLevel2 = StatusNameLevel1 where StatusType = 'Plan';
	
	update @table set StatusNameLevel1 = 'Planned Break' where StatusNameLevel1 = 'B';
	update @table set StatusNameLevel1 = 'Planned Working Time' where StatusNameLevel1 = 'W';
	update @table set StatusNameLevel1 = 'Planned Downtime (M)' where StatusNameLevel1 = 'M';
	update @table set StatusNameLevel1 = 'Planned Downtime (P)' where StatusNameLevel1 = 'P';
	update @table set StatusNameLevel1 = 'Unplanned Downtime (D)' where StatusNameLevel1 = 'D';
	
	update @table set TimeSumInSeconds = Round(TimeSumInSeconds/1000.0,0);
	update @table set TimeSumInMinutes = round(cast(TimeSumInSeconds as float)/60.0,2);
		
	delete from @table where TimeSumInSeconds = 0;
	delete from @table where StatusType = 'Temp2';
	return;
	
END;

