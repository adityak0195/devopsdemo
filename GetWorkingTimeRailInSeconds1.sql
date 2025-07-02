--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetWorkingTimeRailInSeconds1';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetWorkingTimeRailInSeconds1'))
drop FUNCTION GetWorkingTimeRailInSeconds1;
GO
CREATE FUNCTION  GetWorkingTimeRailInSeconds1   
( @Machine varchar(255),
  @StartDate DateTime2,
  @EndDate DateTime2
)  
RETURNS @table TABLE ( 
	KPIDateTimeStart DateTime2, 
	KPIDateTimeEnd DateTime2,
	KPIFloatValue float)  
    BEGIN   
    
    
    --DEPRECATED!!!!!!!!!!!!!!!!!!!!!!
    -- replaced by GetWorkingTimeRailInSeconds1Core and GetWorkingTimeRailInSeconds1Extended
    --DEPRECATED!!!!!!!!!!!!!!!!!!!!!!
	
					insert into @table (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select StartTime, EndTime, isnull(DATEDIFF_BIG(s, StartTime, EndTime),0)
							from shiftCalendar
								where Machine = @Machine
								and StartTime >= @StartDate
								and EndTime <= @EndDate
								and Qualifier = 'W';					
					insert into @table (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select @StartDate, EndTime, isnull(DATEDIFF_BIG(s, @StartDate, EndTime),0)
						from shiftCalendar
							where Machine = @Machine
							and StartTime < @StartDate
							and EndTime > @StartDate
							and EndTime <= @EndDate
							and Qualifier = 'W';
					insert into @table (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select StartTime, @EndDate, isnull(DATEDIFF_BIG(s, StartTime, @EndDate),0)
							from shiftCalendar
								where Machine = @Machine
								and StartTime >= @StartDate
								and StartTime < @EndDate
								and EndTime > @EndDate
								and Qualifier = 'W';
					insert into @table (KPIDateTimeStart, KPIDateTimeEnd, KPIFloatValue) 
						select @StartDate, @EndDate, isnull(DATEDIFF_BIG(s, @StartDate, @EndDate),0)
							from shiftCalendar
								where Machine = @Machine
								and StartTime < @StartDate
								and EndTime > @EndDate
								and Qualifier = 'W';
        RETURN   
    END;
	
	
GO	
