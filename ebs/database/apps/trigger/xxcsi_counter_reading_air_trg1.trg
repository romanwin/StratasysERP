create or replace trigger XXCSI_COUNTER_READING_AIR_TRG1
  after insert on csi_counter_readings  
  for each row
   
declare
  l_instance_id     number         := null;
  l_sf_id           varchar2(150)  := null;
  l_source_id_exist varchar2(5)    := 'N';
  l_relate_to_sf    varchar2(5)    := 'N';
  l_oa2sf_rec       xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code        varchar2(10)   := 0;
  l_err_desc        varchar2(2500) := null;
begin
--------------------------------------------------------------------
--  name:            XXCSI_COUNTER_READING_BUR_TRG1
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   05/10/2010 1:30:11 PM
--------------------------------------------------------------------
--  purpose :        Trigger that will fire each update of counter reading field
--                   will check: 
--                   1) if this counter relate to item_instance that relate to SF
--                   2) get instance_id and attribute12 (SF_id)
--                   3) if there is a row at interface tbl XXOBJT_OA2SF_INTERFACE
--                      if not insert row to interface tbl XXOBJT_OA2SF_INTERFACE
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  05/10/2010  Dalit A. Raviv    initial build
--------------------------------------------------------------------  

  if ( :NEW.counter_reading is not null ) then
  -- Check if this counter relate to Item Instance that relate to SF.
  l_relate_to_sf := XXOBJT_OA2SF_INTERFACE_PKG.is_relate_to_sf (p_source_id    => :NEW.counter_id ,
                                                                p_source_name  => 'INSTALL_BASE',
                                                                p_process_mode => 'UPDATE');
 
  if l_relate_to_sf = 'Y' then
    -- get instance id and att12
    begin
      select cii.instance_id, cii.attribute12
      into   l_instance_id,   l_sf_id
      from   csi_counter_associations cca,
             csi_item_instances       cii
      where  cii.instance_id          = cca.source_object_id
      and    cca.counter_id           = :NEW.counter_id;
    exception
      when others then
        l_instance_id := null;
    end;
   
    if l_instance_id is not null then 
      -- check that there is no row for IB (inctance_id) at interface tbl
      l_source_id_exist := XXOBJT_OA2SF_INTERFACE_PKG.is_source_id_exist (p_source_id    => l_instance_id,
                                                                          p_source_name  => 'INSTALL_BASE');

      if l_source_id_exist = 'N' then
        l_oa2sf_rec.status       := 'NEW';
        l_oa2sf_rec.source_id    := l_instance_id;
        l_oa2sf_rec.source_name  := 'INSTALL_BASE';
        l_oa2sf_rec.sf_id        := l_sf_id;
        XXOBJT_OA2SF_INTERFACE_PKG.insert_into_interface (p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                          p_err_code  => l_err_code,  -- o v
                                                          p_err_msg   => l_err_desc); -- o v
      end if; -- l_source_id_exist  = N
    end if;
  end if; -- l_relate_to_sf
  end if;
end XXCSI_COUNTER_READING_AIR_TRG1;
/

