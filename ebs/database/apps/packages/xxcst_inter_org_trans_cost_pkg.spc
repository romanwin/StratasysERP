create or replace package XXCST_INTER_ORG_TRANS_COST_PKG is

--------------------------------------------------------------------
--  name:            XXCS_INTER_ORG_TRANSF_COST_PKG 
--  Cust:            CUST271- WRI WPI Inter-Org transfer Cost Elements update
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   14/02/2010 2:22:33 PM
--------------------------------------------------------------------
--  purpose :        The customization will be used for costing.
--                   All Resin FG are manufactured in WRI inventory organization 
--                   and upon completion moved to WPI inventory organization.
--                   The FG movement is done using “Direct Inter-Organization Transfer” transaction type. 
--                   While performing this transaction, the WRI Cost Elements are considered 
--                   as MATERIAL cost element in WPI. This causes incorrect costing element value, 
--                   when analyzing the resin inventory valuation and cogs. 
--                   This custom will correct WPI Element value for all material that is moved 
--                   between the organizations.
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  14/02/2009  Dalit A. Raviv    initial build
-------------------------------------------------------------------- 

  procedure main (errbuf                 out varchar2,
                  retcode                out varchar2,
                  p_from_organization_id in  number,
                  p_to_organization_id   in  number,
                  p_trx_date             in  varchar2,
                  p_gl_account           in  number,
                  p_start_date           in  varchar2) ;

end XXCST_INTER_ORG_TRANS_COST_PKG;
/

