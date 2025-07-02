--------------------------------------------------------------
--------------------------------------------------------------
print '-- GetMachineDowntimeData';
--------------------------------------------------------------
--------------------------------------------------------------
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'GetMachineDowntimeData'))
drop FUNCTION GetMachineDowntimeData;
GO
CREATE FUNCTION GetMachineDowntimeData
	(@Machine varchar(255),
	@StatusType varchar(255),
	@StartTime DateTime2,
	@EndTime DateTime2)
RETURNS @table TABLE ( 
	Status varchar(255),
	SubStatus varchar(255),
	Type varchar(5),
	StartTime datetime2,
	EndTime datetime2,
	Duration int)  

BEGIN

 insert into @table (Status,SubStatus,Type,StartTime,EndTime,Duration)  
SELECT  OldStatus as Status, OldSubStatus as SubStatus, SUBSTRING(OldStatus, 17, 2) AS 'Type', OldStatusTime as StartTime, NewStatusTime as EndTime,DATEDIFF(minute,OldStatusTime,NewStatusTime) as Duration
 from

(
	 SELECT
	   NewStatusTime, t5.StatusType, t6.Status as NewStatus, t6.SubStatus as  NewSubStatus, @StartTime as OldStatusTime, t5.Status as OldStatus, t5.SubStatus as OldSubStatus
	FROM
	  (SELECT TOP 1
		  Machine,Status,SubStatus, StatusType
	   FROM
		 smartKPIMachineStatusData
	   WHERE Machine=convert(varchar(255), @Machine)  and StatusType=convert(varchar(255), @StatusType) and [StatusTime]<=@StartTime	order by [StatusTime] desc
	   ) as t5 
	   	INNER JOIN
		(SELECT TOP 1
		  [StatusTime] as NewStatusTime,Machine,Status,SubStatus , StatusType
	   FROM
		 smartKPIMachineStatusData
	   WHERE Machine=convert(varchar(255), @Machine)  and StatusType=convert(varchar(255), @StatusType) and [StatusTime]>@StartTime	order by [StatusTime] asc) as t6
		ON
	  t5.StatusType = t6.StatusType
	  UNION ALl 
 (SELECT NewStatusTime, StatusType, Status, SubStatus, OldStatusTime, OldStatus,OldSubStatus 
  FROM 
	(SELECT 
		  ROW_NUMBER() OVER(ORDER BY [StatusTime]) as RN
		  ,[StatusTime] as NewStatusTime
		  ,[Status]
		  ,[SubStatus]
		  ,[StatusType]
	  FROM smartKPIMachineStatusData where Machine=convert(varchar(255), @Machine)  and StatusType=convert(varchar(255), @StatusType) ) t1
	  inner join (SELECT
		  ROW_NUMBER() OVER(ORDER BY [StatusTime]) AS RN2
		  ,[StatusTime] as OldStatusTime
		  ,[Status] as OldStatus
		  ,[SubStatus] as OldSubStatus
	  FROM smartKPIMachineStatusData where Machine=convert(varchar(255), @Machine)  and StatusType=convert(varchar(255), @StatusType))  t2 on t1.RN=t2.RN2+1
  WHERE OldStatusTime>=@StartTime and t1.NewStatusTime<=@EndTime) 
  
UNION ALL	
SELECT min(NewStatusTime) as NewStatusTime, StatusType, NewStatus,NewSubStatus, OldStatusTime, OldStatus,OldSubStatus 
from (
	SELECT top 1 @EndTime as  NewStatusTime, StatusType, [Status] as NewStatus,[SubStatus] as NewSubStatus , [StatusTime] as OldStatusTime, [Status] as OldStatus,[SubStatus] as OldSubStatus 
	FROM smartKPIMachineStatusData WHERE [StatusTime]<=@EndTime and  Machine=convert(varchar(255), @Machine)  and StatusType=convert(varchar(255), @StatusType )  order by [StatusTime] desc
	union all 
	SELECT top 1 getdate() as  NewStatusTime, StatusType, [Status] as NewStatus,[SubStatus] as NewSubStatus , [StatusTime] as OldStatusTime, [Status] as OldStatus,[SubStatus] as OldSubStatus 
	FROM smartKPIMachineStatusData WHERE [StatusTime]<=@EndTime and [StatusTime]<=getdate() and  Machine=convert(varchar(255), @Machine)  and StatusType=convert(varchar(255), @StatusType )  order by [StatusTime] desc
	) x group by StatusType, NewStatus,NewSubStatus, OldStatusTime, OldStatus,OldSubStatus 
 
	  
	  ) t7
	  
 order by OldStatusTime asc

 return;
 END;
GO
