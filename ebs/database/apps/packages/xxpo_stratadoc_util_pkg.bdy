create or replace package body xxpo_stratadoc_util_pkg is

  ----------------------------------------------------------------------------
  --  name:            xxpo_stratadoc_util_pkg
  --  create by:       Dan Melamed
  --  Revision:        1.0
  --  creation date:   20-Mar-2018
  ----------------------------------------------------------------------------
  --  purpose :         New Vendors interface from Oracle to  Stratadoc
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  20-Mar-2018  Dan Melamed                 CHG0042545 - initial build
  ----------------------------------------------------------------------------

  ----------------------------------------------------------------------------
  --  name:            insert_event
  --  create by:       Dan Melamed
  --  Revision:        1.0
  --  creation date:   20-Mar-2018
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write update indications to xxssys_events. 
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- ---- ----------- --------------- ------------------------------------------------------------
  --  1.0 20-Mar-2018 Dan Melamed     CHG0042545 - initial build
  --  1.1 26-03-2018  Roman.W         CHG0042545 - find tuning
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE insert_events(errbuf      OUT NOCOPY VARCHAR2,
                          retcode     OUT NOCOPY NUMBER,
                          p_days_back IN NUMBER) IS
  
    -------------------------------------
    --      Local Definitions
    -------------------------------------                           
    cursor interfacing_records_cur(c_last_run_date DATE) is
      select pv.vendor_id,
             pv.segment1 vendor_number,
             pv.vat_registration_num vat_number,
             pv.num_1099,
             pv.vendor_name,
             pv.vendor_name_alt vendor_alternate_name,
             pv.end_date_active,
             pv.attribute3 supplier_main_technology,
             pv.attribute4 supplier_technology_2,
             pv.attribute5 supplier_technology_3,
             pv.last_update_date,
             pvs.vendor_site_id,
             pvs.vendor_site_code,
             pvs.inactive_date,
             xxhz_util.get_operating_unit_name(pvs.org_id) operating_unit,
             pvs.last_update_date site_last_update_date
        from po_vendors pv, po_vendor_sites_all pvs
       where pv.vendor_id = pvs.vendor_id
         and nvl(pv.vendor_type_lookup_code, 'X') != 'EMPLOYEE'
         and pvs.org_id != 89 -- objet us
         and GREATEST(pv.last_update_date, pvs.last_update_date) >
             c_last_run_date;
  
    l_date_back        date;
    l_err_occured      number := 0;
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_last_run_date_vc DATE;
    l_last_run_date    varchar2(255);
    l_current_run_time date := sysdate;
    l_profile_saved    boolean;
    --------------------------------------
    --       Code Section
    --------------------------------------
  begin
    l_current_run_time := sysdate;
  
    l_last_run_date_vc := to_date(fnd_profile.VALUE('XXPOSTRATADOC_LAST_RUNING_DATE'),
                                  'DD-MON-YYYY HH24:MI:SS');
  
    if p_days_back is null then
      l_date_back := l_last_run_date_vc;
    elsif p_days_back is not null then
      l_date_back := sysdate - p_days_back;
    else
      retcode := 2;
      errbuf  := 'Invalid last run date set in profile - Exiting !';
      return;
    end if;
  
    for interface_rec in interfacing_records_cur(l_date_back) loop
    
      begin
      
        l_xxssys_event_rec := null;
      
        l_xxssys_event_rec.Entity_Id   := interface_Rec.Vendor_Site_Id;
        l_xxssys_event_rec.Entity_Name := 'VENDORSITE';
        l_xxssys_event_rec.Target_Name := 'STRATADOC';
        l_xxssys_event_rec.Event_Name  := 'xxpo_stratadoc_util_pkg.insert_events';
      
        xxssys_event_pkg.insert_event(p_xxssys_event_rec => l_xxssys_event_rec,
                                      p_db_trigger_mode  => 'N');
      
      exception
        when others then
          retcode := 1;
          errbuf  := 'Warning - Errors while inserting events into Interface()' ||
                     sqlerrm;
        
          fnd_file.put_line(fnd_file.LOG,
                            'Warning - Errors while inserting events into Interface ( ' ||
                            l_xxssys_event_rec.Entity_Id || ',' ||
                            l_xxssys_event_rec.Entity_Name || ',' ||
                            l_xxssys_event_rec.Target_Name || ',' ||
                            l_xxssys_event_rec.Event_Name || ')' || sqlerrm);
        
      end;
    END LOOP;
  
    l_profile_saved := fnd_profile.SAVE('XXPOSTRATADOC_LAST_RUNING_DATE',
                                        TO_CHAR(l_current_run_time,
                                                'DD-MON-YYYY HH24:MI:SS'),
                                        'SITE');
    commit;
  
  exception
    when others then
      retcode := 2;
      errbuf  := 'Error while inserting events into Interface' || sqlerrm;
  end insert_events;

end xxpo_stratadoc_util_pkg;
/
