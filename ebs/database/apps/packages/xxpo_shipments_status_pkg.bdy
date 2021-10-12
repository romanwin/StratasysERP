CREATE OR REPLACE PACKAGE BODY xxpo_shipments_status_pkg IS

  --------------------------------------------------------------------
  --  customization code: CUST053
  --  name:               xxpo_shipments_status_pk
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      24/05/2006
  --  Purpose : Cust 053 - change arrival_date from attribute1 to
  --                       promised_date use of api
  --                       po_change_api1_s.update_po to update this field.
  ----------------------------------------------------------------------
  --  ver   date            name            desc
  --  1.0   24/05/2006      Dalit A. Raviv  initial build
  --  1.1  8.5.17           yuval tal       CHG0040670 : add get_hold_period
  -----------------------------------------------------------------------

  /**************************************************************************************/
  /* Procedure : update_po_promise_date                                                 */
  /* Purpose   : This procedure update the new promised date user enter in the screen.  */
  /*             The update is dune by using po_change_api1_s.update_po api.            */
  /*             The logic is 1) cursor on the rows inserted to the temp tbl (user      */
  /*                          checked in the screen) and do group by po_number. that how*/
  /*                          i get all po i need to update.                            */
  /*                          2) count rows for each po_number.                         */
  /*                          3) check if there is one row to update or many rows. for  */
  /*                             one row the handle is to do the update . there is the  */
  /*                             p_update param that tell me if to do uppdate or uppdate*/
  /*                             and approve of the po.  for po's with more then one row*/
  /*                             i separete the hundle of the last row from the others. */
  /*                             i need to send the current po version to the first row */
  /*                             and all the others will get a higer version.           */
  /*                             if user press the uppdate_and_approved button then for */
  /*                             the last row p_launch_approval_flag param will get Y   */
  /*                             all others will get N . this prevent the po version go */
  /*                             up for each row. it wil go up only the first row and   */
  /*                             on the last row i do the approve.                      */
  /*                                                                                    */
  /* Param in  : 1. p_update_id  - will be the id of all rows user checked to update    */
  /*             2. p_update     - will be the sign which button user pressed           */
  /* Param out : 1. p_error_code - 0 is success, 1 if fialed                            */
  /*             2. p_error_desc - null if success, sqlerrm if failed                   */
  /*                                                                                    */
  /*                                                                                    */
  /* Ver:  Created By:        Creation Date:   Version:                                 */
  /* 1.0   Dalit A. Raviv     24/05/06         Initial ver.                             */
  /* 1.1   Dalit A. Raviv     17/02/2010       add update of attribute3,4 at pll tbl    */
  /* 1.2   yuval tal          26.7.10          add (failed )err row count out var       */
  /* 1.3   Dalit A. Raviv     05/04/2015       CHG0034852 add shipment acceptance info  */
  /*                                           GTMS project                             */
  /**************************************************************************************/
  PROCEDURE update_po_promise_date(p_update_id IN NUMBER,
		           p_update    IN VARCHAR2,
		           --p_err_count  OUT NUMBER,
		           p_error_code OUT NUMBER,
		           p_error_desc OUT VARCHAR2) IS
  
    ------
    -- get all Po's to do the uppdate.
    --
    CURSOR shipment_status_temp_c IS
      SELECT xsst.po_number,
	 xsst.po_header_id,
	 xsst.po_release_id,
	 xsst.release_number,
	 xsst.revision_number,
	 xsst.rel_revision_num
      FROM   xxpo_shipments_status_temp xsst
      WHERE  xsst.update_id = p_update_id
      GROUP  BY xsst.po_number,
	    xsst.po_header_id,
	    xsst.po_release_id,
	    xsst.release_number,
	    xsst.revision_number,
	    xsst.rel_revision_num;
    ------
    -- get all lines, shipments of a specific Po/Release
    --
    CURSOR po_to_update_c(p_po_header_id  IN NUMBER,
		  p_po_release_id IN NUMBER) IS
      SELECT xsst1.po_line_id,
	 xsst1.line_number,
	 xsst1.po_line_location_id,
	 xsst1.shipment_number,
	 xsst1.new_promised_date,
	 xsst1.buyer_name,
	 -- Dalit A. Raviv 19/09/2010 add field to update
	 nvl(xsst1.changed_orig_promised_date, 'N') changed_orig_promised_date,
	 -- Dalit A. Raviv 05/04/2015 CHG0034852 add shipment acceptance info
	 xsst1.shipment_acceptance_code
      FROM   xxpo_shipments_status_temp xsst1
      WHERE  xsst1.po_header_id = p_po_header_id
      AND    xsst1.update_id = p_update_id
      AND    nvl(xsst1.po_release_id, 0) = nvl(p_po_release_id, 0);
  
    l_count         NUMBER := 0;
    l_approval_flag VARCHAR2(3) := NULL;
    l_err_count     NUMBER := 1;
    l_rev_num       NUMBER := NULL;
    l_error_code    NUMBER := 0;
    l_error_desc    VARCHAR2(2000) := NULL;
    l_org_id        NUMBER;
    l_po_org_id     NUMBER;
  
  BEGIN
  
    l_org_id := nvl(fnd_profile.value('DEFAULT_ORG_ID'),
	        fnd_profile.value('ORG_ID'));
    ------
    -- Set org context to match MO: Operating Unit profile before calling the API
    --
    dbms_application_info.set_client_info(l_org_id);
    ------
    -- initialize the global variables org_id, user_id and application_id
    -- NOTE: application_id should be 201 for purchasing
    --fnd_global.APPS_INITIALIZE(l_user_id,l_resp_id ,l_resp_appl_id);
    mo_global.set_org_access(p_org_id_char     => l_org_id,
		     p_sp_id_char      => NULL,
		     p_appl_short_name => 'PO');
  
    --mo_global.set_policy_context ('A', i.org_id); -- 'S' = Single, 'M' = Multiple, 'A' = All.
    --mo_global.init ('PO');
  
    ------
    -- Cursor that bring all the po that need to be update
    --
    FOR shipment_status_temp_r IN shipment_status_temp_c LOOP
      ------
      -- for each po/release check how many rows checked
      -- i count the row user checked in the screen and i
      -- inserted them to the temp table.
      -- if there is a release_id the count will be from the release
      -- and not from the po blanket agreement.(each release for the same po
      -- can have different number of rows checked.
      --
      IF shipment_status_temp_r.po_release_id IS NULL THEN
        SELECT COUNT(xsst.line_number)
        INTO   l_count
        FROM   xxpo_shipments_status_temp xsst
        WHERE  xsst.po_header_id = shipment_status_temp_r.po_header_id
        AND    xsst.update_id = p_update_id;
      ELSE
        SELECT COUNT(xsst.shipment_number)
        INTO   l_count
        FROM   xxpo_shipments_status_temp xsst
        WHERE  xsst.po_header_id = shipment_status_temp_r.po_header_id
        AND    xsst.po_release_id = shipment_status_temp_r.po_release_id
        AND    xsst.update_id = p_update_id;
      END IF;
    
      l_rev_num   := NULL;
      l_err_count := 0;
      ------
      -- Cursor for each po/release with its rows
      --
      FOR po_to_update_r IN po_to_update_c(shipment_status_temp_r.po_header_id,
			       shipment_status_temp_r.po_release_id) LOOP
        --all cases that row is higer then 1
        IF l_count <> 1 THEN
          -- Dalit A. Raviv 05/04/2015 CHG0034852 add shipment acceptance info
          IF po_to_update_r.new_promised_date IS NOT NULL THEN
	------
	-- Get po/release revision num
	-- The release reviion num will be from the release itself
	--
	IF shipment_status_temp_r.po_release_id IS NULL THEN
	  SELECT poh.revision_num,
	         poh.org_id
	  INTO   l_rev_num,
	         l_po_org_id
	  FROM   po_headers_all poh
	  WHERE  po_header_id = shipment_status_temp_r.po_header_id;
	ELSE
	  SELECT por.revision_num,
	         por.org_id
	  INTO   l_rev_num,
	         l_po_org_id
	  FROM   po_releases_all por
	  WHERE  por.po_header_id = shipment_status_temp_r.po_header_id
	  AND    por.po_release_id =
	         shipment_status_temp_r.po_release_id;
	END IF;
          
	update_po(p_po_number                  => shipment_status_temp_r.po_number, -- in  v
	          p_release_number             => shipment_status_temp_r.release_number, -- in  n
	          p_revision_number            => l_rev_num, -- in  n
	          p_line_number                => po_to_update_r.line_number, -- in  n
	          p_shipment_number            => po_to_update_r.shipment_number, -- in  n
	          p_new_promised_date          => po_to_update_r.new_promised_date, -- in  d
	          p_launch_approval_flag       => 'N', -- in  v
	          p_buyer_name                 => po_to_update_r.buyer_name, -- in  v
	          p_org_id                     => l_po_org_id, /*l_org_id*/ -- in  n Dalit 24/12/2009
	          p_po_line_id                 => po_to_update_r.po_line_id, -- Dalit A. Raviv 19/09/2010 add field to update
	          p_po_header_id               => shipment_status_temp_r.po_header_id, -- Dalit A. Raviv 19/09/2010 add field to update
	          p_changed_orig_promised_date => po_to_update_r.changed_orig_promised_date, -- Dalit A. Raviv 19/09/2010 add field to update
	          p_error_code                 => l_error_code, -- out n
	          p_error_desc                 => l_error_desc); -- out v
          
	IF l_error_code = 1 AND l_error_desc IS NOT NULL THEN
	  p_error_code := l_error_code;
	  p_error_desc := l_error_desc;
	  l_err_count  := l_err_count + 1;
	END IF;
          
	l_count := l_count - 1;
          END IF; -- update promised date
          -- Dalit A. Raviv 05/04/2015 CHG0034852 add shipment acceptance info
          IF po_to_update_r.shipment_acceptance_code IS NOT NULL THEN
	BEGIN
	  UPDATE po_line_locations_all pll
	  SET    attribute8           = po_to_update_r.shipment_acceptance_code,
	         pll.last_updated_by  = fnd_global.user_id,
	         pll.last_update_date = SYSDATE
	  WHERE  pll.line_location_id =
	         po_to_update_r.po_line_location_id;
	  COMMIT;
	EXCEPTION
	  WHEN OTHERS THEN
	    p_error_code := 1;
	    p_error_desc := 'Problem update Shipment Acceptance (att8) - PO ' ||
		        shipment_status_temp_r.po_number || ' Rel ' ||
		        shipment_status_temp_r.release_number ||
		        ' line ' || po_to_update_r.line_number ||
		        ' Shipment ' ||
		        po_to_update_r.shipment_number || ' Err ' ||
		        substr(SQLERRM, 1, 2450);
	END;
          END IF; -- update shipment acceptance 05/04/2015 CHG0034852
          -- all cases that row is 1 (only one row or last row)
        ELSE
          -- Dalit A. Raviv 05/04/2015 CHG0034852 add shipment acceptance info
          IF po_to_update_r.new_promised_date IS NOT NULL THEN
          
	------
	-- Get po/release revision num
	-- The release reviion num will be from the release itself
	--
	IF shipment_status_temp_r.po_release_id IS NULL THEN
	  SELECT poh.revision_num,
	         poh.org_id
	  INTO   l_rev_num,
	         l_po_org_id
	  FROM   po_headers_all poh
	  WHERE  po_header_id = shipment_status_temp_r.po_header_id;
	ELSE
	  SELECT por.revision_num,
	         por.org_id
	  INTO   l_rev_num,
	         l_po_org_id
	  FROM   po_releases_all por
	  WHERE  por.po_header_id = shipment_status_temp_r.po_header_id
	  AND    por.po_release_id =
	         shipment_status_temp_r.po_release_id;
	END IF;
          
	------
	-- handle update or update and approve api (N/Y)
	--
	IF p_update = 'UPDATE' THEN
	  l_approval_flag := 'N';
	ELSIF p_update = 'UPDATE_APP' THEN
	  l_approval_flag := 'Y';
	END IF;
          
	update_po(p_po_number                  => shipment_status_temp_r.po_number, -- in  v
	          p_release_number             => shipment_status_temp_r.release_number, -- in  n
	          p_revision_number            => l_rev_num, -- in  n
	          p_line_number                => po_to_update_r.line_number, -- in  n
	          p_shipment_number            => po_to_update_r.shipment_number, -- in  n
	          p_new_promised_date          => po_to_update_r.new_promised_date, -- in  d
	          p_launch_approval_flag       => l_approval_flag, -- in  v
	          p_buyer_name                 => po_to_update_r.buyer_name, -- in  v
	          p_org_id                     => l_po_org_id, /*l_org_id*/ -- in  n Dalit 24/12/2009
	          p_po_line_id                 => po_to_update_r.po_line_id, -- Dalit A. Raviv 19/09/2010 add field to update
	          p_po_header_id               => shipment_status_temp_r.po_header_id, -- Dalit A. Raviv 19/09/2010 add field to update
	          p_changed_orig_promised_date => po_to_update_r.changed_orig_promised_date, -- Dalit A. Raviv 19/09/2010 add field to update
	          p_error_code                 => l_error_code, -- out n
	          p_error_desc                 => l_error_desc); -- out v
          
	IF l_error_code = 1 AND l_error_desc IS NOT NULL THEN
	  p_error_code := l_error_code;
	  p_error_desc := l_error_desc;
	  l_err_count  := l_err_count + 1;
	END IF;
          END IF; -- Update promised date
          -- Dalit A. Raviv 05/04/2015 CHG0034852 add shipment acceptance info
          IF po_to_update_r.shipment_acceptance_code IS NOT NULL THEN
	BEGIN
	  UPDATE po_line_locations_all pll
	  SET    attribute8           = po_to_update_r.shipment_acceptance_code,
	         pll.last_updated_by  = fnd_global.user_id,
	         pll.last_update_date = SYSDATE
	  WHERE  pll.line_location_id =
	         po_to_update_r.po_line_location_id;
	  COMMIT;
	EXCEPTION
	  WHEN OTHERS THEN
	    p_error_code := 1;
	    p_error_desc := 'Problem update Shipment Acceptance (att8) - PO ' ||
		        shipment_status_temp_r.po_number || ' Rel ' ||
		        shipment_status_temp_r.release_number ||
		        ' line ' || po_to_update_r.line_number ||
		        ' Shipment ' ||
		        po_to_update_r.shipment_number || ' Err ' ||
		        substr(SQLERRM, 1, 240);
	END;
          END IF; -- 05/04/2015 CHG0034852
        END IF; -- l_count <> 1
      END LOOP; -- po_to_update_r
    END LOOP; -- shipment_status_temp_r
  
  END update_po_promise_date;

  /**************************************************************************************/
  /* Procedure : update_po                                                              */
  /* Purpose   : 1) call to po_change_api1_s.update_po api                              */
  /*             2) handle the return value from the api                                */
  /*                if return 0 (success) do commit, if return 1 (failed) do roollbke   */
  /*                and handle error msg .                                              */
  /*                                                                                    */
  /* Param in  : 1. p_po_number                                                         */
  /*             2. p_release_number                                                    */
  /*             3. p_revision_number                                                   */
  /*             4. p_line_number                                                       */
  /*             5. p_shipment_number                                                   */
  /*             6. p_new_promised_date                                                 */
  /*             7. p_launch_approval_flag                                              */
  /*             8. p_buyer_name                                                        */
  /* Param out : 1. p_error_code                                                        */
  /*             2. p_error_desc                                                        */
  /*                                                                                    */
  /*                                                                                    */
  /* Created By:           Creation Date:        Version:                               */
  /* 1.0   Dalit A. Raviv     25/05/06           Initial ver.                           */
  /* 1.2   Dalit A. Raviv     19/09/2010         add ability to change original         */
  /*                                             promised date if checked at screen     */
  /*                                                                                    */
  /**************************************************************************************/
  PROCEDURE update_po(p_po_number                  IN VARCHAR2,
	          p_release_number             IN NUMBER,
	          p_revision_number            IN NUMBER,
	          p_line_number                IN NUMBER,
	          p_shipment_number            IN NUMBER,
	          p_new_promised_date          IN DATE,
	          p_launch_approval_flag       IN VARCHAR2,
	          p_buyer_name                 IN VARCHAR2,
	          p_org_id                     IN NUMBER,
	          p_po_line_id                 IN NUMBER, -- 1.2 Dalit A. Raviv  19/09/2010
	          p_po_header_id               IN NUMBER, -- 1.2 Dalit A. Raviv  19/09/2010
	          p_changed_orig_promised_date IN VARCHAR2, -- 1.2 Dalit A. Raviv 19/09/2010
	          p_error_code                 OUT NUMBER,
	          p_error_desc                 OUT VARCHAR2) IS
  
    l_num        NUMBER := NULL;
    l_api_errors po_api_errors_rec_type;
  
  BEGIN
  
    l_num := po_change_api1_s.update_po(x_po_number           => p_po_number, -- po num
			    x_release_number      => p_release_number, -- release num
			    x_revision_number     => p_revision_number, -- po revision num
			    x_line_number         => p_line_number, -- line num
			    x_shipment_number     => p_shipment_number, -- shipment num
			    new_quantity          => to_number(NULL), /*p_new_quantity*/ -- new qty  -- Dalit 31/12/2009
			    new_price             => to_number(NULL), -- new price
			    new_promised_date     => p_new_promised_date, -- new promised date
			    new_need_by_date      => NULL, ---------- new
			    launch_approvals_flag => p_launch_approval_flag, -- launch approval through workflow
			    update_source         => NULL, -- Reserved for future use
			    version               => '1.0', -- Version of the API
			    x_override_date       => SYSDATE, -- for the reserved po
			    x_api_errors          => l_api_errors, -- PO_API_ERRORS_REC_TYPE for debug
			    p_buyer_name          => p_buyer_name, -- buyer name can get other then the one who mad the po
			    p_secondary_quantity  => NULL, -------- new number
			    p_preferred_grade     => NULL, -------- new varchar2
			    -- <INVCONV R12 END>
			    p_org_id => p_org_id); -------- new number need to be a param
  
    IF l_num = 1 THEN
      -- success to update
      COMMIT;
      p_error_code := 0;
      p_error_desc := NULL;
    
      -- 1.2 Dalit A. Raviv 19/09/2010 add ability to change original promised date if checked at screen
      BEGIN
        IF p_changed_orig_promised_date = 'Y' THEN
          UPDATE po_line_locations pll
          SET    attribute4 = to_char(p_new_promised_date, 'YYYY/MON/DD')
          WHERE  pll.po_header_id = p_po_header_id
          AND    pll.po_line_id = p_po_line_id
          AND    pll.shipment_num = p_shipment_number;
          COMMIT;
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          p_error_code := 1;
          p_error_desc := p_error_desc || ' - ' ||
		  'Failed to update original promised date - line id - ' ||
		  p_po_line_id;
      END;
    
    ELSIF l_num = 0 THEN
      -- faile to update
    
      FOR i IN 1 .. l_api_errors.message_text.count LOOP
      
        p_error_code := 1;
        p_error_desc := ('could not update po_num - ' || p_po_number ||
		' line_num - ' || p_line_number ||
		' shipment_number - ' || p_shipment_number ||
		'release_num - ' || p_release_number || chr(10) ||
		'message_name - ' || l_api_errors.message_name(i) ||
		chr(10) || 'message_text - ' ||
		l_api_errors.message_text(i) || chr(10) ||
		'table_name   - ' || l_api_errors.table_name(i) ||
		chr(10) || 'column_name  - ' ||
		l_api_errors.column_name(i) || chr(10) ||
		'entity_type  - ' || l_api_errors.entity_type(i) ||
		chr(10) || 'entity_id    - ' ||
		l_api_errors.entity_id(i));
      END LOOP; -- msg_text
      ROLLBACK;
    END IF; --l_num
  
  END update_po;

  /************************************************************************
  *
  * Procedure:    insert_into_temp_table
  *
  * Description:  insert rows to temp tbl.
  *           xxpo_shipments_status_temp.
  *           by the update_id i recognize all the rows checked by the
  *           user, and then with a cursor i will go and do the update.
  *
  * Programer:    Dalit A. Raviv
  * Date:         23-MAY-2006
  *
  ************************************************************************/
  PROCEDURE insert_into_temp_table(p_update_id        IN NUMBER,
		           p_po_number        IN VARCHAR2,
		           p_release_number   IN NUMBER,
		           p_revision_number  IN NUMBER,
		           p_rel_revision_num IN NUMBER,
		           p_line_number      IN NUMBER,
		           p_shipment_number  IN NUMBER,
		           p_new_promise_date IN DATE,
		           p_buyer_name       IN VARCHAR2,
		           p_po_header_id     IN NUMBER,
		           p_po_line_id       IN NUMBER,
		           p_po_line_loc_id   IN NUMBER,
		           p_po_release_id    IN NUMBER,
		           p_user_id          IN NUMBER,
		           p_login_id         IN NUMBER,
		           p_error_code       OUT NUMBER,
		           p_error_desc       OUT NUMBER) IS
  BEGIN
  
    INSERT INTO xxpo_shipments_status_temp
      (update_id,
       po_header_id,
       po_number,
       po_release_id,
       release_number,
       revision_number,
       rel_revision_num,
       po_line_id,
       line_number,
       po_line_location_id,
       shipment_number,
       new_promised_date,
       buyer_name,
       last_update_date,
       last_updated_by,
       last_update_login,
       creation_date,
       created_by)
    VALUES
      (p_update_id,
       p_po_header_id,
       p_po_number,
       p_po_release_id,
       p_release_number,
       p_rel_revision_num,
       p_revision_number,
       p_po_line_id,
       p_line_number,
       p_po_line_loc_id,
       p_shipment_number,
       p_new_promise_date,
       p_buyer_name,
       SYSDATE,
       p_user_id,
       p_login_id,
       SYSDATE,
       p_user_id);
  
    p_error_code := 0;
    p_error_desc := NULL;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'Faile to insert row at insert_into_temp_table procedure - ' ||
	          SQLCODE || ' - ' || SQLERRM;
  END insert_into_temp_table;

  --------------------------------------------------------------------
  --  Name      :        get_hold_period
  --  Created By:        yuval 
  --  Revision:          1.0
  --  Creation Date:     8.5.17
  --------------------------------------------------------------------
  --  Purpose :          CHG0040670
  --                     Tracking Hold Acceptences Calc hold time for location 
  --------------------------------------------------------------------
  --  Ver  Date               Name                         Desc
  --  1.0  23-Apr-2017        yuval tal                    CHG0040670 Tracking Hold Acceptences
  --------------------------------------------------------------------

  FUNCTION get_hold_period(p_location_id NUMBER) RETURN NUMBER IS
  
    l_hold_days NUMBER;
  BEGIN
  
    SELECT --xx.*,
     SUM(round(end_date - start_date, 3)) hold_days
    INTO   l_hold_days
    FROM   (SELECT xx,
	       line_location_id,
	       last_shipment_acceptence,
	       (SELECT 'Y'
	        FROM   fnd_lookup_types_vl  flt,
		   fnd_lookup_values_vl flv
	        WHERE  flt.lookup_type = flv.lookup_type
	        AND    flt.lookup_type = 'ACCEPTANCE TYPE'
	        AND    flv.attribute1 = 'Y'
	        AND    flv.lookup_code = last_shipment_acceptence) hold_flag,
	       start_date,
	       lead(start_date, 1, SYSDATE) over(PARTITION BY line_location_id ORDER BY to_number(line_location_id), start_date) AS end_date
	FROM   (SELECT '1' xx,
		   table_key line_location_id,
		   new_value last_shipment_acceptence,
		   creation_date start_date,
		   creation_date
	        FROM   xxssys_table_audit
	        WHERE  table_name = 'PO_LINE_LOCATIONS_ALL'
	        AND    column_name = 'ATTRIBUTE8'
	        AND    table_key = to_char(p_location_id)
	        
	        )) xx
    WHERE  hold_flag = 'Y';
  
    RETURN l_hold_days;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN - 1;
    
  END;

END xxpo_shipments_status_pkg;
/
