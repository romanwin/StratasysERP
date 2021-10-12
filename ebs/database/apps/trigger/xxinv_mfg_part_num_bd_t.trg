create or replace trigger XXINV_MFG_PART_NUM_BD_T
  before delete on MTL_MFG_PART_NUMBERS
  for each row
declare
  -- local variables here
  l_count            number := 0;
  --l_message          varchar2(1000);
  general_exception  exception;
begin
--------------------------------------------------------------------
--  customization code: CUST308
--  name:               XXINV_MFG_PART_NUM_BD_T
--  create by:          Dalit A. Raviv
--  $Revision:          1.0
--  creation date:      03/05/2010
--  Description:        Prevent Delete Mfg part num when exist PO att1
--                      or exist requisitions
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   03/05/2010    Dalit A. Raviv  initial build
--------------------------------------------------------------------
  -- profile to control trigger
  IF nvl(fnd_profile.VALUE('XXINV_ENABLE_MFG_PART_NUM_DEL'), 'N') = 'Y' THEN
    -- check if there is PO for the wanted delete mfg_part_num
    select count(1)
    into   l_count
    from   po_lines_all      pol,
           mtl_manufacturers mm
    where  pol.attribute1    is not null
    and    substr(pol.attribute1,1,instr(pol.attribute1,'|')-1) = :old.mfg_part_num
    and    substr(pol.attribute1,instr(pol.attribute1,'|')+1)   = mm.manufacturer_name
    and    mm.manufacturer_id                                   = :old.manufacturer_id
    and    pol.item_id                                          = :old.inventory_item_id;
    -- if there is PO raise exception and popup message to the screen
    if l_count > 0 then
      raise general_exception;
    elsif l_count = 0 then
      -- check at Requisitions level
      select count(1)
      into   l_count
      from   Po_Requisition_Lines_All rl,
             po_requisition_headers_all rh
      where  rl.requisition_header_id   = rh.requisition_header_id
      and    rl.manufacturer_part_number = :old.mfg_part_num      -- 'ACMO'--
      and    rl.item_id                  = :old.inventory_item_id -- 15921 --
      and    rl.manufacturer_id          = :old.manufacturer_id;  -- 1034; --

      if l_count > 0 then
        raise general_exception;
      end if;
    end if;
  end if;
exception
  when general_exception then

    fnd_message.set_name('XXOBJT','XXINV_MFG_PART_NUM_DEL_ERR');
    --l_message := fnd_message.get;
    --dbms_output.put_line('l_message - '||l_message);
    app_exception.raise_exception;

  when others then
    null;
end XXINV_MFG_PART_NUM_BD_T;
/

