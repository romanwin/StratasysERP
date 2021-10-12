CREATE OR REPLACE TRIGGER xxmtl_system_items_aiur_trg2
  -- *****************************************************************************************
  -- Object Name:  XXMTL_SYSTEM_ITEMS_AIUR_TRG2
  -- Type       :   Trigger
  -- Create By  :   Yuval tal
  -- Creation Date: 24-Apr-2019
  -- Purpose    :  Submit concurrent "XXINVWFITEM", if Item Status Code Inserted/Changed
  --
  --  *****************************************************************************************
  --  Ver    Date         Name              Change Desc
  --  -----  ------       --------          --------------------------------------------------
  --  1.0    24-Apr-2019  Yuval Tal         CHG0045539 - Item WF Approval - Initial Build
  --
  -- *****************************************************************************************
  AFTER INSERT OR UPDATE OF  inventory_item_status_code ON  "INV"."MTL_SYSTEM_ITEMS_B"
  FOR EACH ROW

DECLARE
  l_error_message VARCHAR2(2000);
  l_mode VARCHAR2(10) := (CASE
           WHEN inserting THEN
            'INSERT'
           ELSE
            'UPDATE'
         END);
  l_new_itm_sts    Varchar2(30) := :new.inventory_item_status_code;
  l_old_itm_sts   Varchar2(30) := :old.inventory_item_status_code;
BEGIN
   If :new.organization_id != 91 Then
      return;
   End If;
   
   If INSERTING or 
    (UPDATING and  l_new_itm_sts != l_old_itm_sts)
   Then
     -- Call Submit Request XXINV Item Workflow / XXINVWFITEM
     xxinv_wf_item_approval_pkg.submit_request(p_inv_item_id => :new.inventory_item_id,
                                               p_mode        => l_mode,
                                               p_old_status  => l_old_itm_sts,
                                               p_new_status  => l_new_itm_sts);
   END IF;

EXCEPTION
  WHEN OTHERS THEN
    l_error_message := substrb(SQLERRM, 1, 1000);
    raise_application_error(-20999, l_error_message);
END xxmtl_system_items_aiur_trg2;
/