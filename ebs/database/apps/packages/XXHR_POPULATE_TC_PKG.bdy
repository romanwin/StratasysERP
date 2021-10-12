create or replace package body XXHR_POPULATE_TC_PKG is

--------------------------------------------------------------------
--  name:            XXHR_POPULATE_TC_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   14/06/2011 9:52:08 AM
--------------------------------------------------------------------
--  purpose :        MSS project - (Manager Self Service) 
--                   elements calculations
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  14/06/2011  Dalit A. Raviv    initial build
--------------------------------------------------------------------  
  
  --------------------------------------------------------------------
  --  name:            get_person_tc
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   14/06/2011
  --------------------------------------------------------------------
  --  purpose :        function that will calculate person Total Cash (TC)
  --                   255  Hezi        -> Basic Salary No Car
  --                   232  Vadim       -> Basic Salary + car Lising
  --                   2262 Ofer        -> Global + Car Cost
  --                   239  Carmit      -> Global + return car (Car Maintenance)
  --                   2281 Susan       -> Global + car Lising (Car Cost + Car Salary weiver)
  --                   2681 Yoav        -> Global + Car lising + insurance fee (Car Cost + Car Salary weiver + Car Maintenance)
  --                   881  Dalit       -> Global no car
  --                   2401 Kerry  (AP) -> Global HKD + 13Sal
  --                   1321 Anne   (AP) -> Global USD - 13Sal
  --                   176  Sharon (US) -> Global 
  --                   238  Renate (AP) -> Global 
  --  In params:       p_assignment_id
  --  Return:          Person Total Cash
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/06/2011  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  function get_person_tc (p_assignment_id in number) return number is
    cursor get_person_ele_c (p_assignment_id in number) is
      select ee.effective_start_date       date_from,
             decode(ee.effective_end_date,
                    to_date('31/12/4712', 'dd/mm/yyyy'),
                    to_date(null, 'dd/mm/yyyy'),
                    ee.effective_end_date) date_to,
             ettl.element_name,
                 
             decode (ivtl.name,'Eligibility','Pay Value', ivtl.name) name,
             --screen_entry_value            amount,
             case when ettl.element_name = 'Car Cost IL' then
                    XXHR_POPULATE_TC_PKG.get_car_cost_tc_amount (ee.assignment_id,'Car Cost IL') 
                  when ettl.element_name = 'Car Maintenance IL' then
                    XXHR_POPULATE_TC_PKG.get_car_cost_tc_amount (ee.assignment_id,'Car Maintenance IL') 
                  when ettl.element_name = 'Thirteen Salary AP' then
                    XXHR_POPULATE_TC_PKG.get_Thirteen_Salary_amount (ee.assignment_id)
                  when ettl.element_name like 'On Target Bonus%' then
                    XXHR_POPULATE_TC_PKG.get_on_target_amount (ee.assignment_id)
                  else screen_entry_value
             end amount,
             hl1.meaning                   uom,
             hl2.meaning                   frequency,
             decode (ettl.element_name ,'Thirteen Salary AP',null,  et.input_currency_code)        Currency,
             ee.assignment_id,
             et.attribute4,
             nvl(et.attribute5,'N')        TC_Show_Not_Calc
      from   pay_element_entries_f         ee,
             pay_element_links_f           el,
             pay_element_types_f           et,
             pay_input_values_f            iv,
             pay_element_entry_values_f    eev,
             pay_element_types_f_tl        ettl,
             pay_input_values_f_tl         ivtl,
             pay_element_classifications   ec,
             hr_leg_lookups                hl1,
             hr_leg_lookups                hl2
      where  ee.element_link_id            = el.element_link_id
      and    et.element_type_id            = el.element_type_id
      and    et.classification_id          = ec.classification_id
      and    et.element_type_id            = ettl.element_type_id
      and    ettl.language                 = 'US'
      and    iv.element_type_id            = el.element_type_id
      and    iv.input_value_id             = ivtl.input_value_id
      and    ivtl.language                 = userenv('LANG')
      and    iv.input_value_id             = eev.input_value_id
      and    ee.element_entry_id           = eev.element_entry_id
      and    hl1.lookup_code               = iv.uom
      and    hl1.lookup_type               = 'UNITS'
      and    hl1.enabled_flag              = 'Y'
      and    hl2.lookup_code               = et.processing_type
      and    hl2.lookup_type               = 'PROCESSING_TYPE'
      and    hl2.enabled_flag              = 'Y'
      --and    ee.effective_start_date       <= trunc(sysdate)
      and    trunc(sysdate)                between ee.effective_start_date and ee.effective_end_date
      and    ee.effective_start_date       between el.effective_start_date and el.effective_end_date
      and    ee.effective_start_date       between et.effective_start_date and et.effective_end_date
      and    ee.effective_start_date       between iv.effective_start_date and iv.effective_end_date
      and    ee.effective_start_date       between eev.effective_start_date and eev.effective_end_date
      and    screen_entry_value            is not null
      and    decode(ee.effective_end_date,
                    to_date('31/12/4712', 'dd/mm/yyyy'),
                    to_date(null, 'dd/mm/yyyy'),
                    ee.effective_end_date) is null
      and    nvl(et.attribute4,'N')        = 'Y'
      and    iv.uom                        = case when ettl.element_name = 'Thirteen Salary AP' then
                                                    ('C') 
                                                  when ettl.element_name = 'Corporate MBO' then
                                                    ('N')
                                                  else
                                                    ('M')
                                             end
      and    ee.assignment_id = p_assignment_id; --in( 255, 232, 2262, 239, 2281, 2681, 881, 2401, 1321, 176, 238);

    l_tc number := 0;
  begin
  
    for get_person_ele_r in get_person_ele_c (p_assignment_id) loop
      if /*get_person_ele_r.element_name in ('Bonus US', 'Bonus IL', 'Bonus EU') or get_person_ele_r.element_name = 'Corporate MBO'*/ 
         get_person_ele_r.TC_Show_Not_Calc = 'Y' then
        l_tc := l_tc;
      else
        l_tc := l_tc + get_person_ele_r.amount;
      end if;
    end loop;
    return l_tc;
  exception
    when others then 
      return null;
  end;
  
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
                                   p_element_name  in varchar2) return varchar2 is
  
    cursor get_car_elements_c (p_assignment_id in number) is
      select ettl.element_name,
             screen_entry_value            amount,
             ee.assignment_id
      from   pay_element_entries_f         ee,
             pay_element_links_f           el,
             pay_element_types_f           et,
             pay_input_values_f            iv,
             pay_element_entry_values_f    eev,
             pay_element_types_f_tl        ettl,
             pay_input_values_f_tl         ivtl,
             pay_element_classifications   ec,
             hr_leg_lookups                hl1
      where  ee.element_link_id            = el.element_link_id
      and    et.element_type_id            = el.element_type_id
      and    et.classification_id          = ec.classification_id
      and    et.element_type_id            = ettl.element_type_id
      and    ettl.language                 = 'US'
      and    iv.element_type_id            = el.element_type_id
      and    iv.uom                        in ('M', 'N', 'C')
      and    iv.input_value_id             = ivtl.input_value_id
      and    ivtl.language                 = userenv('LANG')
      and    iv.input_value_id             = eev.input_value_id
      and    ee.element_entry_id           = eev.element_entry_id
      and    hl1.lookup_code               = iv.uom
      and    hl1.lookup_type               = 'UNITS'
      and    hl1.enabled_flag              = 'Y'
      and    ee.effective_start_date       <= trunc(sysdate)
      and    ee.effective_start_date       between el.effective_start_date and el.effective_end_date
      and    ee.effective_start_date       between et.effective_start_date and et.effective_end_date
      and    ee.effective_start_date       between iv.effective_start_date and iv.effective_end_date
      and    ee.effective_start_date       between eev.effective_start_date and eev.effective_end_date
      and    screen_entry_value            is not null
      and    decode(ee.effective_end_date,
                    to_date('31/12/4712', 'dd/mm/yyyy'),
                    to_date(null, 'dd/mm/yyyy'),
                    ee.effective_end_date) is null
      and    ee.assignment_id              = p_assignment_id  --in (171,306,2262,2281,2681,204,239)
      and    ettl.element_name             in ('Car Cost IL', 'Car Maintenance IL', 'Car Salary Waiver IL');
       
      l_car_cost          varchar2(5) := 'N';
      l_car_maintenance   varchar2(5) := 'N';
      l_car_salary_waiver varchar2(5) := 'N';
      l_amount            varchar2(2400) := null;  
    
  begin
    -- check Car cost
    if p_element_name = 'Car Cost IL' then
      for get_car_elements_r in get_car_elements_c (p_assignment_id) loop
        if get_car_elements_r.element_name = 'Car Cost IL' then
          l_car_cost := 'Y';
        elsif get_car_elements_r.element_name = 'Car Salary Waiver IL' then
          l_car_salary_waiver := 'Y';
        end if;
      end loop;
      
      if l_car_cost = 'Y' and l_car_salary_waiver = 'N' Then
        return nvl(fnd_profile.VALUE('XXHR_ELE_CAR_COST_WORTH'),3800);
      else
        return 0;
      end if;
    end if; -- Car Cost IL
    
    -- Ceck Car Maintenance 
    if p_element_name = 'Car Maintenance IL' then
      for get_car_elements_r in get_car_elements_c (p_assignment_id) loop
        if get_car_elements_r.element_name = 'Car Cost IL' then
          l_car_cost := 'Y';
        elsif get_car_elements_r.element_name = 'Car Salary Waiver IL' then
          l_car_salary_waiver := 'Y';
        elsif get_car_elements_r.element_name = 'Car Maintenance IL' then
          l_car_maintenance := 'Y';
          l_amount          := get_car_elements_r.amount;
        end if;
      end loop;
      
      if (l_car_cost = 'Y' and l_car_salary_waiver = 'Y' and l_car_maintenance = 'Y') or 
         (l_car_cost = 'Y' and l_car_salary_waiver = 'Y' and l_car_maintenance = 'N') Then
        return 0;
      else
        return l_amount;
      end if;
    end if; -- Car Maintenance IL
    
    return 0;
  exception
    when others then 
      return 0;
  end get_car_cost_tc_amount;
  
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
  function get_Thirteen_Salary_amount (p_assignment_id in number) return varchar2 is
  
    cursor get_13Sal_elements_c (p_assignment_id in number) is
      select ettl.element_name,
             screen_entry_value            amount,
             ee.assignment_id
      from   pay_element_entries_f         ee,
             pay_element_links_f           el,
             pay_element_types_f           et,
             pay_input_values_f            iv,
             pay_element_entry_values_f    eev,
             pay_element_types_f_tl        ettl,
             pay_input_values_f_tl         ivtl,
             pay_element_classifications   ec,
             hr_leg_lookups                hl1
      where  ee.element_link_id            = el.element_link_id
      and    et.element_type_id            = el.element_type_id
      and    et.classification_id          = ec.classification_id
      and    et.element_type_id            = ettl.element_type_id
      and    ettl.language                 = 'US'
      and    iv.element_type_id            = el.element_type_id
      and    iv.uom                        in ('M', 'N', 'C')
      and    iv.input_value_id             = ivtl.input_value_id
      and    ivtl.language                 = userenv('LANG')
      and    iv.input_value_id             = eev.input_value_id
      and    ee.element_entry_id           = eev.element_entry_id
      and    hl1.lookup_code               = iv.uom
      and    hl1.lookup_type               = 'UNITS'
      and    hl1.enabled_flag              = 'Y'
      and    ee.effective_start_date       <= trunc(sysdate)
      and    ee.effective_start_date       between el.effective_start_date and el.effective_end_date
      and    ee.effective_start_date       between et.effective_start_date and et.effective_end_date
      and    ee.effective_start_date       between iv.effective_start_date and iv.effective_end_date
      and    ee.effective_start_date       between eev.effective_start_date and eev.effective_end_date
      and    screen_entry_value            is not null
      and    decode(ee.effective_end_date,
                    to_date('31/12/4712', 'dd/mm/yyyy'),
                    to_date(null, 'dd/mm/yyyy'),
                    ee.effective_end_date) is null
      and    ee.assignment_id              = p_assignment_id  --in (2401)
      and    (ettl.element_name            = ('Thirteen Salary AP')
             or ettl.element_name          like 'Monthly Salary AP%' );
  
    l_13sal  varchar2(10)  := 'N';
    l_amount varchar2(100) := null;
  begin
    for get_13Sal_elements_r in get_13Sal_elements_c(p_assignment_id) loop
      if get_13Sal_elements_r.Element_Name = 'Thirteen Salary AP' then
        l_13sal := get_13Sal_elements_r.Amount;
      else
        l_amount := get_13Sal_elements_r.Amount;
      end if;
    end loop;
   
    if l_13sal = 'Y' then
      return l_amount/12;
    else
      return 0;
    end if;
  exception
    when others then 
      return 0;  
  end get_Thirteen_Salary_amount;
  
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
  function get_on_target_amount (p_assignment_id in number) return varchar2 is
  
    cursor get_on_target_bonus_c (p_assignment_id in number) is
      select ettl.element_name,
             screen_entry_value            amount,
             ee.assignment_id
      from   pay_element_entries_f         ee,
             pay_element_links_f           el,
             pay_element_types_f           et,
             pay_input_values_f            iv,
             pay_element_entry_values_f    eev,
             pay_element_types_f_tl        ettl,
             pay_input_values_f_tl         ivtl,
             pay_element_classifications   ec,
             hr_leg_lookups                hl1
      where  ee.element_link_id            = el.element_link_id
      and    et.element_type_id            = el.element_type_id
      and    et.classification_id          = ec.classification_id
      and    et.element_type_id            = ettl.element_type_id
      and    ettl.language                 = 'US'
      and    iv.element_type_id            = el.element_type_id
      and    iv.uom                        in ('M', 'N', 'C')
      and    iv.input_value_id             = ivtl.input_value_id
      and    ivtl.language                 = userenv('LANG')
      and    iv.input_value_id             = eev.input_value_id
      and    ee.element_entry_id           = eev.element_entry_id
      and    hl1.lookup_code               = iv.uom
      and    hl1.lookup_type               = 'UNITS'
      and    hl1.enabled_flag              = 'Y'
      and    ee.effective_start_date       <= trunc(sysdate)
      and    ee.effective_start_date       between el.effective_start_date and el.effective_end_date
      and    ee.effective_start_date       between et.effective_start_date and et.effective_end_date
      and    ee.effective_start_date       between iv.effective_start_date and iv.effective_end_date
      and    ee.effective_start_date       between eev.effective_start_date and eev.effective_end_date
      and    screen_entry_value            is not null
      and    decode(ee.effective_end_date,
                    to_date('31/12/4712', 'dd/mm/yyyy'),
                    to_date(null, 'dd/mm/yyyy'),
                    ee.effective_end_date) is null
      and    ee.assignment_id              = p_assignment_id  --in (2401)
      and    ettl.element_name             like 'On Target Bonus%' ;
  
    l_amount varchar2(100) := null;
  begin
    for get_on_target_bonus_r in get_on_target_bonus_c(p_assignment_id) loop
      l_amount := get_on_target_bonus_r.Amount;
    end loop;
   
    return trunc(l_amount/12,1);
    
  exception
    when others then 
      return 0;  
  end get_on_target_amount;
  
  ------------------------------------------------
  function xxx(p_person_id in number ) return varchar2 is
  
  begin
    return p_person_id||' ,' ||'Dalit' ;
  end;
  
end XXHR_POPULATE_TC_PKG;
/
