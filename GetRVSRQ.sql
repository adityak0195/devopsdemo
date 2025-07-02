-- =============================================
-- Author: Martin Flassak
-- Create date: 03/2024
-- Description: GetRVSRQ: calculates the Rate of Quality for RVS
-- Parameters:
-- @OKParts, int - Number of OK parts
-- @NOKParts, int - Number of NOK parts
--...
-- Returns: float, Value of RQ as % (0-100)
-- =============================================

create or alter function GetRVSRQ
	(@OKParts int
    ,@NOKParts int
    )
returns float
begin
--Check input variables for null values
    set 
        @OKParts = isnull(@OKParts,0);
    set 
        @NOKParts = isnull(@NOKParts,0);
        


--DECLARATIONS
	declare @rqresult float = 0.0;


--do calculation, if denominator is zero value is set to 0
	if (@OKParts+@NOKParts > 0)
		set 
            @rqresult = convert(float,@OKParts)/(convert(float,@OKParts)+convert(float,@NOKParts))*100;

--return rounded value	
	return 
        round(@rqresult,2);
end;
go