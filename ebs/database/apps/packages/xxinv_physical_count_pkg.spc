CREATE OR REPLACE PACKAGE xxinv_physical_count_pkg IS

  --------------------------------------------------------------------
  --  name:            XXINV_PHYSICAL_COUNT_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/05/2010 3:29:44 PM
  --------------------------------------------------------------------
  --  purpose :        CUST325 - Upload program to the physical counts from excel to the system
  --                   Get excel that will hold all neccessary fields and update 
  --                   mtl_physical_inventory_tags table with the physical count quantity
  --                   and update of mtl_physical_adjustments tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/05/2010  Dalit A. Raviv    initial build
  --  1.1  29/06/2010  Dalit A. Raviv    add function upd_physical_adj_qty
  --                                     do update to mtl_physical_adjustments tbl
  --------------------------------------------------------------------  

  --------------------------------------------------------------------
  --  name:            load_physical_count_qty
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/05/2010 3:29:44 PM
  --------------------------------------------------------------------
  --  purpose :        Load physical count qty data from excel file to 
  --                   mtl_physical_inventory_tags table (update qty)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/05/2010  Dalit A. Raviv    initial build
  --  1.1  7.12.10     yuval tal         add  p_revision     to upd_physical_adj_qty       
  --------------------------------------------------------------------
  PROCEDURE load_physical_count_qty(errbuf           OUT VARCHAR2,
                                    retcode          OUT VARCHAR2,
                                    p_location       IN VARCHAR2,
                                    p_filename       IN VARCHAR2,
                                    p_overwrite_data IN VARCHAR2);

END xxinv_physical_count_pkg;
/

