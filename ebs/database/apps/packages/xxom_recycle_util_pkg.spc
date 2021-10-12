create or replace package xxom_recycle_util_pkg authid current_user as
  ----------------------------------------------------------------------------
  --  name:            xxom_recycle_util_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   08/07/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0035852 - Recycling application utilities container package
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  08/07/2015  Diptasurjya Chatterjee(TCS)  CHG0035852 - initial build
  ----------------------------------------------------------------------------
  
  function partion_table_by_region(obj_schema VARCHAR2,
		                               obj_name   VARCHAR2) return varchar2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035852 - Insert record into recycle request table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  08/07/2015  Diptasurjya Chatterjee (TCS)    CHG0035852 - Initial Build
  -- --------------------------------------------------------------------------------------------

  procedure insert_recycle_request (p_recycle_request    IN xxobjt.xx_om_recyclereq_tab,
                                    x_status             OUT varchar2,
                                    x_status_message     OUT varchar2);

end xxom_recycle_util_pkg;
/
