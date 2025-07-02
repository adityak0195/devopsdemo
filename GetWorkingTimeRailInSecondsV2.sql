--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetWorkingTimeRailInSecondsV2';
--------------------------------------------------------------
--------------------------------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetWorkingTimeRailInSecondsV2'))
drop FUNCTION GetWorkingTimeRailInSecondsV2;
GO
CREATE FUNCTION  GetWorkingTimeRailInSecondsV2   
( @StartDate DateTime2,
  @EndDate DateTime2,
  @Machine varchar(255)
)  
RETURNS int  
	BEGIN
	
		declare @tableWithWorkingTime table (StartTime datetime2, EndTime datetime2, diff bigint, type varchar(255));
		declare @tableActivatedMaintenanceTimes table (StartTime datetime2, EndTime datetime2, diff bigint, type varchar(255));
		Declare @cursorActivatedMaintenanceTimes CURSOR;
		DECLARE @StartActivatedMaintenanceTime datetime2;
		DECLARE @EndActivatedMaintenanceTime datetime2;
		DECLARE @WorkingTimeCVSInSeconds int;
		declare @SAPMachine varchar(255);
		
		SELECT @SAPMachine=[TextValue]
		  FROM [smartKPIMachineKeyValueData]
		  where Machine = @Machine
		  and PropertyKey = 'SAPWorkcenterNumber';

		with timePeriodsWithWorkingTime as ( 
			select
				Id, StartTime, EndTime,
				ROW_NUMBER() over (order by StartTime, EndTime) as rn
			from shiftCalendar
			where (StartTime between @StartDate and @EndDate or EndTime  between @StartDate and @EndDate)
			and Machine = @SAPMachine
			and Qualifier = 'W'
		), cteWithWorkingTime as (
			select Id, StartTime, EndTime, rn, 1 as GroupId
			from timePeriodsWithWorkingTime
			where rn = 1
			union all
		select -- recursive sql query
			p2.Id,
			case
				when (p1.StartTime between p2.StartTime and p2.EndTime) then p2.StartTime
				when (p2.StartTime between p1.StartTime and p1.EndTime) then p1.StartTime
				when (p1.StartTime < p2.StartTime and p1.EndTime > p2.EndTime) then p1.StartTime
				when (p1.StartTime > p2.StartTime and p1.EndTime < p2.EndTime) then p2.StartTime
				else p2.StartTime
			end as StartTime,
			case
				when (p1.EndTime between p2.StartTime and p2.EndTime) then p2.EndTime
				when (p2.EndTime between p1.StartTime and p1.EndTime) then p1.EndTime
				when (p1.StartTime < p2.StartTime and p1.EndTime > p2.EndTime) then p1.EndTime
				when (p1.StartTime > p2.StartTime and p1.EndTime < p2.EndTime) then p2.EndTime
				else p2.EndTime
			end as EndTime,
			p2.rn,
			case when
				(p1.StartTime between p2.StartTime and p2.EndTime) or
				(p1.EndTime between p2.StartTime and p2.EndTime) or
				(p1.StartTime < p2.StartTime and p1.EndTime > p2.EndTime) or
				(p1.StartTime > p2.StartTime and p1.EndTime < p2.EndTime)
				then
				p1.GroupId
				else
				(p1.GroupId+1)
			end as GroupId
			from cteWithWorkingTime p1 -- referencing CTE itself
			inner join timePeriodsWithWorkingTime p2 on (p1.rn+1) = p2.rn
		), groupedTimesWithWorkingTime as (
		select 
			GroupId, 
			min(case when StartTime < @StartDate then @StartDate else StartTime end) StartTime, 
			max(case when EndTime > @EndDate then @EndDate else EndTime end) EndTime, 
			DATEDIFF(second, min(case when StartTime < @StartDate then @StartDate else StartTime end), max(case when EndTime > @EndDate then @EndDate else EndTime end)) as diff,
			'Uptime' as type
		from cteWithWorkingTime
		group by GroupId
)
		insert into @tableWithWorkingTime (StartTime, EndTime, diff, type)
		select StartTime, EndTime, diff, type
		from groupedTimesWithWorkingTime
		OPTION (MAXRECURSION 0);

		with timePeriodsActivatedMaintenanceTimes as ( 
			select
				Id, StartTime, EndTime,
				ROW_NUMBER() over (order by StartTime, EndTime) as rn
			from shiftCalendar
			where (StartTime between @StartDate and @EndDate or EndTime  between @StartDate and @EndDate)
			and Machine = @SAPMachine
			and Qualifier in ('PS', 'PE')
		), cteActivatedMaintenanceTimes as (
			select Id, StartTime, EndTime, rn, 1 as GroupId
			from timePeriodsActivatedMaintenanceTimes
			where rn = 1
			union all
		select -- recursive sql query
			p2.Id,
			case
				when (p1.StartTime between p2.StartTime and p2.EndTime) then p2.StartTime
				when (p2.StartTime between p1.StartTime and p1.EndTime) then p1.StartTime
				when (p1.StartTime < p2.StartTime and p1.EndTime > p2.EndTime) then p1.StartTime
				when (p1.StartTime > p2.StartTime and p1.EndTime < p2.EndTime) then p2.StartTime
				else p2.StartTime
			end as StartTime,
			case
				when (p1.EndTime between p2.StartTime and p2.EndTime) then p2.EndTime
				when (p2.EndTime between p1.StartTime and p1.EndTime) then p1.EndTime
				when (p1.StartTime < p2.StartTime and p1.EndTime > p2.EndTime) then p1.EndTime
				when (p1.StartTime > p2.StartTime and p1.EndTime < p2.EndTime) then p2.EndTime
				else p2.EndTime
			end as EndTime,
			p2.rn,
			case when
				(p1.StartTime between p2.StartTime and p2.EndTime) or
				(p1.EndTime between p2.StartTime and p2.EndTime) or
				(p1.StartTime < p2.StartTime and p1.EndTime > p2.EndTime) or
				(p1.StartTime > p2.StartTime and p1.EndTime < p2.EndTime)
				then
				p1.GroupId
				else
				(p1.GroupId+1)
			end as GroupId
			from cteActivatedMaintenanceTimes p1 -- referencing CTE itself
			inner join timePeriodsActivatedMaintenanceTimes p2 on (p1.rn+1) = p2.rn
		), groupedTimesActivatedMaintenanceTimes as (
		select 
			GroupId, 
			min(case when StartTime < @StartDate then @StartDate else StartTime end) StartTime, 
			max(case when EndTime > @EndDate then @EndDate else EndTime end) EndTime, 
			DATEDIFF(second, min(case when StartTime < @StartDate then @StartDate else StartTime end), max(case when EndTime > @EndDate then @EndDate else EndTime end)) as diff,
			'ActivatedMaintenanceTime' as type
		from cteActivatedMaintenanceTimes
		group by GroupId
)
		insert into @tableActivatedMaintenanceTimes (StartTime, EndTime, diff, type)
		select StartTime, EndTime, diff, type
		from groupedTimesActivatedMaintenanceTimes
		OPTION (MAXRECURSION 0);



		SET @cursorActivatedMaintenanceTimes = CURSOR FOR
		select StartTime, EndTime from @tableActivatedMaintenanceTimes;

		OPEN @cursorActivatedMaintenanceTimes;
			FETCH NEXT FROM @cursorActivatedMaintenanceTimes into @StartActivatedMaintenanceTime, @EndActivatedMaintenanceTime;
			WHILE @@FETCH_STATUS = 0
			BEGIN;
				delete from @tableWithWorkingTime 
					where StartTime >= @StartActivatedMaintenanceTime 
					and EndTime <= @EndActivatedMaintenanceTime;
				update @tableWithWorkingTime set EndTime = @StartActivatedMaintenanceTime 
					where StartTime < @StartActivatedMaintenanceTime 
					and EndTime <= @EndActivatedMaintenanceTime 
					and EndTime >  @StartActivatedMaintenanceTime;
				update @tableWithWorkingTime set StartTime = @EndActivatedMaintenanceTime 
					where StartTime >= @StartActivatedMaintenanceTime 
					and EndTime > @EndActivatedMaintenanceTime
					and StartTime < @EndActivatedMaintenanceTime;
				insert into @tableWithWorkingTime (StartTime, EndTime) 
					select StartTime, @StartActivatedMaintenanceTime from @tableWithWorkingTime
					where StartTime < @StartActivatedMaintenanceTime and EndTime > @EndActivatedMaintenanceTime;
				insert into @tableWithWorkingTime (StartTime, EndTime) 
					select @EndActivatedMaintenanceTime, EndTime from @tableWithWorkingTime
					where StartTime < @StartActivatedMaintenanceTime and EndTime > @EndActivatedMaintenanceTime;
				delete from @tableWithWorkingTime 
					where StartTime < @StartActivatedMaintenanceTime and EndTime > @EndActivatedMaintenanceTime;

				FETCH NEXT FROM @cursorActivatedMaintenanceTimes into @StartActivatedMaintenanceTime, @EndActivatedMaintenanceTime;
			END;
		CLOSE @cursorActivatedMaintenanceTimes;
		DEALLOCATE @cursorActivatedMaintenanceTimes;

		update @tableWithWorkingTime set diff = DATEDIFF(second, StartTime, EndTime);
		select @WorkingTimeCVSInSeconds=isnull(sum(diff),0) from @tableWithWorkingTime;

	
        RETURN @WorkingTimeCVSInSeconds; 
    END;
	
	
GO	
