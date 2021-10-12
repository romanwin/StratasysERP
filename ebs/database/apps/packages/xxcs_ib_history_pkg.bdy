create or replace package body xxcs_ib_history_pkg is

--------------------------------------------------------------------
--  name:            XXCS_IB_HISTORY
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   07/05/2012 09:27:10
--------------------------------------------------------------------
--  purpose :        REP266 - MTXX Reports - Disco report
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  07/05/2012  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  g_user_id  number:= null; -- 1111 scheduler
  g_run_date date;
  --------------------------------------------------------------------
  --  name:            main_history
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   1) check if there is old record if yes need to update end date.
  --                   2) insert new row
  --                   3) update party details, item details and IB active_end_date
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/05/2012  Dalit A. Raviv    initial build
  --  1.1  13/06/2012  Dalit A. Raviv    add change not to see rows that the change of party was
  --                                     from type Sales Oredr Internal Issue
  --------------------------------------------------------------------
  procedure main_history ( errbuf   out varchar2,
                           retcode  out number,
                           p_date   in  varchar2) is


    cursor IB_pop_c is
      -- population of all printers at Install base
      SELECT cii.instance_id
      FROM   csi_item_instances    cii,
             xxcs_items_printers_v prt
      where  cii.inventory_item_id = prt.inventory_item_id;
      --and    cii.instance_id       in ( 462005,3891011,111059);

    -- history population per Instance per day
    cursor IB_Hist_c (p_date        in date,
                      p_instance_id in number) is
      -- item
      select --'ITEM' source,
             ih.instance_id,
             XXCS_IB_HISTORY_PKG.get_last_party_per_date (ih.instance_id,ih.creation_date) party_id,
             ih.new_inventory_item_id,
             -- 27-Aug-2009 date coversion from old system to Oracle Appl
             decode(trunc(ih.creation_date),to_date ('27-AUG-2009','DD-MON-YYYY'),
                                            ih.new_active_start_date,ih.creation_date) from_date,
             to_date(null) to_date
      from   csi_item_instances_h      ih,
             xxcs_items_printers_v     prt -- only for printers

      where  ih.new_inventory_item_id    is not null
      and    nvl(ih.old_inventory_item_id, 0)  <> ih.new_inventory_item_id
      and    ih.new_inventory_item_id    = prt.inventory_item_id
      and    ih.instance_id              = p_instance_id --462005
      and    trunc(ih.creation_date)     <= p_date --to_date('22/07/2010','dd/mm/yyyy')
      and    trunc(ih.creation_date)     < trunc(sysdate) -- do not run on today data
      and    ih.creation_date            = (select max(ih2.creation_date)
                                            from   csi_item_instances_h      ih2
                                            where  ih2.instance_id           = p_instance_id
                                            and    trunc(ih2.creation_date)  = p_date
                                            and    nvl(ih2.old_inventory_item_id, 0)  <> ih2.new_inventory_item_id
                                            and    ih2.new_inventory_item_id is not null)
      union
      -- party
      select --'PARTY' source,
             cip.instance_id,
             ph.new_party_id party_id,
             XXCS_IB_HISTORY_PKG.get_last_item_per_date (cip.instance_id, ph.creation_date) new_inventory_item_id,
             -- 27-Aug-2009 date coversion from old system to Oracle Appl
             decode(trunc(ph.creation_date),to_date ('27-AUG-2009','DD-MON-YYYY'),
                                            ph.new_active_start_date,ph.creation_date) from_date,
             to_date(null) to_date
      from   csi_i_parties_h           ph,
             csi_i_parties             cip,
             hz_parties                hp,
             csi_inst_txn_details_v    cc -- 13/06/2012 Dalit A. Raviv
      where  ph.instance_party_id      = cip.instance_party_id
      and    ph.new_party_id           is not null
      and    nvl(ph.old_party_id,0)    != ph.new_party_id
      and    ph.new_party_id           = hp.party_id
      and    hp.party_type             = 'ORGANIZATION'
      -- 13/06/2012 Dalit A. Raviv
      and    cip.instance_id           = cc.instance_id
      and    ph.transaction_id         = cc.transaction_id
      and    cc.transaction_type_id    <> 126              -- ISO_ISSUE Internal Sales Order Issue
      -- 13/06/2012
      and    cip.instance_id           = p_instance_id
      and    trunc(ph.creation_date)   = p_date
      and    ph.creation_date          = (select max(ph2.creation_date)
                                          from   csi_i_parties_h          ph2,
                                                 csi_i_parties            cip2,
                                                 hz_parties               hp2
                                          where  cip2.instance_party_id   = ph2.instance_party_id
                                          and    ph2.new_party_id         is not null
                                          and    nvl(ph2.old_party_id,0)  != ph2.new_party_id
                                          and    ph2.new_party_id         = hp2.party_id
                                          and    hp2.party_type           = 'ORGANIZATION'
                                          and    cip2.instance_id         =  p_instance_id
                                          and    ph2.new_party_id         is not null
                                          and    trunc(ph2.creation_date) = p_date)
      and    trunc(ph.creation_date)   < trunc(sysdate);

      -- with the instance_id go to second cursor user transaction_id
      /*
      select instance_id,
             max(party_id) party_id,
             max(new_inventory_item_id) inventory_item_id ,
             from_date, to_date(null) to_date
      from (select -- 'ITEM' source,
                   ih.instance_id, cii_party.new_party_id party_id, ih.new_inventory_item_id,
                   -- 27-Aug-2009 date coversion from old system to Oracle Appl
                   decode(trunc(ih.creation_date),to_date ('27-AUG-2009','DD-MON-YYYY'),
                                                  ih.new_active_start_date,ih.creation_date) from_date
            from   csi_item_instances_h      ih,
                   xxcs_items_printers_v     prt, -- only for printers
                   (select cip.instance_id, ph.new_party_id , ph.creation_date
                    from   csi_i_parties_h           ph,
                           csi_i_parties             cip
                    where  ph.instance_party_id      = cip.instance_party_id
                    and    trunc(ph.creation_date)   <= p_date
                    and    ph.new_party_id           is not null
                    and    ph.new_party_source_table = 'HZ_PARTIES'
                    and    cip.instance_id           = p_instance_id --10018
                    and    ph.creation_date          = (select max(ph1.creation_date)
                                                        from   csi_i_parties_h            ph1,
                                                               csi_i_parties              cip1
                                                        where  ph1.instance_party_id      = cip1.instance_party_id
                                                        and    trunc(ph1.creation_date)   <= p_date
                                                        and    ph1.new_party_id           is not null
                                                        and    ph1.new_party_source_table = 'HZ_PARTIES'
                                                        and    cip1.instance_id           = cip.instance_id)

                    ) cii_party
            where  ih.new_inventory_item_id    is not null
            and    ih.new_inventory_item_id    = prt.inventory_item_id
            and    cii_party.instance_id (+)   = ih.instance_id
            and    ih.instance_id              = p_instance_id  --10977 --<p_instance_id>
            and    trunc(ih.creation_date)     = p_date         --27/08/2009
            and    trunc(ih.creation_date)     < trunc(sysdate) -- do not run on today data
            union
            select -- 'PARTY' source,
                   cip.instance_id, ph.new_party_id , cii_item.new_inventory_item_id new_inventory_item_id,
                   -- 27-Aug-2009 date coversion from old system to Oracle Appl
                   decode(trunc(ph.creation_date),to_date ('27-AUG-2009','DD-MON-YYYY'),
                                                  ph.new_active_start_date,ph.creation_date) from_date
            from   csi_i_parties_h           ph,
                   csi_i_parties             cip,
                   -- bring the item that was in this date for this party.
                   (select ih.new_inventory_item_id, ih.instance_id, max(ih.creation_date)
                    from   csi_item_instances_h      ih,
                           xxcs_items_printers_v     prt
                    where  trunc(ih.creation_date)   <= p_date
                    and    ih.instance_id            =  p_instance_id
                    and    new_inventory_item_id     is not null
                    and    ih.new_inventory_item_id  = prt.inventory_item_id
                    group by ih.new_inventory_item_id, ih.instance_id
                   ) cii_item
            where  ph.instance_party_id      = cip.instance_party_id
            and    ph.new_party_id           is not null
            and    ph.new_party_source_table = 'HZ_PARTIES'
            and    cii_item.instance_id (+)  = cip.instance_id
            and    cip.instance_id           = p_instance_id --10018 --10977 --<p_instance_id>
            and    trunc(ph.creation_date)   = p_date
            and    trunc(ph.creation_date)   < trunc(sysdate) -- do not run on today data
      ) a_view
      group by instance_id, from_date;
    */

    l_hist_rec t_hist_rec;
    l_err_code number;
    l_err_desc varchar2(2500);
    l_need_upd varchar2(10) := 'N';
    -- l_count    number    := 0;

    general_exception exception;
  begin
    errbuf := null;
    retcode := 0;

    if p_date is null then
      g_run_date := trunc(sysdate - 1);
    else
      -- 21-MAY-2012 10:17:05
      g_run_date := fnd_date.canonical_to_date(p_date); -- trunc(p_date);
    end if;

    select user_id
    into   g_user_id
    from   fnd_user fu
    where  fu.user_name = 'SCHEDULER';
    /*
    select count(1)
    into   l_count
    from   XXCS_IB_HISTORY hist
    where  trunc(hist.parameter_run_date) = trunc(p_date);

    if l_count <> 0 then
      retcode := 1;
      errbuf := 'Program allready runs for this date';
      fnd_file.put_line(fnd_file.log,'Program allready runs for this date');
      dbms_output.put_line('Program allready runs for this date');
      raise general_exception;
    end if;
    */
    for IB_pop_r in IB_pop_c loop

      l_need_upd := 'N';
      l_err_code := 0;
      l_err_desc := null;
      for IB_Hist_r in IB_Hist_c (trunc(g_run_date), IB_pop_r.Instance_Id) loop
        --l_hist_rec := IB_Hist_r;
        -- check if there is old record if yes need to update end date.
        begin
          select 'Y'
          into   l_need_upd
          from   XXCS_IB_HISTORY  hist
          where  hist.instance_id = IB_pop_r.Instance_Id
          and    hist.end_date    is null;
          -- IB_Hist_r.From_Date in all days it will be equivalent to p_date
          -- except to the first run of the 27-AUG-2009
          update_history(p_end_date    => IB_Hist_r.From_Date,  -- i d
                         p_instance_id => IB_pop_r.Instance_Id, -- i n
                         p_err_code    => l_err_code,           -- o n
                         p_err_desc    => l_err_desc);          -- o v
        exception
          when others then null;
        end;

        -- insert new row
        l_hist_rec := IB_Hist_r;
        l_err_code := 0;
        l_err_desc := null;
        insert_history(p_hist_rec   => l_hist_rec,  -- i t_hist_rec,
                       p_err_code   => l_err_code, -- o n
                       p_err_desc   => l_err_desc);-- o v
        if l_err_code <> 0 then
          fnd_file.put_line(fnd_file.log,'---------------- START -------------');
          fnd_file.put_line(fnd_file.log,'Date - '||to_char(g_run_date,'DD-MON-YYYY'));
          fnd_file.put_line(fnd_file.log,'Instance - '||IB_pop_r.Instance_Id);
          dbms_output.put_line('---------------- START -------------');
          dbms_output.put_line('Date - '||to_char(g_run_date,'DD-MON-YYYY'));
          dbms_output.put_line('Instance - '||IB_pop_r.Instance_Id);
        end if;
      end loop; -- IB_Hist_c
    end loop; -- IB_pop_c

    l_err_code := 0;
    l_err_desc := null;
    -- update party details, item details and IB active_end_date
    apd_additional_details (p_err_code  => l_err_code, -- o n
                            p_err_desc  => l_err_desc);-- o v

    -- Handle installed_date was changed in IB but the party or Item did not so we do not work
    -- on this row.
    l_err_code := 0;
    l_err_desc := null;
    upd_changes_install_date (p_err_code  => l_err_code, -- o n
                              p_err_desc  => l_err_desc);-- o v
    if l_err_code <> 0 then
      dbms_output.put_line('Update Installed date Failed'||l_err_desc);
      fnd_file.put_line(fnd_file.log,'Update Installed date Failed'||l_err_desc);
    end if;

  exception
    when general_exception then
      null;
    when others then
      retcode := 1;
      errbuf := 'GEN exception main_history - '||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'GEN exception main_history - '||substr(sqlerrm,1,240));
      dbms_output.put_line('GEN exception main_history - '||substr(sqlerrm,1,240));
  end main_history;
  --------------------------------------------------------------------
  --  name:            apd_additional_details
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   add party, item, and IB active_end_date details
  --                   to each row.
  --                   Process flag give indication that these are new rows to process on
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure apd_additional_details (p_err_code    out number,
                                    p_err_desc    out varchar2) is

  PRAGMA AUTONOMOUS_TRANSACTION;

    cursor hst_pop_c is
      select *
      from   XXCS_IB_HISTORY hist
      where  process_flag    = 'N';

    l_item            varchar2(40);
    l_item_desc       varchar2(360);
    l_item_type       varchar2(150);
    l_party_number    varchar2(30);
    l_party_name      varchar2(360);
    l_active_end_date date;
    l_install_date    date;
  begin
    p_err_code := 0;
    p_err_desc := null;
    for hst_pop_r in hst_pop_c loop
      l_item            := null;
      l_item_desc       := null;
      l_item_type       := null;
      l_party_number    := null;
      l_party_name      := null;
      l_active_end_date := null;
      l_install_date    := null;
      -- Get Party details
      begin
        select hp.party_number, hp.party_name
        into   l_party_number,
               l_party_name
        from   hz_parties  hp
        where  hp.party_id = hst_pop_r.party_id;
      exception
        when others then
          l_party_number := null;
          l_party_name   := null;
          fnd_file.put_line(fnd_file.log,'Party Details - Party Id - '||hst_pop_r.party_id||
                                         ' Instance id - '||hst_pop_r.instance_id||
                                         ' Hist Id - '||hst_pop_r.hist_id );
          dbms_output.put_line('Party Details - Party Id - '||hst_pop_r.party_id||
                               ' Instance id - '||hst_pop_r.instance_id||
                               ' Hist Id - '||hst_pop_r.hist_id);
      end;
      -- Get Item details
      begin
        select item.item, item.item_description, item.item_type
        into   l_item, l_item_desc, l_item_type
        from   xxcs_items_printers_v item
        where  item.inventory_item_id = hst_pop_r.inventory_item_id;

      exception
        when others then
          l_item         := null;
          l_item_desc    := null;
          l_item_type    := null;
          fnd_file.put_line(fnd_file.log,'Item Details - Item Id - '||hst_pop_r.inventory_item_id||
                                         ' Instance id - '||hst_pop_r.instance_id||
                                         ' Hist Id - '||hst_pop_r.hist_id );
          dbms_output.put_line('Item Details - Item Id - '||hst_pop_r.inventory_item_id||
                               ' Instance id - '||hst_pop_r.instance_id||
                               ' Hist Id - '||hst_pop_r.hist_id );
      end;
      -- Get If Instance is closed
      begin
        select cii.active_end_date
        into   l_active_end_date
        from   csi_item_instances cii
        where  cii.instance_id    = hst_pop_r.instance_id ;
      exception
        when others then
          l_active_end_date := null;
          fnd_file.put_line(fnd_file.log,'IB Details - '||
                                         ' Instance id - '||hst_pop_r.instance_id||
                                         ' Hist Id - '||hst_pop_r.hist_id );
          dbms_output.put_line('IB Details - '||
                               ' Instance id - '||hst_pop_r.instance_id||
                               ' Hist Id - '||hst_pop_r.hist_id );
      end;

      if nvl(fnd_profile.value('XXCS_HIST_INSTALL_DATE'),'N') = 'Y' then
        l_install_date := get_install_date (p_instance_id => hst_pop_r.instance_id, -- i n
                                            p_start_date  => hst_pop_r.start_date,  -- i d
                                            p_end_date    => hst_pop_r.end_date);   -- i d
      end if;

      begin
        update XXCS_IB_HISTORY hist
        set    hist.instance_active_end_date = l_active_end_date,
               hist.party_number             = l_party_number,
               hist.party_name               = l_party_name,
               hist.item                     = l_item,
               hist.item_desc                = l_item_desc,
               hist.item_type                = l_item_type,
               hist.install_date             = l_install_date,
               hist.process_flag             = 'Y'
        where  hist.hist_id                  = hst_pop_r.hist_id;
        commit;
      exception
        when others then
          fnd_file.put_line(fnd_file.log,'Update Failed'||
                                         ' Instance id - '||hst_pop_r.instance_id||
                                         ' Hist Id - '||hst_pop_r.hist_id );
          dbms_output.put_line('Update Failed'||
                               ' Instance id - '||hst_pop_r.instance_id||
                               ' Hist Id - '||hst_pop_r.hist_id);
          rollback;
      end;
    end loop;
  exception

    when others then
      p_err_code := 1;
      p_err_desc := 'GEN exception apd_additional_details - '||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'GEN exception apd_additional_details - '||substr(sqlerrm,1,240));
      dbms_output.put_line('GEN exception apd_additional_details - '||substr(sqlerrm,1,240));
  end apd_additional_details;

  ---------------------------------------
 /* procedure update_party_details (p_err_code    out number,
                                  p_err_desc    out varchar2) is
    cursor get_party_pop_c is
      select distinct hist.party_id
      from   XXCS_IB_HISTORY hist
      where  hist.party_number is null
      and    hist.party_name   is null;

    cursor get_party_details_c (p_party_id in number) is
      select hp.party_number, hp.party_name
      from   hz_parties  hp
      where  hp.party_id = p_party_id;
  begin
    for get_party_pop_r in get_party_pop_c loop
      for get_party_details_r in get_party_details_c(get_party_pop_r.party_id) loop
        begin
        update XXCS_IB_HISTORY   hist
        set    hist.party_number = get_party_details_r.party_number,
               hist.party_name   = get_party_details_r.party_name
        where  hist.party_id     = get_party_pop_r.party_id
        and    hist.party_number is null
        and    hist.party_name   is null;
        commit;
        exception
          when others then null;
        end;
      end loop;
    end loop;
  end;
 */
  --------------------------------------------------------------------
  --  name:            update_history
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   before insert new row the program look if this instance
  --                   have allready row at XXCS_IB_HISTORY table that have no end_date
  --                   in this case we need to close the last row (end_date is null)
  --                   with current row start date minus 1 sec.
  --                   Afetr that we can insert the new row.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure update_history(p_end_date    in  date,
                           p_instance_id in  number,
                           p_err_code    out number,
                           p_err_desc    out varchar2) is

    PRAGMA AUTONOMOUS_TRANSACTION;

  begin
    update XXCS_IB_HISTORY  hist
    set    end_date         = p_end_date - 1/24/60/60
    where  hist.instance_id = p_instance_id
    and    hist.end_date    is null;

    commit;
  exception
    when others then
      fnd_file.put_line(fnd_file.log,'Procedure update_history - Failed - '||substr(sqlerrm,1,240));
      dbms_output.put_line('Procedure update_history - Failed - '||substr(sqlerrm,1,240));
      rollback;
      p_err_code := 1;
      p_err_desc := 'Procedure update_history - Failed - '||substr(sqlerrm,1,240);
  end update_history;

  --------------------------------------------------------------------
  --  name:            insert_history
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   insert new row to XXCS_IB_HISTORY table by
  --                   cursor population
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure insert_history(p_hist_rec   in  t_hist_rec,
                           p_err_code   out number,
                           p_err_desc   out varchar2) is

    PRAGMA AUTONOMOUS_TRANSACTION;
    l_hist_id number := null;
  begin
    p_err_code := 0;
    p_err_desc := null;
    -- get entity id
    select XXCS_IB_HISTORY_S.Nextval
    into   l_hist_id
    from   dual;

    insert into XXCS_IB_HISTORY(hist_id,                  -- n
                                instance_id,              -- n
                                start_date,               -- d
                                end_date,                 -- d
                                instance_active_end_date, -- d
                                party_id,                 -- n
                                party_number,             -- v
                                party_name ,              -- v
                                inventory_item_id,        -- n
                                item,                     -- v
                                item_desc,                -- v
                                item_type,                -- v
                                process_flag,             -- v
                                parameter_run_date,       -- d
                                last_update_date,         -- d
                                last_updated_by,          -- n
                                creation_date,            -- d
                                created_by)               -- n
    values                     (l_hist_id,
                                p_hist_rec.instance_id,
                                p_hist_rec.from_date,
                                p_hist_rec.to_date,
                                null,
                                p_hist_rec.party_id,
                                null,
                                null,
                                p_hist_rec.inventory_item_id,
                                null,
                                null,
                                null,
                                'N',
                                g_run_date,
                                sysdate,
                                g_user_id,
                                sysdate,
                                g_user_id);

    commit;
  exception
    when others then
      fnd_file.put_line(fnd_file.log,'Procedure insert_history - Failed - '||substr(sqlerrm,1,240));
      dbms_output.put_line('Procedure insert_history - Failed - '||substr(sqlerrm,1,240));
      rollback;
      p_err_code := 1;
      p_err_desc := 'Procedure insert_history - Failed - '||substr(sqlerrm,1,240);
  end insert_history;

  --------------------------------------------------------------------
  --  name:            get_last_item_per_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   This function look for the nearest item_id
  --                   by instance_id and date.
  --                   because party history held at one table and item history
  --                   at enother we need to find what was the item when the party changed.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_last_item_per_date (p_instance_id in number,
                                   p_date        in date) return number is
    l_item_id number := null;
  begin

    select ih.new_inventory_item_id
    into   l_item_id
    from   csi_item_instances_h      ih,
           xxcs_items_printers_v     prt -- only for printers
    where  ih.new_inventory_item_id    is not null
    and    nvl(ih.old_inventory_item_id, 0)  <> ih.new_inventory_item_id
    and    ih.new_inventory_item_id    = prt.inventory_item_id
    and    ih.instance_id              = p_instance_id  --10977 --<p_instance_id>
    and    trunc(ih.creation_date)     <= p_date       --27/08/2009
    and    ih.creation_date            = (select max(ih2.creation_date)
                                          from   csi_item_instances_h      ih2
                                          where  ih2.instance_id           = p_instance_id
                                          and    trunc(ih2.creation_date)  <= p_date
                                          and    ih2.new_inventory_item_id is not null
                                          and    nvl(ih2.old_inventory_item_id, 0)  <> ih2.new_inventory_item_id
                                         );
    return l_item_id;

  exception
    when others then
      return null;
  end get_last_item_per_date;

  --------------------------------------------------------------------
  --  name:            get_last_party_per_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   This function look for the nearest party_id
  --                   by instance_id and date.
  --                   because party history held at one table and item history
  --                   at enother we need to find what was the party when the item changed.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_last_party_per_date (p_instance_id in number,
                                    p_date        in date) return number is
    l_party_id number := null;
  begin
    select ph.new_party_id
    into   l_party_id
    from   csi_i_parties_h           ph,
           csi_i_parties             cip,
           hz_parties                hp
    where  ph.instance_party_id      = cip.instance_party_id
    and    ph.new_party_id           is not null
    and    nvl(ph.old_party_id,0)    != ph.new_party_id
    and    ph.new_party_id           = hp.party_id
    and    hp.party_type             = 'ORGANIZATION'
    and    cip.instance_id           = p_instance_id -- 462005
    and    trunc(ph.creation_date)   <= p_date --to_date('22/07/2010','dd/mm/yyyy')
    and    ph.creation_date          = (select max(ph2.creation_date)
                                        from   csi_i_parties_h    ph2,
                                               csi_i_parties      cip2,
                                               hz_parties         hp2
                                        where  cip2.instance_party_id = ph2.instance_party_id
                                        and    ph2.new_party_id           is not null
                                        and    nvl(ph2.old_party_id,0)    != ph2.new_party_id
                                        and    ph2.new_party_id           = hp2.party_id
                                        and    hp2.party_type             = 'ORGANIZATION'
                                        and    cip2.instance_id           =  p_instance_id
                                        and    ph2.new_party_id           is not null
                                        and    trunc(ph2.creation_date)   <= p_date)
     group by ph.new_party_id;

    return l_party_id;
  exception
    when too_many_rows then
      select ph.new_party_id
      into   l_party_id
      from   csi_i_parties_h           ph,
             csi_i_parties             cip,
             hz_parties                hp
      where  ph.instance_party_id      = cip.instance_party_id
      and    ph.new_party_id           is not null
      and    nvl(ph.old_party_id,0)    != ph.new_party_id
      and    ph.new_party_id           = hp.party_id
      and    hp.party_type             = 'ORGANIZATION'
      and    cip.instance_id           = p_instance_id -- 462005
      and    trunc(ph.creation_date)   <= p_date --to_date('22/07/2010','dd/mm/yyyy')
      and    ph.creation_date          = (select max(decode(trunc(ph2.creation_date),to_date ('27-AUG-2009','DD-MON-YYYY'),
                                                                  ph2.new_active_start_date,ph2.creation_date))
                                          from   csi_i_parties_h    ph2,
                                                 csi_i_parties      cip2,
                                                 hz_parties         hp2
                                          where  cip2.instance_party_id = ph2.instance_party_id
                                          and    ph2.new_party_id           is not null
                                          and    nvl(ph2.old_party_id,0)    != ph2.new_party_id
                                          and    ph2.new_party_id           = hp2.party_id
                                          and    hp2.party_type             = 'ORGANIZATION'
                                          and    cip2.instance_id           =  p_instance_id
                                          and    ph2.new_party_id           is not null
                                          and    trunc(ph2.creation_date)   <= p_date)
       and rownum = 1;

       return l_party_id;

    when others then
      return null;
  end get_last_party_per_date;

  --------------------------------------------------------------------
  --  name:            get_install_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  function get_install_date (p_instance_id in number,
                             p_start_date  in date,
                             p_end_date    in date) return date is

    l_install_date date := null;
  begin

    if p_end_date  is null then
      begin
        select install_date
        into   l_install_date
        from   csi_item_instances cii
        where  cii.instance_id    = p_instance_id;
        return l_install_date;
      exception
        when others then return null;
      end;
    else
      begin
        ---
        -- NOTE this select do not support cases which install_date is not between
        -- ownership start date(p_start_date) and end_date (p_end_date)
        -- like in case instance_id = 10082
        --
        select ih.new_install_date
        into   l_install_date
        from   csi_item_instances_h   ih
        where  not (ih.new_install_date is null   and ih.old_install_date is null)
        and    nvl(ih.new_install_date,sysdate-1) <>  nvl(ih.old_install_date,SYSDATE)
        AND    ih.instance_id                     = p_instance_id /*OWNER_HIST.instance_id*/
        AND    nvl(ih.new_install_date,p_start_date) >= p_start_date /*p_end_date*/ --to_date('22/03/2012 16:10:51','dd/mm/yyyy hh24:mi:ss')-- <'p_end date from our table'>
        and    nvl(ih.new_install_date,p_end_date)   < p_end_date
        --AND    ih.instance_history_id             = ( select min(ih2.instance_history_id)
        --and    ih.new_install_date                  = (select min(ih2.new_install_date )
        AND    ih.creation_date                     = (select MAX(ih2.creation_date )
                                                       from   csi_item_instances_h                    ih2
                                                       where  not (ih2.new_install_date is null       and ih2.old_install_date is null)
                                                       and    nvl(ih2.new_install_date,sysdate-1)     <> nvl(ih2.old_install_date,SYSDATE)
                                                       AND    ih2.instance_id                         = p_instance_id
                                                       AND    nvl(ih2.new_install_date,p_start_date ) >= p_start_date
                                                       AND    nvl(ih2.new_install_date, p_end_date)   < p_end_date
                                                       and    ih2.creation_date                       >= p_start_date
                                                       and    ih2.creation_date                       < p_end_date
                                                      );
        return l_install_date;
      exception
      when no_data_found THEN return NULL;

        when others then
          begin
            select install_date
            into   l_install_date
            from   csi_item_instances cii
            where  cii.instance_id    = p_instance_id;
            return l_install_date;
          exception
            when others then
              return null;
          end;
      end;
    end if; -- end date is null
  exception
    when others then
      return null;
  end get_install_date;

  --------------------------------------------------------------------
  --  name:            upd_install_date_first_run
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   Help to run programe with each day a parameter.
  --                   USE ONLY FOR DUBUG OR FIRST RUN AT PRODUCTION
  --                   will correct install_date and update it to Hist tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upd_install_date_first_run (p_err_code    out number,
                                        p_err_desc    out varchar2) is

  PRAGMA AUTONOMOUS_TRANSACTION;

    cursor hst_pop_c is
      select *
      from   XXCS_IB_HISTORY hist;
      --where  process_flag    = 'N';

    l_install_date    date := null;
  begin
    p_err_code := 0;
    p_err_desc := null;
    for hst_pop_r in hst_pop_c loop
      --l_install_date    := null;

      l_install_date := get_install_date (p_instance_id => hst_pop_r.instance_id, -- i n
                                            p_start_date  => hst_pop_r.start_date,  -- i d
                                            p_end_date    => hst_pop_r.end_date);   -- i d

      begin
        update XXCS_IB_HISTORY hist
        set    hist.install_date             = l_install_date
        where  hist.hist_id                  = hst_pop_r.hist_id;
        commit;
      exception
        when others then
          fnd_file.put_line(fnd_file.log,'Update Failed'||
                                         ' Instance id - '||hst_pop_r.instance_id||
                                         ' Hist Id - '||hst_pop_r.hist_id );
          dbms_output.put_line('Update Failed'||
                               ' Instance id - '||hst_pop_r.instance_id||
                               ' Hist Id - '||hst_pop_r.hist_id);
          rollback;
      end;
    end loop;
  exception

    when others then
      p_err_code := 1;
      p_err_desc := 'GEN exception upd_install_date_first_run - '||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'GEN exception upd_install_date_1 - '||substr(sqlerrm,1,240));
      dbms_output.put_line('GEN exception upd_install_date_first_run - '||substr(sqlerrm,1,240));
  end upd_install_date_first_run;

  --------------------------------------------------------------------
  --  name:            install_date_remainder_to_fix
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   Help to run programe with each day a parameter.
  --                   USE ONLY FOR DUBUG OR FIRST RUN AT PRODUCTION
  --                   will correct install_date after update that was made
  --                   with procedure upd_install_date_first_run
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure install_date_remainder_to_fix (p_err_code    out number,
                                           p_err_desc    out varchar2) is
    cursor get_pop_c is
      select zz.hist_id,zz.lead_date install_date_to_upd, zz.instance_id --, zz.*
      from (select lead (t.instance_id)       OVER (PARTITION BY t.instance_id,t.party_id ORDER BY t.start_date) lead_instance,
                   lead (t.inventory_item_id) OVER (PARTITION BY t.instance_id,t.party_id ORDER BY t.start_date) lead_item,
                   lead (t.party_id)          OVER (PARTITION BY t.instance_id,t.party_id ORDER BY t.start_date) lead_party,
                   lead (t.install_date)      OVER (PARTITION BY t.instance_id,t.party_id ORDER BY t.start_date) lead_date,
                   lead (t.end_date)          OVER (PARTITION BY t.instance_id,t.party_id ORDER BY t.start_date) lead_end_date,
                   t.*
            from   xxcs_ib_history t
            where  t.item_type      = 'PRINTER'
            --and  t.instance_id    = 10082
            order by t.start_date
           ) zz
      where  zz.lead_item           != zz.inventory_item_id
      and    zz.lead_date           is not null
      and    zz.install_date        is null
      and    zz.lead_end_date       is null
      and    zz.lead_instance       = zz.instance_id
      and    zz.lead_party          = zz.party_id;
  begin
    p_err_code := 0;
    p_err_desc := null;
    for get_pop_r in get_pop_c loop
      dbms_output.put_line('Instance - '||get_pop_r.instance_id ||' Hist_Id - '||get_pop_r.hist_id);
      update XXCS_IB_HISTORY   hist
      set    hist.install_date = get_pop_r.install_date_to_upd
      where  hist.hist_id      = get_pop_r.hist_id;

      commit;
    end loop;

  exception
    when others then
      dbms_output.put_line('Procedure install_date_remainder_to_fix - Failed - '||substr(sqlerrm,1,240));
      rollback;
      p_err_code := 1;
      p_err_desc := 'Procedure install_date_remainder_to_fix - Failed - '||substr(sqlerrm,1,240);

  end install_date_remainder_to_fix;

  -----------------------------------------------------------
  function alter_db_hidden_parameter return number is

  begin
    execute immediate ' alter session set "_optimizer_push_pred_cost_based"=false' ;
    return 1;
  exception
    when others then
      return 0;
  end;

  --------------------------------------------------------------------
  --  name:
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure upd_changes_install_date (p_err_code    out number,
                                      p_err_desc    out varchar2) is

  PRAGMA AUTONOMOUS_TRANSACTION;

    cursor get_pop_c is
      select cii.last_update_date cii_last_update_date, cii.install_date cii_install_date,
             h.hist_id, h.instance_id
      from   xxcs_ib_history    h,
             csi_item_instances cii
      where  h.end_date         is null
      and    h.install_date     is null
      and    party_number       != 1600 -- Objet Internal Install Base
      and    item_type          = 'PRINTER'
      and    h.instance_id      = cii.instance_id
      and    cii.install_date   is not null;

  begin
    p_err_code  := 0;
    p_err_desc  := null;
    for get_pop_r in get_pop_c loop
      begin
        update xxcs_ib_history h
        set    h.install_date  = get_pop_r.cii_install_date
        where  h.hist_id       = get_pop_r.hist_id;
        commit;
      exception
        when others then
          p_err_code  := 1;
          p_err_desc  := 'Problem to Update install date - hist_id - '||get_pop_r.hist_id||' Instance - '||get_pop_r.instance_id;
      end;
    end loop;

  end upd_changes_install_date;

  --------------------------------------------------------------------
  --  name:            run_prog
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/05/2012 09:27:10
  --------------------------------------------------------------------
  --  purpose :        REP266 - MTXX Reports - Disco report
  --                   Help to run programe with each day a parameter.
  --                   USE ONLY FOR DUBUG OR FIRST RUN AT PRODUCTION
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure run_prog is
    cursor date_c is
      select map.accounting_date
      from   gl_date_period_map map                                       -- 31/12/2010
      where  map.accounting_date > to_date('24-AUG-2009','DD-MON-YYYY') -- 25-AUG-2009 - 01-JAN-2011
      and    map.accounting_date < trunc(sysdate) -- to_date('01-JAN-2010','DD-MON-YYYY') -- trunc(sysdate) 01-JAN-2011 - 01-JAN-2012 trunc(sysdate)
      order by accounting_date;

    l_err_code number         := 0;
    l_err_desc varchar2(2500) := null;
  begin
    for date_r in date_c loop
      l_err_code := 0;
      l_err_desc := null;

      main_history ( errbuf   => l_err_code, --out varchar2,
                     retcode  => l_err_desc, --out number,
                     p_date   => date_r.accounting_date); -- in date
      if nvl(l_err_code,0) <> 0 then
        dbms_output.put_line(l_err_desc);
      end if;
    end loop;

  end run_prog;


end XXCS_IB_HISTORY_PKG;
/
