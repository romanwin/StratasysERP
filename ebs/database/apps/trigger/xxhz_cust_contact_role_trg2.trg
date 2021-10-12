CREATE OR REPLACE TRIGGER xxhz_cust_contact_role_trg2
--------------------------------------------------------------------------------------------------
  --  name:              XXHZ_CUST_CONTACT_ROLE_TRG2
  --  create by:         Diptasurjya Chatterjee
  --  Revision:          1.0
  --  creation date:     05/15/2018
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0042626  : Validate duplicate email and eCom OU DFF
  --
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                 Desc
  --  1.0   05/15/2018    Diptasurjya          CHG0042626 - Initial build
  --  1.1   7/7/2020      yuval tal            CHG0048217 - b2b ecomm modify  : add event

  -- 1.2   18.5.21         yuval tal           CHG0049851 - disable hybris activities
  --------------------------------------------------------------------------------------------------
  FOR DELETE ON hz_role_responsibility
  COMPOUND TRIGGER

  TYPE t_change_tab IS TABLE OF hz_role_responsibility%ROWTYPE;
  g_change_tab t_change_tab := t_change_tab();

  AFTER EACH ROW IS
  BEGIN
  
    g_change_tab.extend;
    g_change_tab(g_change_tab.last).cust_account_role_id := :old.cust_account_role_id;
  
  END AFTER EACH ROW;

  AFTER STATEMENT IS
    l_status         VARCHAR2(1) := 'S';
    l_status_message VARCHAR2(4000);
  BEGIN
    --xxhz_ecomm_event_pkg.writelog('before statement');
    IF g_change_tab.count > 0 THEN
      FOR i IN g_change_tab.first .. g_change_tab.last
      LOOP
        --xxhz_ecomm_event_pkg.writelog('before statement in loop');
        --CHG0049851
        /* xxhz_ecomm_event_pkg.handle_contact_new(p_contact_id      => g_change_tab(i)
                             .cust_account_role_id,
        p_db_trigger_mode => 'Y');*/
      
        xxssys_strataforce_events_pkg.handle_contact(g_change_tab(i)
				     .cust_account_role_id,
				     'Y'); -- CHG0048217
      
        --xxhz_ecomm_event_pkg.writelog('after statement in loop');
        IF l_status <> 'S' THEN
          raise_application_error(-20001,
		          substr(l_status_message, 1, 4000));
        END IF;
      END LOOP;
    END IF;
    --xxhz_ecomm_event_pkg.writelog('after statement');
  END AFTER STATEMENT;
END xxhz_cust_contact_role_trg2;
/
