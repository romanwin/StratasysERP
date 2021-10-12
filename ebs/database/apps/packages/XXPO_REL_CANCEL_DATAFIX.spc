CREATE OR REPLACE PACKAGE xxpo_rel_cancel_datafix IS
  --------------------------------------------------------------------
  --  customization code: CR 1297 - Tech Log Issue # 181 - XX: PO Release Cancel Datafix  
  --  name:               PO Release Cancellation Data fix
  --  create by:          Venu Kandi
  --  $Revision:          1.0 
  --  creation date:      30/01/2014
  --------------------------------------------------------------------
  --  process:            Datafix for Syteline to Oracle converted blanket releases  
  --                      Encumberance account flag was set to Y on the shipments and distributions
  --                      which is preventing users from cancelling converted Blanket PO releases
  --------------------------------------------------------------------
  --  ver    date         name           desc
  --  1.0   30/01/2014   Venu Kandi      initial build
  --------------------------------------------------------------------

  PROCEDURE fix_po_release(errbuf             OUT  VARCHAR2,
                           retcode            OUT  NUMBER,
                           p_po_header_id 	  IN   NUMBER, 
						   p_rel_number 	  IN   NUMBER);

END xxpo_rel_cancel_datafix;
/

