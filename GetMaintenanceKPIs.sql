--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetMaintenanceKPIs';
--------------------------------------------------------------
--------------------------------------------------------------

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetMaintenanceKPIs'))
drop FUNCTION GetMaintenanceKPIs;
GO
CREATE FUNCTION [dbo].[GetMaintenanceKPIs]
	(@StartDateTime DateTime2,
	@EndDateTime DateTime2,
	@Machine varchar(255),
	@MainStationOnly bit)
RETURNS @table TABLE ( 
	Machine varchar(255),
	SumTBF float,
	CountTBF float, 
	MTBF float,
	SumTTR float,
	CountTTR float,
	MTTR float,
	SumRT float,
	CountRT float,
	MRT float,
	StartTime DateTime2,
	EndTime DateTime2)  
BEGIN;
if @MainStationOnly = 1
BEGIN 
DECLARE @MainStation varchar(255);
SELECT @MainStation=[TextValue]
		FROM [smartKPIMachineKeyValueData]
		where PropertyKey = 'MainStationForLineStatus'
		and Machine = @Machine;
INSERT INTO @table (Machine,SumTBF,CountTBF,MTBF,SumTTR, CountTTR, MTTR, SumRT, CountRT, MRT)

SELECT Machine
,sum(SumTBF) as SumTBF
,sum(CountTBF) as CountTBF
,sum(MTBF) as MTBF
,sum(SumTTR) as SumTTR
,sum(CountTTR) as CountTTR
,sum(MTTR) as MTTR	
,sum(SumRT) as  SumRT
,sum(CountRT) as  CountRT
,sum(MRT) as MRT 

FROM (
SELECT Machine
,null as SumTBF
,null as CountTBF
,null as MTBF
		,Sum(TTR) as SumTTR
		,count(NULLIF(TTR,0) ) as CountTTR
		,ROUND((CONVERT(float,Sum(TTR))/60)/count(NULLIF(TTR,0)), 2) as MTTR	
,null as SumRT
,null as CountRT
,null as MRT

	FROM (		
		SELECT Machine,CASE [Status]
		WHEN 'MT Notified' THEN (datediff(MINUTE,StatusTime, nextTime))
		WHEN 'Breakdown End' THEN 0
		END AS TTR
	FROM (
		SELECT [Machine]
	    ,[StatusTime]
	    ,[Status]
        ,[StatusType]
        ,[nextStatus]
	    ,ISNULL(lag([StatusTime],1)  OVER (ORDER BY [StatusTime] desc),@EndDateTime) as nextTime
    FROM (
        SELECT [TextValue] as Machine
        ,[StatusTime]
        ,[Status]
        ,[StatusType]
        ,lag([Status],1)  OVER (ORDER BY [StatusTime] desc) as nextStatus
		FROM smartKPIMachineStatusData a, smartKPIMachineKeyValueData b where StatusType='PM Data'  and ([Status]='MT Notified' or [Status]='Breakdown End')
        and [StatusTime]>=@StartDateTime and [StatusTime]<=@EndDateTime and b.Machine=a.Machine and b.PropertyKey='KBLocalLineThing' and b.Machine=@MainStation 
      ) x
	) c where nextStatus<>[Status]         
) d group by Machine
--
UNION ALL            
SELECT Machine
 		,Sum(TBF) as SumTBF
 		,count(NULLIF(TBF,0)) as CountTBF
 		,ROUND((CONVERT(float,Sum(TBF))/60)/count(NULLIF(TBF,0)), 2) as MTBF
,null as SumTTR
,null as CountTTR
,null as MTTR
,null as SumRT
,null as CountRT
,null as MRT
		FROM (
  Select Machine
	,CASE [Status]
	   WHEN 'KBMaschStatus.1.TI.MachineBreakdown' THEN 0   
       WHEN 'Breakdown End' THEN (datediff(MINUTE,StatusTime, nextTime))
	  END AS TBF
  FROM    (
      SELECT [Machine]
	  ,[StatusTime]
	  ,[Status]
      ,[StatusType]
      ,[nextStatus]
	  ,ISNULL(lag([StatusTime],1)  OVER (ORDER BY [StatusTime] desc),@EndDateTime) as nextTime
    FROM (
        SELECT [TextValue] as Machine
        ,[StatusTime]
        ,[Status]
        ,[StatusType]
        ,lag([Status],1)  OVER (ORDER BY [StatusTime] desc) as nextStatus
	   FROM smartKPIMachineStatusData a, smartKPIMachineKeyValueData b where ((StatusType='PM Data' and [Status]='Breakdown End') OR (StatusType='Operator Screen' and ([Status]='KBMaschStatus.1.TI.MachineBreakdown')))
        and [StatusTime]>=@StartDateTime and [StatusTime]<=@EndDateTime and b.Machine=a.Machine and b.PropertyKey='KBLocalLineThing' and b.Machine=@MainStation 
      ) x
	) c where nextStatus<>[Status]
            
) d group by Machine

UNION ALL            

    SELECT Machine
,null as SumTBF
,null as CountTBF
,null as MTBF
,null as SumTTR
,null as CountTTR
,null as MTTR
		,Sum(RT) as SumRT
		,count(NULLIF(RT,0) ) as CountRT
		,ROUND((CONVERT(float,Sum(RT))/60)/count(NULLIF(RT,0)), 2) as MRT
		FROM (
  Select Machine
	,CASE [Status]
	   WHEN 'MT Notified' THEN (datediff(MINUTE,StatusTime, nextTime))
       WHEN 'MT onsite' THEN 0
	  END AS RT
  FROM    (
      SELECT [Machine]
	  ,[StatusTime]
	  ,[Status]
      ,[StatusType]
      ,[nextStatus]
	  ,ISNULL(lag([StatusTime],1)  OVER (ORDER BY [StatusTime] desc),@EndDateTime) as nextTime
    FROM (
        SELECT [TextValue] as Machine
        ,[StatusTime]
        ,[Status]
        ,[StatusType]
        ,lag([Status],1)  OVER (ORDER BY [StatusTime] desc) as nextStatus
	   FROM smartKPIMachineStatusData a, smartKPIMachineKeyValueData b where (StatusType='PM Data' and ([Status]='MT Notified' OR [Status]='MT onsite'))
        and [StatusTime]>=@StartDateTime and a.[StatusTime]<=@EndDateTime and b.Machine=a.Machine and b.PropertyKey='KBLocalLineThing' and b.Machine=@MainStation 
      ) x
	) c where nextStatus<>[Status]
-- 
            
) d group by Machine

) z group by Machine

-- inserting time periods for maintenance KPIs 
update @table set StartTime = @StartDateTime, EndTime = @EndDateTime

END;

ELSE IF @MainStationOnly = 0
BEGIN

INSERT INTO @table (Machine,SumTBF,CountTBF,MTBF,SumTTR, CountTTR, MTTR, SumRT, CountRT, MRT)

SELECT Machine
,sum(SumTBF) as SumTBF
,sum(CountTBF) as CountTBF
,sum(MTBF) as MTBF
,sum(SumTTR) as SumTTR
,sum(CountTTR) as CountTTR
,sum(MTTR) as MTTR	
,sum(SumRT) as  SumRT
,sum(CountRT) as  CountRT
,sum(MRT) as MRT 

FROM (
SELECT Machine
,null as SumTBF
,null as CountTBF
,null as MTBF
		,Sum(TTR) as SumTTR
		,count(NULLIF(TTR,0) ) as CountTTR
		,ROUND((CONVERT(float,Sum(TTR))/60)/count(NULLIF(TTR,0)), 2) as MTTR	
,null as SumRT
,null as CountRT
,null as MRT

	FROM (		
		SELECT Machine,CASE [Status]
		WHEN 'MT Notified' THEN (datediff(MINUTE,StatusTime, nextTime))
		WHEN 'Breakdown End' THEN 0
		END AS TTR
	FROM (
		SELECT [Machine]
	    ,[StatusTime]
	    ,[Status]
        ,[StatusType]
        ,[nextStatus]
	    ,ISNULL(lag([StatusTime],1)  OVER (ORDER BY [StatusTime] desc),@EndDateTime) as nextTime
    FROM (
        SELECT [TextValue] as Machine
        ,[StatusTime]
        ,[Status]
        ,[StatusType]
        ,lag([Status],1)  OVER (ORDER BY [StatusTime] desc) as nextStatus
		FROM smartKPIMachineStatusData a, smartKPIMachineKeyValueData b where StatusType='PM Data'  and ([Status]='MT Notified' or [Status]='Breakdown End')
        and [StatusTime]>=@StartDateTime and [StatusTime]<=@EndDateTime and b.Machine=a.Machine and b.PropertyKey='KBLocalLineThing' and b.TextValue=@Machine 
      ) x
	) c where nextStatus<>[Status]         
) d group by Machine
--
UNION ALL            
SELECT Machine
 		,Sum(TBF) as SumTBF
 		,count(NULLIF(TBF,0)) as CountTBF
 		,ROUND((CONVERT(float,Sum(TBF))/60)/count(NULLIF(TBF,0)), 2) as MTBF
,null as SumTTR
,null as CountTTR
,null as MTTR
,null as SumRT
,null as CountRT
,null as MRT
		FROM (
  Select Machine
	,CASE [Status]
	   WHEN 'KBMaschStatus.1.TI.MachineBreakdown' THEN 0   
       WHEN 'Breakdown End' THEN (datediff(MINUTE,StatusTime, nextTime))
	  END AS TBF
  FROM    (
      SELECT [Machine]
	  ,[StatusTime]
	  ,[Status]
      ,[StatusType]
      ,[nextStatus]
	  ,ISNULL(lag([StatusTime],1)  OVER (ORDER BY [StatusTime] desc),@EndDateTime) as nextTime
    FROM (
        SELECT [TextValue] as Machine
        ,[StatusTime]
        ,[Status]
        ,[StatusType]
        ,lag([Status],1)  OVER (ORDER BY [StatusTime] desc) as nextStatus
	   FROM smartKPIMachineStatusData a, smartKPIMachineKeyValueData b where ((StatusType='PM Data' and [Status]='Breakdown End') OR (StatusType='Operator Screen' and ([Status]='KBMaschStatus.1.TI.MachineBreakdown')))
        and [StatusTime]>=@StartDateTime and [StatusTime]<=@EndDateTime and b.Machine=a.Machine and b.PropertyKey='KBLocalLineThing' and b.TextValue=@Machine 
      ) x
	) c where nextStatus<>[Status]
            
) d group by Machine

UNION ALL            

    SELECT Machine
,null as SumTBF
,null as CountTBF
,null as MTBF
,null as SumTTR
,null as CountTTR
,null as MTTR
		,Sum(RT) as SumRT
		,count(NULLIF(RT,0) ) as CountRT
		,ROUND((CONVERT(float,Sum(RT))/60)/count(NULLIF(RT,0)), 2) as MRT
		FROM (
  Select Machine
	,CASE [Status]
	   WHEN 'MT Notified' THEN (datediff(MINUTE,StatusTime, nextTime))
       WHEN 'MT onsite' THEN 0
	  END AS RT
  FROM    (
      SELECT [Machine]
	  ,[StatusTime]
	  ,[Status]
      ,[StatusType]
      ,[nextStatus]
	  ,ISNULL(lag([StatusTime],1)  OVER (ORDER BY [StatusTime] desc),@EndDateTime) as nextTime
    FROM (
        SELECT [TextValue] as Machine
        ,[StatusTime]
        ,[Status]
        ,[StatusType]
        ,lag([Status],1)  OVER (ORDER BY [StatusTime] desc) as nextStatus
	   FROM smartKPIMachineStatusData a, smartKPIMachineKeyValueData b where (StatusType='PM Data' and ([Status]='MT Notified' OR [Status]='MT onsite'))
        and [StatusTime]>=@StartDateTime and a.[StatusTime]<=@EndDateTime and b.Machine=a.Machine and b.PropertyKey='KBLocalLineThing' and b.TextValue=@Machine 
      ) x
	) c where nextStatus<>[Status]
-- 
            
) d group by Machine

) z group by Machine

-- inserting time periods for maintenance KPIs 
update @table set StartTime = @StartDateTime, EndTime = @EndDateTime

END;

return;

END;
GO
