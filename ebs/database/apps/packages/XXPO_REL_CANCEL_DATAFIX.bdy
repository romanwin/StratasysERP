CREATE OR REPLACE PACKAGE BODY xxpo_rel_cancel_datafix IS
  --------------------------------------------------------------------
  --  customization code: CR # 1297 - Tech Log # 181 
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
  --  1.1   02/12/2014   Venu Kandi      CR# 1321
  --                                     Previous version of code only allows the fix to work if the 
  --                                     we did not receive anything on the release (or shipment)
  --                                     That check is removed in this version
  --------------------------------------------------------------------
  PROCEDURE fix_po_release(errbuf             OUT  VARCHAR2,
                           retcode            OUT  NUMBER,
                           p_po_header_id 	  IN   NUMBER,
						   p_rel_number 	  IN   NUMBER)
  IS
  	ln_po_release_id number;
	ln_count		 number;
  BEGIN

	   fnd_file.put_line (fnd_file.log, 'PO_HEADER_ID = ' || p_po_header_id);
	   fnd_file.put_line (fnd_file.log, 'RELEASE NUMBER = ' || p_rel_number);

  	   -- Get the release id for the release number
	   SELECT por.po_release_id
	   INTO ln_po_release_id
	   FROM  po_releases_all por
	   WHERE por.po_header_id = p_po_header_id
	   AND	 por.release_num  = p_rel_number;

	   fnd_file.put_line (fnd_file.log, 'PO_RELEASE_ID = ' || ln_po_release_id);
	   fnd_file.put_line (fnd_file.log, ' ');

	   -- fix shipments for PO release cancellation
	   update po_line_locations_all
	   set encumbered_flag = 'N',
	   	   taxable_flag	= 'N',
		   cancel_flag 	= 'N',
		   closed_code 	= 'OPEN'
	   where po_release_id = ln_po_release_id
	   and	 created_by    = 1171; 
	   -- and	 quantity_received = 0; -- Commented by Venu 02/12/2014 

	   ln_count := sql%rowcount;

	   fnd_file.put_line (fnd_file.log, 'Total shipments updated: ' || ln_count);
  	   fnd_file.put_line (fnd_file.log, 'NOTE: Program updates shipments with quantity received = 0');

	   -- fix distributions for PO release cancellation
	   update po_distributions_all pod
	   set encumbered_flag = 'N',
	   	   encumbered_amount = null,
		   gl_encumbered_date = null,
		   gl_encumbered_period_name = null
	   where po_release_id = ln_po_release_id
	   and	 created_by    = 1171
	   and	 line_location_id in (select line_location_id
	   		 				  	  from po_line_locations_all pll
								  where pll.po_release_id = pod.po_release_id
								  and	pll.created_by    = 1171
	   							  -- and	pll.quantity_received = 0 -- Commented by Venu 02/12/2014 
								  );

	   fnd_file.put_line (fnd_file.log, 'Total distributions updated: ' || ln_count);

	   commit;

  END fix_po_release;
END xxpo_rel_cancel_datafix;
/

