create or replace package xxhr_populate_tc_pkg AUTHID CURRENT_USER is

--------------------------------------------------------------------
--  name:            XXHR_POPULATE_TC_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.1 
--  creation date:   14/06/2011 9:52:08 AM
--------------------------------------------------------------------
--  purpose :        MSS project - (Manager Self Service) 
--                   elements calculations
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  14/06/2011  Dalit A. Raviv    initial build
--  1.1  27/06/2013  Dalit A. Raviv    Handle HR packages and apps_view
--                                     add AUTHID CURRENT_USER to spec
--------------------------------------------------------------------  
  
  --------------------------------------------------------------------
  --  name:            get_person_tc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/06/2011
  --------------------------------------------------------------------
  --  purpose :        function that will calculate person Total Cash (TC)
  --  In params:       p_assignment_id
  --  Return:          Person Total Chash
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/06/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_person_tc (p_assignment_id in number) return number;
  
  --------------------------------------------------------------------
  --  name:            get_car_cost_tc_amount
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/06/2011
  --------------------------------------------------------------------
  --  purpose :        function that will check if person have element Car Cost
  --                   and Car Salary Waiver then return 0 , else need to add 3800 
  --                   to the salary.
  --                   If employee have only 'Car Cost IL' element return 3800 (from profile) 
  --                      need to add to the salary 3800 NIS
  --                   if employee have elements 'Car Cost IL' and 'Car Salary Waiver IL' return 0
  --                      no need to add to salary any NIS
  --                   if employee have elements 'Car Cost IL', 'Car Maintenance IL', 'Car Salary Waiver IL'
  --                      return 0 no need to add to salary any NIS
  --                   if employee have only 'Car Maintenance IL' return 1 and show the value of the element.
  --  In params:       p_assignment_id
  --  Return:          The amount need to add to the salary.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/06/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_car_cost_tc_amount (p_assignment_id in number,
                                   p_element_name  in varchar2) return varchar2;
                                   
                                   
  --------------------------------------------------------------------
  --  name:            get_Thirteen_Salary_amount
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   19/06/2011
  --------------------------------------------------------------------
  --  purpose :        function that will check if person have element Thirteen Salary AP = Y
  --                   Then need to return the salry / 12 for this element.
  --                   
  --  In params:       p_assignment_id
  --  Return:          The amount need to add to the salary.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/06/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_Thirteen_Salary_amount (p_assignment_id in number) return varchar2;                                   
                                   
  --------------------------------------------------------------------
  --  name:            get_on_target_amount
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   19/06/2011
  --------------------------------------------------------------------
  --  purpose :        function that will check if person have element On Target Bonus (AP, EU, Us)
  --                   Then need to return the amount / 12 for this element.
  --                   
  --  In params:       p_assignment_id
  --  Return:          The amount need to add to the salary.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/06/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_on_target_amount (p_assignment_id in number) return varchar2;
  
  function xxx(p_person_id in number) return varchar2;                                   

end XXHR_POPULATE_TC_PKG;

 
/
