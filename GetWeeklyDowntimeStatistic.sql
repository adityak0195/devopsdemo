--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetWeeklyDowntimeStatistic';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetWeeklyDowntimeStatistic'))
drop FUNCTION GetWeeklyDowntimeStatistic;
GO
CREATE FUNCTION GetWeeklyDowntimeStatistic
	(@DateInWeek DateTime2,
	@machine varchar(255),
	@station varchar(255))
RETURNS @table TABLE ( 
	DayName varchar(10),
	PTimeSumInSeconds int,
	PITimeSumInSeconds int,
	TITimeSumInSeconds int,
	OITimeSumInSeconds int,
	QualityTimeSumInSeconds int,
	UnknownTimeSumInSeconds int,
	UnplannedTimeSumInSeconds int,
	ChangeoverTimeSumInSeconds int,
	OEE2 float,
	Utilization float,
	RQ float)  
BEGIN;

	declare @singleDataTable as TABLE 
		(TimeSumInSeconds int,
		StatusType varchar(255));
	
	declare @StartDate as datetime2;
	declare @EndDate as datetime2;

	Declare @getSingleData CURSOR;
	Declare @TimeSumInSeconds as int;
	Declare @StatusType as varchar(255);

	Declare @PTimeSumInSeconds int;
	Declare @PITimeSumInSeconds int;
	Declare @TITimeSumInSeconds int;
	Declare @OITimeSumInSeconds int;
	Declare @QualityTimeSumInSeconds int;
	Declare @UnknownTimeSumInSeconds int;
	Declare @UnplannedTimeSumInSeconds int;
	Declare @ChangeoverTimeSumInSeconds int;

	Declare @counter int = 0;

	set @StartDate = dateadd(day, -1, dateadd(week, datediff(week, 0, @DateInWeek), 0));
	set @EndDate = dateadd(day, -1, dateadd(day, 1, @StartDate));

	while (@counter < 7)
	BEGIN

		set @StartDate = dateadd(day, 1, @StartDate);
		set @EndDate = dateadd(day, 1, @StartDate);

		SET @getSingleData = CURSOR FOR
			select TimeSumInSeconds, StatusType from dbo.GetDowntimeStatistic(@StartDate, @EndDate, @machine, @station);

		SET @PTimeSumInSeconds = 0;
		SET @PITimeSumInSeconds = 0;
		SET @TITimeSumInSeconds = 0;
		SET @OITimeSumInSeconds = 0;
		SET @QualityTimeSumInSeconds = 0;
		SET @UnknownTimeSumInSeconds = 0;
		SET @UnplannedTimeSumInSeconds = 0;
		SET @ChangeoverTimeSumInSeconds = 0;

		if (@StartDate < getutcdate())
		BEGIN

			OPEN @getSingleData;
				FETCH NEXT FROM @getSingleData into @TimeSumInSeconds, @StatusType;
				WHILE @@FETCH_STATUS = 0
				BEGIN;
					if (@StatusType = 'Productive')
						SET @PTimeSumInSeconds = @TimeSumInSeconds;
					if (@StatusType = 'Planned Interruption')
						SET @PITimeSumInSeconds = @TimeSumInSeconds;
					if (@StatusType = 'Technical Interruption')
						SET @TITimeSumInSeconds = @TimeSumInSeconds;
					if (@StatusType = 'Organisational Interruption')
						SET @OITimeSumInSeconds = @TimeSumInSeconds;
					if (@StatusType = 'Quality')
						SET @QualityTimeSumInSeconds = @TimeSumInSeconds;
					if (@StatusType = 'Unknown')
						SET @UnknownTimeSumInSeconds = @TimeSumInSeconds;
					if (@StatusType = 'Unplanned')
						SET @UnplannedTimeSumInSeconds = @TimeSumInSeconds;
					if (@StatusType = 'Changeover')
						SET @ChangeoverTimeSumInSeconds = @TimeSumInSeconds;

					FETCH NEXT FROM @getSingleData into @TimeSumInSeconds, @StatusType;
				END;
			CLOSE @getSingleData;
		END;
		insert into @table 
			(DayName, 
			PTimeSumInSeconds ,
			PITimeSumInSeconds ,
			TITimeSumInSeconds ,
			OITimeSumInSeconds ,
			QualityTimeSumInSeconds ,
			UnknownTimeSumInSeconds ,
			UnplannedTimeSumInSeconds ,
			ChangeoverTimeSumInSeconds,
			OEE2,
			Utilization,
			RQ			) 
			select 
			case @counter
				when 0 then 'Mo'
				when 1 then 'Tu'
				when 2 then 'We'
				when 3 then 'Th'
				when 4 then 'Fr'
				when 5 then 'Sa'
				when 6 then 'So'
				else '-'
			END, 
			@PTimeSumInSeconds ,
			@PITimeSumInSeconds ,
			@TITimeSumInSeconds ,
			@OITimeSumInSeconds ,
			@QualityTimeSumInSeconds ,
			@UnknownTimeSumInSeconds ,
			@UnplannedTimeSumInSeconds ,
			@ChangeoverTimeSumInSeconds,
			KPIOee, 
			KPIUtilization, 
			KPIRQ 
			from GetUtilizationOee2Truck(@StartDate, @EndDate, @machine);
		set @counter = @counter + 1;

	END;


	return;
END;
GO

--declare @dt as DateTime2 = getutcdate();
--select * from GetWeeklyDowntimeStatistic(@dt, 'KBLisLaa6MachineThing', 'KBLisLaa6DBStationThing')

