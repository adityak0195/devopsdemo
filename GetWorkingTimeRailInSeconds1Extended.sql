--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetWorkingTimeRailInSeconds1Extended';
--------------------------------------------------------------
--------------------------------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetWorkingTimeRailInSeconds1Extended'))
drop FUNCTION GetWorkingTimeRailInSeconds1Extended;
GO
CREATE FUNCTION  GetWorkingTimeRailInSeconds1Extended   
( @StartDate DateTime2,
  @EndDate DateTime2,
  @Machine varchar(255)
)  
RETURNS int  
	BEGIN
	
        declare @tableWithWorkingTime TABLE ( 
            KPIDateTimeStart DateTime2, 
            KPIDateTimeEnd DateTime2,
            KPIFloatValue float)  ;
        declare @tableActivatedMaintenanceTimes TABLE ( 
            KPIDateTimeStart DateTime2, 
            KPIDateTimeEnd DateTime2,
            KPIFloatValue float)  ;
		Declare @cursorActivatedMaintenanceTimes CURSOR;
		DECLARE @StartActivatedMaintenanceTime datetime2;
		DECLARE @EndActivatedMaintenanceTime datetime2;
		DECLARE @WorkingTimeCVSInSeconds int;
		declare @SAPMachine varchar(255);
		
		SELECT @SAPMachine=[TextValue]
		  FROM [smartKPIMachineKeyValueData]
		  where Machine = @Machine
		  and PropertyKey = 'SAPWorkcenterNumber';

					insert into @tableWithWorkingTime (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select StartTime, EndTime, isnull(DATEDIFF_BIG(s, StartTime, EndTime),0)
							from shiftCalendar
								where Machine = @SAPMachine
								and StartTime >= @StartDate
								and EndTime <= @EndDate
								and Qualifier = 'W';					
					insert into @tableWithWorkingTime (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select @StartDate, EndTime, isnull(DATEDIFF_BIG(s, @StartDate, EndTime),0)
						from shiftCalendar
							where Machine = @SAPMachine
							and StartTime < @StartDate
							and EndTime > @StartDate
							and EndTime <= @EndDate
							and Qualifier = 'W';
					insert into @tableWithWorkingTime (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select StartTime, @EndDate, isnull(DATEDIFF_BIG(s, StartTime, @EndDate),0)
							from shiftCalendar
								where Machine = @SAPMachine
								and StartTime >= @StartDate
								and StartTime < @EndDate
								and EndTime > @EndDate
								and Qualifier = 'W';
					insert into @tableWithWorkingTime (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select @StartDate, @EndDate, isnull(DATEDIFF_BIG(s, @StartDate, @EndDate),0)
							from shiftCalendar
								where Machine = @SAPMachine
								and StartTime < @StartDate
								and EndTime > @EndDate
								and Qualifier = 'W';

					insert into @tableActivatedMaintenanceTimes (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select StartTime, EndTime, isnull(DATEDIFF_BIG(s, StartTime, EndTime),0)
							from shiftCalendar
								where Machine = @SAPMachine
								and StartTime >= @StartDate
								and EndTime <= @EndDate
								and Qualifier in ('E');					
					insert into @tableActivatedMaintenanceTimes (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select @StartDate, EndTime, isnull(DATEDIFF_BIG(s, @StartDate, EndTime),0)
						from shiftCalendar
							where Machine = @SAPMachine
							and StartTime < @StartDate
							and EndTime > @StartDate
							and EndTime <= @EndDate
							and Qualifier in ('E');
					insert into @tableActivatedMaintenanceTimes (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select StartTime, @EndDate, isnull(DATEDIFF_BIG(s, StartTime, @EndDate),0)
							from shiftCalendar
								where Machine = @SAPMachine
								and StartTime >= @StartDate
								and StartTime < @EndDate
								and EndTime > @EndDate
								and Qualifier in ('E');
					insert into @tableActivatedMaintenanceTimes (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select @StartDate, @EndDate, isnull(DATEDIFF_BIG(s, @StartDate, @EndDate),0)
							from shiftCalendar
								where Machine = @SAPMachine
								and StartTime < @StartDate
								and EndTime > @EndDate
								and Qualifier in ('E');


		SET @cursorActivatedMaintenanceTimes = CURSOR FOR
		select KPIDateTimeStart, KPIDateTimeEnd from @tableActivatedMaintenanceTimes;

		OPEN @cursorActivatedMaintenanceTimes;
			FETCH NEXT FROM @cursorActivatedMaintenanceTimes into @StartActivatedMaintenanceTime, @EndActivatedMaintenanceTime;
			WHILE @@FETCH_STATUS = 0
			BEGIN;
				delete from @tableWithWorkingTime 
					where KPIDateTimeStart >= @StartActivatedMaintenanceTime 
					and KPIDateTimeEnd <= @EndActivatedMaintenanceTime;
				update @tableWithWorkingTime set KPIDateTimeEnd = @StartActivatedMaintenanceTime 
					where KPIDateTimeStart < @StartActivatedMaintenanceTime 
					and KPIDateTimeEnd <= @EndActivatedMaintenanceTime 
					and KPIDateTimeEnd >  @StartActivatedMaintenanceTime;
				update @tableWithWorkingTime set KPIDateTimeStart = @EndActivatedMaintenanceTime 
					where KPIDateTimeStart >= @StartActivatedMaintenanceTime 
					and KPIDateTimeEnd > @EndActivatedMaintenanceTime
					and KPIDateTimeStart < @EndActivatedMaintenanceTime;
				insert into @tableWithWorkingTime (KPIDateTimeStart, KPIDateTimeEnd) 
					select KPIDateTimeStart, @StartActivatedMaintenanceTime from @tableWithWorkingTime
					where KPIDateTimeStart < @StartActivatedMaintenanceTime and KPIDateTimeEnd > @EndActivatedMaintenanceTime;
				insert into @tableWithWorkingTime (KPIDateTimeStart, KPIDateTimeEnd) 
					select @EndActivatedMaintenanceTime, KPIDateTimeEnd from @tableWithWorkingTime
					where KPIDateTimeStart < @StartActivatedMaintenanceTime and KPIDateTimeEnd > @EndActivatedMaintenanceTime;
				delete from @tableWithWorkingTime 
					where KPIDateTimeStart < @StartActivatedMaintenanceTime and KPIDateTimeEnd > @EndActivatedMaintenanceTime;

				FETCH NEXT FROM @cursorActivatedMaintenanceTimes into @StartActivatedMaintenanceTime, @EndActivatedMaintenanceTime;
			END;
		CLOSE @cursorActivatedMaintenanceTimes;
		DEALLOCATE @cursorActivatedMaintenanceTimes;

		update @tableWithWorkingTime set KPIFloatValue = DATEDIFF(second, KPIDateTimeStart, KPIDateTimeEnd);
		select @WorkingTimeCVSInSeconds=isnull(sum(KPIFloatValue),0) from @tableWithWorkingTime;
	
        RETURN @WorkingTimeCVSInSeconds; 
    END;
	
	
GO	
