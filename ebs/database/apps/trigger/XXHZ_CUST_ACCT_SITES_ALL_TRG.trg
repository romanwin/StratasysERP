create or replace trigger XXHZ_CUST_ACCT_SITES_ALL_TRG
  before INSERT or UPDATE of ATTRIBUTE4, STATUS on HZ_CUST_ACCT_SITES_ALL
  for each row
declare
  -- local variables here
  l_cust_account_id        NUMBER;
  l_cust_acct_site_id      NUMBER;
  l_new_sf_account_address VARCHAR2(10); -- Y/N
  l_old_sf_account_address VARCHAR2(10); -- Y/N
  l_new_status             VARCHAR2(10);
  l_old_status             VARCHAR2(10);
  l_error_code             VARCHAR2(10);
  l_error_desc             VARCHAR2(2000);
  result                   BOOLEAN;
  l_exception              VARCHAR2(10000);
  MY_EXCEPTION EXCEPTION;
  l_action VARCHAR2(300);
begin
  ------------------------------------------------------------------------------------------------------------------
  -- Ver   When         Who            Descr
  -- ----  -----------  -------------  -----------------------------------------------------------------------------
  -- 1.0   01/05/2020   Roman W.       CHG0047450 - Account, Contact interface - ReDo
  -- 1.1   26/11/2020   Roman W.       CHG0047450 - Account, Contact interface - ReDo
  -- 1.2                                      added setting default value 'Y' in case this is first site to account
  --                                          Added call to parametr "p_created_by_module" 
  --                                          in xxssys_strataforce_events2_pkg.acct_site_insert_trg
  ------------------------------------------------------------------------------------------------------------------
  l_error_code := '0';
  l_error_desc := null;

  l_old_sf_account_address := nvl(:OLD.ATTRIBUTE4, 'N');
  l_new_sf_account_address := nvl(:NEW.ATTRIBUTE4, 'N');
  l_cust_account_id        := nvl(:new.cust_account_id,
                                  :old.cust_account_id);
  l_cust_acct_site_id      := nvl(:new.cust_acct_site_id,
                                  :old.cust_acct_site_id);
  l_new_status             := :new.STATUS;
  l_old_status             := :old.STATUS;

  case
    when INSERTING then
      l_action := '(INSERTING)';
      ------------------------------------------------------------------------
      --                     I N S E R T I N G
      ------------------------------------------------------------------------
      xxssys_strataforce_events2_pkg.acct_site_insert_trg(p_created_by_module      => :new.created_by_module,
                                                          p_cust_account_id        => l_cust_account_id,
                                                          p_cust_acct_site_id      => l_cust_acct_site_id,
                                                          p_status                 => l_new_status,
                                                          p_new_sf_account_address => l_new_sf_account_address,
                                                          p_error_code             => l_error_code,
                                                          p_error_desc             => l_error_desc);
      if 0 != l_error_code then
        l_exception := 'ERROR_XXHZ_CUST_ACCT_SITES_ALL_TRG_INSERTING : ' ||
                       l_error_desc;
        raise MY_EXCEPTION;
      else
        :NEW.ATTRIBUTE4 := l_new_sf_account_address; -- 1.2
      end if;
    when UPDATING then
      l_action := '(UPDATING)';
      ------------------------------------------------------------------------
      --                     U P D A T I N G ('ATTRIBUTE4')
      ------------------------------------------------------------------------
      if fnd_global.CONC_REQUEST_ID = -1 then
      
        result := fnd_request.set_mode(TRUE);
      
        if l_old_status != l_new_status or
           l_old_sf_account_address != l_new_sf_account_address then
        
          xxssys_strataforce_events2_pkg.acct_site_updpdate_trg(p_cust_account_id        => l_cust_account_id,
                                                                p_cust_acct_site_id      => l_cust_acct_site_id,
                                                                p_old_status             => l_old_status,
                                                                p_new_status             => l_new_status,
                                                                p_old_sf_account_address => l_old_sf_account_address,
                                                                p_new_sf_account_address => l_new_sf_account_address,
                                                                p_error_code             => l_error_code,
                                                                p_error_desc             => l_error_desc);
        
          if 0 != l_error_code then
            l_exception := l_error_desc;
            raise MY_EXCEPTION;
            /*
            l_exception := 'UPDATING(''STATUS'')_XXHZ_CUST_ACCT_SITES_ALL_TRG: ' ||
                           chr(10) || 'l_old_status=> ' || l_old_status ||
                           chr(10) || 'l_new_status=> ' || l_new_status ||
                           chr(10) || 'l_old_sf_account_address=> ' ||
                           l_old_sf_account_address || chr(10) ||
                           'l_new_sf_account_address=> ' ||
                           l_new_sf_account_address || chr(10) ||
                           l_error_desc;
            raise MY_EXCEPTION;
            */
          end if;
        
        end if;
      end if;
  end case;

exception
  when MY_EXCEPTION then
    RAISE_APPLICATION_ERROR(-20001,
                            'MY_EXCEPTION' || l_action || ' : ' ||
                            l_exception);
  when others then
    RAISE_APPLICATION_ERROR(-20001,
                            'EXCEPTION_OTHERS ' || l_action ||
                            ' Trigger  : XXHZ_CUST_ACCT_SITES_ALL_TRG : ' ||
                            sqlerrm);
end XXHZ_CUST_ACCT_SITES_ALL_TRG;
/
