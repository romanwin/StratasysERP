CREATE OR REPLACE PACKAGE XXCSI_NSRL_RMA_PKG as

--------------------------------------------------------------------
--  name:            CUST 321 - Update IB and clear Error interface after RMA process
--  create by:       Vitaly K.
--  Revision:        1.0 
--  creation date:   30/05/2010 
--------------------------------------------------------------------
--  purpose :        Update IB and clear Error interface after RMA process
--------------------------------------------------------------------
--  ver  date        name            desc
--  1.0  30/05/2010  Vitaly K.       initial build
-------------------------------------------------------------------- 

  g_utl_check_done   char := 'N';

  TYPE rma_rec is RECORD(
    rma_line_id        number,
    inventory_item_id  number,
    organization_id    number,
    received_quantity  number,
    ordered_quantity   number,
    order_quantity_uom varchar2(9),
    lot_number         varchar2(30),
    revision           varchar2(3),
    party_id           number,
    party_acct_id      number,
    transaction_date   date);


  TYPE ref_inst_rec is RECORD(
    instance_id        number,
    inventory_item_id  number,
    organization_id    number,
    quantity           number,
    lot_number         varchar2(30),
    uom                varchar2(9));

  TYPE ref_inst_tbl is TABLE of ref_inst_rec INDEX BY binary_integer;

  TYPE instance_rec IS RECORD(
    instance_id        number,
    inst_remained_qty  number);

  TYPE instance_tbl IS TABLE of instance_rec INDEX BY binary_integer;
  
  --------------------------------------------------------------
  Procedure create_ib_relationship (p_parent_instance_id  IN NUMBER,
                                    p_child_instance_id   IN NUMBER);
  --------------------------------------------------------------
  PROCEDURE nsr_rma_fix(errbuf            OUT NOCOPY VARCHAR2,
                        retcode           OUT NOCOPY NUMBER,
                        p_batch_number    IN  number,
                        p_create_instance IN  VARCHAR2);
  --------------------------------------------------------------
END XXCSI_NSRL_RMA_PKG ;
/

