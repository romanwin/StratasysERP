CREATE OR REPLACE PACKAGE xxqa_utils_pkg IS

--------------------------------------------------------------------
--  name:              XXQA_UTILS_PKG
--  create by:         RanS
--  Revision:          1.0
--  creation date:     xx/xx/xxxx
--------------------------------------------------------------------
--  purpose :          Utilities for QA module
--------------------------------------------------------------------
--  ver   date         name            desc
--  1.0   xx/xx/xxxx   RanS            Initial 
--  1.1   20/03/2013   yuval atl       CR 709 : ADD  get_rfr_responsibility_from_mf   the MF Responsibility count logic
--  1.2   02/05/2013   yuval tal       CR751 : Change the MF Responsibility count - MRB Decision :
--  1.3   25/11/2013   Vitaly          CT870 -- get_mf_cost added
--  1.4   22/10/2014   Dalit A. Raviv  CHG0032720 - Copy Inspection results by supplier LOT 
--                                     add 2 functions that will call by forms personalization
--                                     is_Insp_results_exists, get_Insp_results_per_lot 
--------------------------------------------------------------------
  
  FUNCTION get_mf_cost(p_mf_number VARCHAR2) RETURN NUMBER;

  FUNCTION is_plan_duplicate(p_mf_num VARCHAR2, p_plan_id NUMBER)
    RETURN VARCHAR2;

  FUNCTION is_plan_allowes_duplicate(p_plan_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_work_hours(p_date_from     IN DATE,
                          p_date_to       IN DATE,
                          p_hours_per_day IN NUMBER) RETURN NUMBER;

  PROCEDURE populate_mf_cost_tables(p_err_code    OUT NUMBER,
                                    p_err_message OUT VARCHAR2);

  FUNCTION get_rfr_responsibility_from_mf(p_wip_entity_id NUMBER)
    RETURN VARCHAR2;
    
  --------------------------------------------------------------------
  --  name:              is_Insp_results_exists
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     20/10/2014
  --------------------------------------------------------------------
  --  purpose :          CHG0032720 - Copy Inspection results by supplier LOT 
  --------------------------------------------------------------------
  --  ver   date         name              desc
  --  1.0   20/10/2014   Dalit A. Raviv    Initial 
  --------------------------------------------------------------------
  function is_Insp_results_exists (p_plan_id          in  number,
                                   p_organization_id  in  number,
                                   p_suplier_lot      in  varchar2,
                                   p_num_of_days      in  number) return varchar2;
                                      
  --------------------------------------------------------------------
  --  name:              get_Insp_results_per_lot
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     20/10/2014
  --------------------------------------------------------------------
  --  purpose :          CHG0032720 - Copy Inspection results by supplier LOT 
  --                     by the entity return different feild details.
  --------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   20/10/2014    Dalit A. Raviv    Initial 
  --------------------------------------------------------------------
  function get_Insp_results_per_lot (p_plan_id          in  number,
                                     p_organization_id  in  number,
                                     p_suplier_lot      in  varchar2,
                                     p_entity           in  varchar2,
                                     p_num_of_days      in  number) return varchar2;                              
                                            
END xxqa_utils_pkg;
/
