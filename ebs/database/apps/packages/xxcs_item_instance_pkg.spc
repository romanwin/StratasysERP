CREATE OR REPLACE PACKAGE xxcs_item_instance_pkg IS

--------------------------------------------------------------------
--  name:            XXCS_ITEM_INSTANCE_PKG
--  create by:       Vitaly K.
--  Revision:        1.4
--  creation date:   10/01/2010
--------------------------------------------------------------------
--  purpose :        For concurrent XX: Set Item Instance  (short name: XXCS_SET_ITEM_INSTANCE)
--                   program that clean IB for instances that return back to inventory
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  10/01/2010  Vitaly K.         initial build
--  1.1  06/11/2011  Roman V.          set_item_instance /update_child_instance_systems 
--                                     rull out instances that returned from shows/T&B and sold to same customer
--  1.2  22/01/2012  Dalit A. Raviv    set_item_instance - add condition to population
--  1.3  24/04/2012  Dalit A. Raviv    set_item_instance - add or condition on attribute8 
--                                     We now add the region as part from the condition to 
--                                     delete the data when a printer is returning to Objet. 
--  1.4  29/04/2013  Dalit A. Raviv    new program to update US CS region                                   
--------------------------------------------------------------------

  type xxcs_instance_rec is record(instance_id        number,
                                   instance_rank      number,
                                   inventory_item_id  number,
                                   item               varchar2(100),
                                   organization_id    number,
                                   quantity           number,
                                   uom                varchar2(9));

  type xxcs_instance_tbl is table of xxcs_instance_rec;


  type xxcs_instance_history_rec is record(instance_id                number,
                                           history_rank               number,
                                           party_id                   number,
                                           party_number               varchar2(100),
                                           party_name                 varchar2(300),
                                           ownership_date             date,    ---start
                                           end_date                   date,    ---stop
                                           instance_active_end_date   date,
                                           item                       varchar2(100),
                                           item_desc                  varchar2(100),
                                           item_type                  varchar2(100),
                                           party_hist_transaction_id  number,
                                           party_hist_creation_date   date);

  type xxcs_instance_history_tbl is table of xxcs_instance_history_rec;

  --------------------------------------------------------------------
  --  name:            set_item_instance
  --  create by:       Vitaly K.
  --  Revision:        1.0
  --  creation date:   10/01/2010
  --------------------------------------------------------------------
  --  purpose :        For concurrent XX: Update Child Instance Systems  (short name: XXCS_UPD_CHILD_INSTANCE_SYS)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/01/2010  Vitaly K.         initial build
  --  1.1  06/11/2011  Roman V.          rull out instances that returned from
  --                                     shows/T&B and sold to same customer
  --------------------------------------------------------------------
  procedure set_item_instance(errbuf   out varchar2,
                              errcode  out varchar2);
  
  --------------------------------------------------------------------
  --  name:            update_us_cs_region
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/04/2013
  --------------------------------------------------------------------
  --  purpose :        Concurrent - XX: Update US IB according to states
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/04/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                              
  procedure update_us_cs_region (errbuf   out varchar2,
                                 errcode  out varchar2);                               

  procedure update_child_instance_systems(errbuf   out varchar2,
                                          errcode  out varchar2);

  --- not in use
  ----FUNCTION get_instance_top_level_parent(p_child_instance_id IN NUMBER) RETURN NUMBER; ---from bottom to top
  ---
  function get_child_inst_from_hierarchy(p_parent_instance_id           in number,
                                         p_child_inst_inventory_item_id in number,
                                         p_error_interface_header_id    in number) return xxcs_instance_tbl pipelined;

  function get_unassigned_instance(p_owner_party_id            in number,
                                   p_owner_party_acct_id       in number,
                                   p_inventory_item_id         in number,
                                   p_error_interface_header_id in number) return xxcs_instance_tbl pipelined;

  function get_instance_ownership_history(p_instance_id  in number) return xxcs_instance_history_tbl pipelined;

end xxcs_item_instance_pkg;

 
/
