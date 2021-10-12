create or replace package XXOM_CREDIT_HOLD_UTIL_PKG is

--------------------------------------------------------------------
--  name:            XXOM_CREDIT_HOLD_UTIL_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   07/07/2015 15:16:56
--------------------------------------------------------------------
--  purpose :        CHG0035495 - Workflow for credit check Hold on SO
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  07/07/2015  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_approver
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      07/07/2015
  --  Purpose :           get approver name

  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   07/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  PROCEDURE get_approver(p_doc_instance_id in  number,
                         p_entity          in  varchar2,
                         x_approver        out varchar2,
                         x_err_code        out number,
                         x_err_msg         out varchar2);

  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_doc_instance_details
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      14/07/2015
  --  Purpose :           will use from FRW SalesOrder if parameter p_doc_instance_id
  --                      sent to the page, need to get the so header id and hold id
  --                      from the doc approval process, else it will work as today.
  --                      this info will help to determine if to show/hide some RN info
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   14/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  procedure get_doc_instance_details (p_doc_instance_id in  number,
                                      p_so_header_id    out varchar2,
                                      p_auto_hold_id    out varchar2,
                                      p_err_code        out varchar2,
                                      p_err_msg         out varchar2);
                                      
  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_customer_credit_limit
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      07/07/2015
  --  Purpose :
  --  In Parameters:
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   07/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  function get_customer_credit_limit (p_invoice_to_org_id in number) return number;
  
  function get_approver_by_region (p_limit  in number,
                                   p_region in varchar2,
                                   p_entity in varchar2,
                                   p_org_id in number) return varchar2;
                                   
  --------------------------------------------------------------------
  --  customization code: CHG0035495 - Workflow for credit check Hold on SO
  --  name:               get_org_region
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      08/07/2015
  --  Purpose :           get approver name
  --                      get the OU from the SO -> get from the legal entity
  --                      get the company -> connect to value set 'XXGL_COMPANY_SEG' ->
  --                      get the region
  ----------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   08/07/2015    Dalit A. Raviv    initial build
  -----------------------------------------------------------------------
  function get_org_region (p_org_id in number) return varchar2;                                                                         

end XXOM_CREDIT_HOLD_UTIL_PKG;
/
