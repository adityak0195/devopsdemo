--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetWorkingTimeRailInSeconds';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetWorkingTimeRailInSeconds'))
drop FUNCTION GetWorkingTimeRailInSeconds;
GO
CREATE FUNCTION  GetWorkingTimeRailInSeconds   
( @Machine varchar(255),
  @StartDate DateTime2,
  @EndDate DateTime2
)  
RETURNS int  
    BEGIN   


    --DEPRECATED!!!!!!!!!!!!!!!!!!!!!!
    -- replaced by GetWorkingTimeRailInSeconds1Core and GetWorkingTimeRailInSeconds1Extended
    --DEPRECATED!!!!!!!!!!!!!!!!!!!!!!


		declare @WorkingTimeInSeconds int;
		select @WorkingTimeInSeconds=isnull(sum(KPIFloatValue),0) from GetWorkingTimeRailInSeconds1(@Machine, @StartDate, @EndDate)
        RETURN @WorkingTimeInSeconds  
    END;
	
	
GO	