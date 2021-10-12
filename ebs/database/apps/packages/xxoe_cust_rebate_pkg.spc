create or replace package XXOE_Cust_Rebate_Pkg is

  -- Author  : AVIH
  -- Created : 20/08/2009 10:23:08
  -- Purpose : Handle Customer Rebate
  
Procedure calc_rebate (errbuf               Out Varchar2,
                       Retcode              Out Varchar2,
                       P_OrgID              In  number,
                       P_CustomerID         In  number,
                       P_FromDate           In  varchar2,
                       P_ToDate             In  varchar2,
                       P_CategSegment1      In  varchar2
                      );

end XXOE_Cust_Rebate_Pkg;
/

