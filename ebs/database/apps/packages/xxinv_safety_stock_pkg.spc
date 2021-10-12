CREATE OR REPLACE PACKAGE xxinv_safety_stock_pkg IS

  --------------------------------------------------------------------
  --  name:            XXINV_SAFETY_STOCK_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   2/7/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        The customization will be used by the Service Planning department, at any
  --                   given time. The propose is to have a tool to update (Update existing, delete 
  --                   existing, add to the table) record of item and its safety stock.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/02/2009  Dalit A. Raviv    initial build
  --  1.1   15/8/2011  yuval tal          CR 303: add parameter to load_safety_stock_data + logic changed
  --------------------------------------------------------------------  

  -- Public function and procedure declarations
  --procedure upd_mtl_safety_stocks ();

  --procedure ins_mtl_safty_stocks ();

  /*PROCEDURE del_mtl_safety_stocks (p_organization_id  in  number,
  p_error_code       out number,
  p_error_desc       out varchar2);*/

  PROCEDURE load_safety_stock_data(errbuf                  OUT VARCHAR2,
                                   retcode                 OUT VARCHAR2,
                                   p_location              IN VARCHAR2,
                                   p_filename              IN VARCHAR2,
                                   p_organization_id       IN NUMBER,
                                   p_delete_exists_recodrs VARCHAR2);

END xxinv_safety_stock_pkg;
/
