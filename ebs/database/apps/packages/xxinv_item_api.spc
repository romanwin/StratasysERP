CREATE OR REPLACE PACKAGE xxinv_item_api IS

  -----------------------------------------------------
  --  name:            xxinv_item_api
  --  create by:
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21.3.11     yuval tal       initial build
  --  1.1  27.7.11     yuval tal       CR 287:add support for updating wip_supply_type and planner
  --  1.2  4.3.12      YUVAL TAL       CR 388 : add support for COST_OF_SALES_ACCOUNT_DSP  SALES_ACCOUNT_DSP
  --  1.3  5.2.13      yuval tal       CR 674 : Massive Item Update : add SP attributes Returnable null to HQ
  --  1.4  3.9.13      yuval tal       CR 1004 nodify update_batch : add  8 attributes
  --  1.5  07/10/2014  Dalit A. RAviv  CHG0033231 - add Inventory Org to itrem att25.
  --  1.6  16-FEB-2015 Gubendran K     CHG0034563 - Addded 5 Item Fields to Inventory Update item attributes report
  --  1.4  12/07/2015  Michal Tzvik    CHG0035537 - PROCEDURE update_batch: add fields list_price_per_unit ,shrinkage_rate
  --  1.5  30.4.17     yuval tal       CHG0040441 - update_batch Cut the PO- Mass update of sourcing buyer
  --  1.6  04-Jun-2018 Dan Melamed     CHG0043127 - Add external invoker for the seeded Import Items (INCOIN)
  --  1.7 14.12.20     yuval tal       CHG0049102 - modify get_ccid add default parameter

  --------------------------------------------------------------------
  /* FUNCTION get_item_id(p_seg VARCHAR2, p_organization_id NUMBER)
    RETURN NUMBER;
  FUNCTION get_organization_id(p_organization_code VARCHAR2) RETURN NUMBER;
  
  FUNCTION get_buyer_id(p_full_name VARCHAR2) RETURN NUMBER;*/

  PROCEDURE update_batch(errbuf      OUT VARCHAR2,
		 retcode     OUT VARCHAR2,
		 p_file_name VARCHAR2 DEFAULT 'ItemUpdate.csv');

  FUNCTION get_item_id(p_seg             VARCHAR2,
	           p_organization_id NUMBER) RETURN NUMBER;
  FUNCTION get_ccid(p_concat_seg VARCHAR2,
	        p_org_code   VARCHAR2 DEFAULT NULL) RETURN NUMBER;

  --------------------------------------------------------------------
  --  name:            import_items
  --  create by:       Dan Melamed
  --  Revision:        1.0
  --  ccreation date:  04-Jun-2018 12:01:00 PM
  --------------------------------------------------------------------
  --  purpose :        Invoke/call point for the concurrent.
  --                   This procedure resets the NLS Language and invokes the seeded Import Items (INCOIN) Concurrent.
  --------------------------------------------------------------------
  --  ver     name              date         desc
  --  1.0     Dan Melamed       03-Jun-2018  Initial version : CHG0043127
  --------------------------------------------------------------------
  PROCEDURE import_items(errbuf          OUT NOCOPY VARCHAR2,
		 retcode         OUT NOCOPY NUMBER,
		 p_org_id        VARCHAR2 DEFAULT NULL,
		 p_all_org       VARCHAR2 DEFAULT NULL,
		 p_val_item_flag VARCHAR2 DEFAULT NULL,
		 p_pro_item_flag VARCHAR2 DEFAULT NULL,
		 p_del_rec_flag  VARCHAR2 DEFAULT NULL,
		 p_xset_id       VARCHAR2 DEFAULT NULL,
		 p_run_mode      VARCHAR2 DEFAULT NULL,
		 p_gather_stats  VARCHAR2 DEFAULT NULL,
		 p_language      VARCHAR2 DEFAULT NULL);
END;
/
