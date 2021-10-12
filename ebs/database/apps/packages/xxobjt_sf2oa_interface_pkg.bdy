create or replace package body xxobjt_sf2oa_interface_pkg IS

  --------------------------------------------------------------------
  --  name:            XXOBJT_SF2OA_INTERFACE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        CUST352 - Oracle Interface with SFDC
  --                   This package Handle all procedure that get data
  --                   data from SF and pass it to Oracle.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --  1.1  26/10/2010  Dalit A. Raviv    add sf_fax number option for contact ins/upd
  --  1.2  24/11/2010  Dalit A. Raviv    1) create_code_assignment_api - when api finished
  --                                        with error table will update with warning and not error
  --                                     2) create_account_api - update party attribute3 with Sales_Territory__c (from sf)
  --                                     3) create_location_api - add validation on state only
  --                                        when territory_code is US.
  --  1.3  05/12/2010  Dalit A. Raviv    l_state was to short. update_location_api/ create_location_api
  --  1.4  21/12/2010  Dalit A. Raviv    procedure -> create_party_site_api.
  --                                     t_cust_site_use_rec.location have only 40 char
  --                                     the data we send is bigger - p_party_name || ' - ' ||l_location_s
  --                                     solution to sorten p_party_name to 30 char
  --  1.5  02/01/2010  Dalit A. Raviv    Procedure create_party_site_api:
  --                                     change party_site_name from country to party_name
  --  1.6  15/04/2012  Dalit A. Raviv    There is a problem that new job_title at SF did not enter
  --                                     to lookup 'RESPONSIBILITY'. this cause that person do create at
  --                                     oracle but because of the job title error SF do not update with oracle_id
  --                                     and therefor continue sending (and creating) each hour the same data
  --                                     to update oracle. the solution is to mark the row as OA_WARNING
  --                                     and oracle_id istead of OA_ERR.
  --                                     1) add global variable g_job_title
  --                                     2) init and call this global from procedure create_org_contact_api
  --                                     3) refer to this global at procedure create_new_contact.
  --  1.7  18/07/2012  Dalit A. Raviv    add procedure purge_log_tables
  --  1.8  16/10/2012  Dalit A. Raviv    add function get_sf_id_exist and call it from several places.
  --                                     CUST352 1.8 CR-503 Oracle Interface with SFDC -Prevent duplications from SFDC
  --  1.9  31/10/2012  Dalit A. Raviv    add handle of rollback (create_new_contact, handle_sites_in_oracle)
  --  2.0  11/05/2014  yuval tal         CHG0031508 modify main - insert line into oa2sf interfcae table for id's sync
  --                                      modify call_bpel_process
  -- 2.1   04/05/2016 yuval tal           CHG0037918 migration to 12c support redirect between 2 servers
  --                                      modify proc call_bpel_process
  -- 2.2   22.6.16   yuval tal            CHG0038819  : change logic check_sf_exists/purge_log_tables
  --                                      change get_sf_id_exist
  --                                      modify handle_accounts_in_oracle/handle_sites_in_oracle/handle_contacts_in_oracle
  --                                      use exists oracle id in case found and update success instead of err
  --  2.3   15.8.2016    yuval tal        INC0066076  modify update_location : check no need to update location
  -- 2.4   11.9.16      yuval tal         INC0076039 modify update_new_contact /update_contact_point_api disable phone updates
  -- 2.5   04.03.19     Lingaraj          INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
  --------------------------------------------------------------------

  g_user_id NUMBER;
  --g_org_id       NUMBER;
  g_num_of_api_e NUMBER := 0;
  g_num_of_api_s NUMBER := 0;
  g_create_by_module CONSTANT VARCHAR2(20) := 'SALESFORCE'; -- SALESFORCE
  g_remove_ns_xsl xmltype := xmltype('<?xml version="1.0" encoding="UTF-8" ?><xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"><xsl:template match="comment()|processing-instruction()|/"><xsl:copy><xsl:apply-templates/></xsl:copy></xsl:template><xsl:template match="*"><xsl:element name="{local-name()}"><xsl:apply-templates select="@*|node()"/></xsl:element></xsl:template><xsl:template match="@*"><xsl:choose><xsl:when test="name() != ''xmlns''"><xsl:attribute name="{local-name()}"><xsl:value-of select="."/></xsl:attribute></xsl:when></xsl:choose></xsl:template></xsl:stylesheet>');
  -- g_blat_xmlns CONSTANT VARCHAR2(250) := 'xmlns="http://soap.sforce.com/schemas/class/ServiceAccountWS"';
  -- 1.6  15/04/2012  Dalit A. Raviv
  g_job_title VARCHAR2(10);
  --
  --------------------------------------------------------------------
  --  name:            string_to_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/09/2010
  --------------------------------------------------------------------
  --  purpose :        function that convert strinf into date
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/09/2010  Yuval Tal         initial build
  --------------------------------------------------------------------
  FUNCTION string_to_date(p_string IN VARCHAR2) RETURN DATE IS
    l_date DATE := NULL;
  BEGIN
    SELECT to_date(p_string,
	       fnd_profile.value('XXOBJT_SF2OA_DATE_FORMAT_MASK'))
    INTO   l_date
    FROM   dual;

    RETURN l_date;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END string_to_date;

  --------------------------------------------------------------------
  --  name:            remove_xmlns
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   19/09/2010
  --------------------------------------------------------------------
  --  purpose :        xml transform - take out the xmlns (name space)
  --                   out of an xmltype.
  --                   return xmltype without name space.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/09/2010  Yuval Tal         initial build
  --------------------------------------------------------------------
  FUNCTION remove_xmlns(p_xml xmltype) RETURN xmltype IS
    l_xml xmltype;
  BEGIN

    SELECT xmltransform(p_xml, g_remove_ns_xsl)
    INTO   l_xml
    FROM   dual;

    RETURN l_xml;

  END;

  --------------------------------------------------------------------
  --  name:            get_cust_account_id_by_sf_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Function - get SF_ID and return oracle cust_account_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_cust_account_id_by_sf_id(p_sf_id IN VARCHAR2) RETURN NUMBER IS
    l_cust_account_id NUMBER := NULL;
  BEGIN
    SELECT hca.cust_account_id
    INTO   l_cust_account_id
    FROM   hz_cust_accounts hca
    WHERE  hca.attribute4 = p_sf_id;

    RETURN l_cust_account_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_cust_account_id_by_sf_id;

  --------------------------------------------------------------------
  --  name:            set_SALESFORCE_user
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Set global variable User id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE set_salesforce_user IS

  BEGIN
    IF g_user_id IS NULL THEN
      SELECT user_id
      INTO   g_user_id
      FROM   fnd_user
      WHERE  user_name = 'SALESFORCE';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      g_user_id := -1;
  END set_salesforce_user;

  --------------------------------------------------------------------
  --  name:            insert_into_header
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that insert row to interface header tbl
  --                   at the begining of the process.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE insert_into_header(p_source_name IN VARCHAR2,
		       p_batch_id    OUT NUMBER,
		       p_err_code    OUT VARCHAR2,
		       p_err_msg     OUT VARCHAR2) IS

    PRAGMA AUTONOMOUS_TRANSACTION;
    l_batch_id NUMBER;
  BEGIN
    -- get batch id
    SELECT xxobjt_oa2sf_interface_bid_s.nextval
    INTO   l_batch_id
    FROM   dual;

    INSERT INTO xxobjt_sf2oa_interface_h
      (oracle_batch_id,
       bpel_instance_id,
       source_name,
       sf_response, --       xmltype,
       oa_err_code,
       oa_err_msg,
       last_update_date,
       last_updated_by,
       last_update_login,
       creation_date,
       created_by)
    VALUES
      (l_batch_id,
       NULL,
       p_source_name,
       NULL,
       NULL,
       NULL,
       SYSDATE,
       g_user_id,
       -1,
       SYSDATE,
       g_user_id);
    COMMIT;
    p_err_code := 0;
    p_err_msg  := NULL;
    p_batch_id := l_batch_id;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - insert_into_header - p_batch_id - ' ||
	        p_batch_id || ' - ' || substr(SQLERRM, 1, 240);

  END insert_into_header;

  --------------------------------------------------------------------
  --  name:            update_sf_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update interface line tbl
  --                   with the sf_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_sf_id(p_sf_id           IN VARCHAR2,
		 p_oracle_event_id IN NUMBER,
		 p_err_msg         OUT VARCHAR2,
		 p_err_code        OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    UPDATE xxobjt_sf2oa_interface_l l
    SET    l.last_update_date = SYSDATE,
           l.sf_id            = p_sf_id
    WHERE  l.oracle_event_id = p_oracle_event_id;
    COMMIT;
    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_sf_id - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
  END;

  --------------------------------------------------------------------
  --  name:            update_sf_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update interface line tbl
  --                   with the sf_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/09/2010  Dalit A. Raviv    initial build
  --  1.1 21.3.16      yuval tal         CHG0038819  if xml is identical to previous xml then there is nothing to do
  --------------------------------------------------------------------
  PROCEDURE update_sf_exist(p_sf_id           IN VARCHAR2,
		    p_oracle_event_id IN NUMBER,
		    p_err_msg         OUT VARCHAR2,
		    p_err_code        OUT VARCHAR2) IS

    --PRAGMA AUTONOMOUS_TRANSACTION;

    l_count               NUMBER := 0;
    l_days                NUMBER := 0;
    l_clob_curr           CLOB;
    l_clob_pre            CLOB;
    l_pre_status          VARCHAR2(50);
    l_pre_date            DATE;
    l_pre_err_message     VARCHAR2(2500);
    l_least_creation_date DATE;
    CURSOR c IS
      SELECT *
      FROM   (SELECT t.rec_xml.getclobval() xml_clob,
	         creation_date,
	         oa_err_msg,
	         status,
	         row_number() over(PARTITION BY sf_id ORDER BY t.creation_date DESC) x_rownum
	  FROM   xxobjt_sf2oa_interface_l t
	  WHERE  t.sf_id = p_sf_id)
      WHERE  x_rownum IN (1, 2);
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
    -- check last xml for the same sf_id is different otherwise  hold

    l_days := nvl(fnd_profile.value('XXOBJT_OA2SF_NUM_OF_DAYS_ERR'), 5); -- 5
    -- check if sf_id exists in interface with status OA_ERR

    FOR i IN c LOOP

      IF i.x_rownum = 1 THEN
        -- latest record
        l_clob_curr := i.xml_clob;
      ELSE
        l_clob_pre        := i.xml_clob;
        l_pre_status      := i.status;
        l_pre_date        := i.creation_date;
        l_pre_err_message := i.oa_err_msg;
      END IF;

    END LOOP;
    -- dbms_output.put_line('l_pre_status= ' || l_pre_status || ' l_days=' ||
    --    l_days);
    -- check first try
    IF l_pre_status IS NULL THEN
      dbms_output.put_line('process1 ');
      RETURN;
    END IF;

    -- if identical and previous status is not success then
    IF dbms_lob.compare(nvl(l_clob_curr, 'null'), nvl(l_clob_pre, 'null')) = 0 AND
       l_pre_status IN ('OA_ERR', 'OA_HOLD') AND
       instr(l_pre_err_message, 'Location Api Err') > 0 THEN

      -- get oldest records date for sf_id to check interval between
      /*    BEGIN
        SELECT creation_date
        INTO   l_least_creation_date
        FROM   (SELECT t.rec_xml.getclobval() xml_clob,
                       creation_date,
                       status,
                       row_number() over(PARTITION BY sf_id ORDER BY t.creation_date ASC) x_rownum
                FROM   xxobjt_sf2oa_interface_l t
                WHERE  t.sf_id = p_sf_id
                AND    t.oracle_event_id != p_oracle_event_id)
        WHERE  x_rownum = 1;

        -- check interval for retry if oldest record created more than X days ago

        IF SYSDATE - l_least_creation_date > l_days THEN
          dbms_output.put_line('process11 ');
          RETURN;
        END IF;

      EXCEPTION
        WHEN no_data_found THEN
          RETURN; -- process order , no older record found
      END;*/

      -- update to hold , so no process wil be made
      UPDATE xxobjt_sf2oa_interface_l l
      SET    l.last_update_date = SYSDATE,
	 l.status           = 'OA_HOLD'
      WHERE  l.oracle_event_id = p_oracle_event_id;
      dbms_output.put_line('skip ');
      COMMIT;
    ELSE
      dbms_output.put_line('process ');
    END IF;

    /*  SELECT COUNT(1)
    INTO   l_count
    FROM   xxobjt_sf2oa_interface_l l
    WHERE  l.oracle_event_id <> p_oracle_event_id
    AND    l.sf_id = p_sf_id
          -- AND    l.oa_err_code = 0 -- yuval avalara
    AND    l.status IN ('OA_ERR', 'OA_HOLD', 'SF_ERR')
    AND    l.creation_date > SYSDATE - l_days; --5

    IF l_count > 0 THEN
      UPDATE xxobjt_sf2oa_interface_l l
      SET    l.last_update_date = SYSDATE,
             l.status           = 'OA_HOLD'
      WHERE  l.oracle_event_id = p_oracle_event_id;
      COMMIT;

    END IF;*/
    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_sf_id - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
  END update_sf_exist;

  --------------------------------------------------------------------
  --  name:            update_interface_line_error
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update interface line tbl
  --                   with the error status of the record (API)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_interface_line_error(p_status          IN VARCHAR2,
			    p_oracle_event_id IN NUMBER,
			    p_err_msg         IN OUT VARCHAR2,
			    p_err_code        OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_count NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
    INTO   l_count
    FROM   xxobjt_sf2oa_interface_l l
    WHERE  l.oracle_event_id = p_oracle_event_id
    AND    l.oa_err_msg IS NOT NULL;

    UPDATE xxobjt_sf2oa_interface_l l
    SET    l.oa_err_code      = 1,
           l.oa_err_msg       = decode(l_count,
			   0,
			   p_err_msg,
			   substr(l.oa_err_msg || chr(10) ||
			          p_err_msg,
			          1,
			          2500)),
           l.last_update_date = SYSDATE,
           l.status           = decode(l_count, 0, p_status, 'OA_WARNING') --'OA_ERR'
    WHERE  l.oracle_event_id = p_oracle_event_id;
    COMMIT;

    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_interface_line_error - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
  END update_interface_line_error;

  --------------------------------------------------------------------
  --  name:            update_interface_line_status
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update interface line tbl
  --                   with the status of the record (API)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_interface_line_status(p_status          IN VARCHAR2,
			     p_oracle_id       IN NUMBER,
			     p_sf_id           IN VARCHAR2,
			     p_oracle_event_id IN NUMBER,
			     p_entity          IN VARCHAR2 DEFAULT 'INSERT',
			     p_msg             IN VARCHAR2 DEFAULT NULL,
			     p_err_code        OUT VARCHAR2,
			     p_err_msg         OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_count NUMBER := 0;
  BEGIN
    IF nvl(p_entity, 'INSERT') = 'INSERT' THEN
      UPDATE xxobjt_sf2oa_interface_l l
      SET    l.last_update_date = SYSDATE,
	 l.status           = p_status, --'OA_SUCCESS',
	 l.oa_err_code      = 0,
	 l.sf_id            = p_sf_id,
	 l.oracle_id        = p_oracle_id
      WHERE  l.oracle_event_id = p_oracle_event_id;
    ELSE
      -- in Update mode the OA_err_msg field get msg from 4 API's
      -- all 4 API's will write to the interface log table.
      -- check if the line have message allready
      -- if yes so concatenate the new message with line break
      -- if no update new message only
      SELECT COUNT(1)
      INTO   l_count
      FROM   xxobjt_sf2oa_interface_l l
      WHERE  l.oracle_event_id = p_oracle_event_id
      AND    l.oa_err_msg IS NOT NULL;

      UPDATE xxobjt_sf2oa_interface_l l
      SET    l.last_update_date = SYSDATE,
	 l.status           = decode(l_count, 0, p_status, 'OA_WARNING'), --'OA_SUCCESS',
	 l.oa_err_code      = 0,
	 l.oa_err_msg       = decode(l_count,
			     0,
			     p_msg,
			     l.oa_err_msg || chr(10) || p_msg),
	 l.sf_id            = p_sf_id,
	 l.oracle_id        = p_oracle_id
      WHERE  l.oracle_event_id = p_oracle_event_id;
    END IF;
    COMMIT;
    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_interface_line_status - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
  END update_interface_line_status;

  --------------------------------------------------------------------
  --  name:            update_SF_header_xml_Data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update interface header tbl
  --                   with the respond xml, ans source_name, and bpel_instance_id
  --                   by batch_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_sf_header_xml_data(p_batch_id    IN NUMBER,
			  p_bpel_id     IN NUMBER,
			  p_respond     IN xmltype,
			  p_source_name IN VARCHAR2,
			  p_err_code    OUT VARCHAR2,
			  p_err_msg     OUT VARCHAR2) IS

  BEGIN
    -- set g_user_id SALESFORCE User
    set_salesforce_user;

    UPDATE xxobjt_sf2oa_interface_h xsoih
    SET    xsoih.bpel_instance_id = p_bpel_id,
           xsoih.sf_response      = p_respond,
           xsoih.source_name      = p_source_name,
           xsoih.last_update_date = SYSDATE,
           xsoih.last_updated_by  = g_user_id
    WHERE  xsoih.oracle_batch_id = p_batch_id;

    COMMIT;

    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_SF_header_xml_Data - p_batch_id - ' ||
	        p_batch_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - update_SF_header_xml_Data - ' ||
		   substr(SQLERRM, 1, 240));
      BEGIN
        UPDATE xxobjt_sf2oa_interface_h xsoih
        SET    xsoih.oa_err_code = 1,
	   xsoih.oa_err_msg  = 'Update SF header xml Data Failed '
        WHERE  xsoih.oracle_batch_id = p_batch_id;

        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
  END update_sf_header_xml_data;

  --------------------------------------------------------------------
  --  name:            insert_SF_line_xml_Data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that insert new rows to interface line tbl
  --                   with the respond xml, ans source_name, and bpel_instance_id
  --                   by batch_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE insert_sf_line_xml_data(p_batch_id    IN NUMBER,
			p_source_name OUT VARCHAR2,
			p_err_code    OUT VARCHAR2,
			p_err_msg     OUT VARCHAR2) IS

    CURSOR xml_parse_c(p_respond IN xmltype,
	           p_extract IN VARCHAR2) IS
      SELECT *
      FROM   TABLE(xmlsequence(extract(p_respond, p_extract))) xml;

    l_respond     xmltype;
    l_source_name VARCHAR2(250) := NULL;
    l_extract     VARCHAR2(250) := NULL;
  BEGIN
    --<GetAllAccountsResponse xmlns="http://soap.sforce.com/schemas/class/ServiceAccountWS">
    --<GetAllSitesResponse xmlns="http://soap.sforce.com/schemas/class/ServiceAccountWS">
    --<GetAllContactsResponse xmlns="http://soap.sforce.com/schemas/class/ServiceAccountWS">
    -- set g_user_id SALESFORCE User
    set_salesforce_user;

    SELECT h.sf_response,
           h.source_name
    INTO   l_respond,
           l_source_name
    FROM   xxobjt_sf2oa_interface_h h
    WHERE  h.oracle_batch_id = p_batch_id;

    IF l_source_name = 'ACCOUNT' THEN
      l_extract := '/GetAllAccountsResponse/result';
    ELSIF l_source_name = 'SITE' THEN
      l_extract := '/GetAllSitesResponse/result';
    ELSIF l_source_name = 'CONTACT' THEN
      l_extract := '/GetAllContactsResponse/result';
    END IF;

    FOR xml_parse_r IN xml_parse_c(l_respond, l_extract) LOOP

      INSERT INTO xxobjt_sf2oa_interface_l
        (oracle_event_id,
         oracle_batch_id,
         status,
         rec_xml,
         last_update_date,
         last_updated_by,
         last_update_login,
         creation_date,
         created_by)
      VALUES
        (xxobjt_oa2sf_interface_id_s.nextval,
         p_batch_id,
         'NEW',
         xml_parse_r.column_value,
         SYSDATE,
         g_user_id,
         -1,
         SYSDATE,
         g_user_id);
    END LOOP;

    COMMIT;
    p_source_name := l_source_name;
    p_err_code    := 0;
    p_err_msg     := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - insert_SF_line_xml_Data - p_batch_id - ' ||
	        p_batch_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - insert_SF_line_xml_Data - ' ||
		   substr(SQLERRM, 1, 240));

      BEGIN
        UPDATE xxobjt_sf2oa_interface_h xsoih
        SET    xsoih.oa_err_code = 1,
	   xsoih.oa_err_msg  = 'Insert SF line xml Data '
        WHERE  xsoih.oracle_batch_id = p_batch_id;

        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
  END insert_sf_line_xml_data;

  --------------------------------------------------------------------
  --  name:            create_account_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create account API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --  1.1  28/11/2010  Dalit A. raviv    update party attribute3 with Sales_Territory__c (from sf)
  --------------------------------------------------------------------
  PROCEDURE create_account_api(p_oracle_event_id  IN NUMBER,
		       p_sales_channel_id IN VARCHAR2,
		       p_account_name     IN VARCHAR2,
		       p_sf_account_id    IN VARCHAR2,
		       p_org_id           IN VARCHAR2,
		       p_cust_account_id  OUT NUMBER,
		       p_party_id         OUT NUMBER,
		       p_err_code         OUT VARCHAR2,
		       p_err_msg          OUT VARCHAR2) IS

    l_party_number      VARCHAR2(30);
    l_category_code     VARCHAR2(150);
    l_sales_chanel_code VARCHAR2(150);
    l_account_number    NUMBER;
    l_cust_account_id   NUMBER;
    l_party_id          NUMBER;
    l_profile_id        NUMBER;
    l_return_status     VARCHAR2(1);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2000);
    l_data              VARCHAR2(2000);
    l_msg_index_out     NUMBER;
    l_org_id            NUMBER;

    t_cust_account_rec     hz_cust_account_v2pub.cust_account_rec_type;
    t_organization_rec     hz_party_v2pub.organization_rec_type;
    t_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;

    l_err_msg  VARCHAR2(2500) := NULL;
    l_err_code VARCHAR2(10) := 10;
    invalid_customer EXCEPTION;

  BEGIN
    fnd_msg_pub.initialize;
    l_party_id          := NULL;
    l_cust_account_id   := NULL;
    l_category_code     := NULL;
    l_sales_chanel_code := NULL;

    BEGIN
      -- Get sales_chanel_code and category_code
      -- Category code can be - Direct / InDirect / Distributor
      -- Sales chanel code can be - DIRECT / INDIRECT (Distributor is an Indirect)
      SELECT decode(flv.lookup_code,
	        'DIRECT',
	        'CUSTOMER',
	        'INDIRECT',
	        'END CUSTOMER',
	        'DISTRIBUTOR'),
	 decode(flv.lookup_code, 'DIRECT', 'DIRECT', 'INDIRECT')
      INTO   l_category_code,
	 l_sales_chanel_code
      FROM   fnd_lookup_values flv
      WHERE  flv.lookup_type = 'XX_SF_CHANNEL_CODES'
      AND    flv.enabled_flag = 'Y'
      AND    flv.end_date_active IS NULL
      AND    flv.language = 'US'
      AND    flv.description = p_sales_channel_id;

    EXCEPTION
      WHEN OTHERS THEN
        l_category_code     := NULL;
        l_sales_chanel_code := NULL;
    END;
    -- get org id
    BEGIN
      SELECT ffv.flex_value ou_id
      INTO   l_org_id
      FROM   fnd_flex_values     ffv,
	 fnd_flex_value_sets ffvs,
	 fnd_flex_values_tl  ffvt
      WHERE  ffv.flex_value_set_id = ffvs.flex_value_set_id
      AND    ffvs.flex_value_set_name = 'XXOBJT_SF_SALES_TERRITORY'
      AND    ffv.flex_value_id = ffvt.flex_value_id
      AND    ffvt.language = 'US'
      AND    ffvt.description = p_org_id; --Sales_Territory__c from SF
    EXCEPTION
      WHEN OTHERS THEN
        l_org_id := NULL;
    END;

    -- get account Syquence
    --SELECT hz_cust_accounts_s.NEXTVAL INTO l_account_number FROM dual;

    t_cust_account_rec.account_name         := p_account_name;
    t_cust_account_rec.date_type_preference := 'ARRIVAL';
    --t_cust_account_rec.account_number       := l_account_number;
    t_cust_account_rec.sales_channel_code := l_sales_chanel_code;
    t_cust_account_rec.created_by_module  := g_create_by_module; --'SALESFORCE';
    t_cust_account_rec.attribute4         := p_sf_account_id;

    t_organization_rec.organization_name          := p_account_name;
    t_organization_rec.created_by_module          := g_create_by_module; --'SALESFORCE';
    t_organization_rec.organization_name_phonetic := p_account_name;
    t_organization_rec.organization_type          := 'ORGANIZATION';
    t_organization_rec.party_rec.category_code    := l_category_code;
    t_organization_rec.party_rec.attribute3       := l_org_id;

    hz_cust_account_v2pub.create_cust_account(p_init_msg_list        => 'T',
			          p_cust_account_rec     => t_cust_account_rec,
			          p_organization_rec     => t_organization_rec,
			          p_customer_profile_rec => t_customer_profile_rec,
			          p_create_profile_amt   => 'F',
			          x_cust_account_id      => l_cust_account_id, -- o nocopy n
			          x_account_number       => l_account_number, -- o nocopy v
			          x_party_id             => l_party_id, -- o nocopy n
			          x_party_number         => l_party_number, -- o nocopy v
			          x_profile_id           => l_profile_id, -- o nocopy n
			          x_return_status        => l_return_status, -- o nocopy v
			          x_msg_count            => l_msg_count, -- o nocopy n
			          x_msg_data             => l_msg_data); -- o nocopy v
    -- if api failed - 1) write to log errors
    --                 2) update interface line table with errors.
    --                 3) rollback
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg  := 'Error create account: ';
      p_err_code := '1';
      fnd_file.put_line(fnd_file.log,
		'Creation of Customer' ||
		t_cust_account_rec.account_name || ' is failed.');
      fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;

      ROLLBACK;
      l_err_msg := substr(p_err_msg, 1, 2000);
      update_interface_line_error(p_status          => 'OA_ERR',
		          p_oracle_event_id => p_oracle_event_id,
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code);

      p_cust_account_id := NULL;
      p_party_id        := NULL;
      p_err_code        := '1';
      -- if api success - 1) update interface line table with success.
      --                  2) commit
    ELSE
      COMMIT;
      p_cust_account_id := l_cust_account_id;
      p_party_id        := l_party_id;
      p_err_code        := '0';
      p_err_msg         := NULL;

      /*update_interface_line_status(p_status          => 'OA_SUCCESS',
                                   p_oracle_id       => l_cust_account_id,
                                   p_sf_id           => p_sf_account_id,
                                   p_oracle_event_id => p_oracle_event_id,
                                   p_err_code        => l_err_code,
                                   p_err_msg         => l_err_msg);
      */
      BEGIN
        UPDATE xxobjt_sf2oa_interface_l l
        SET    l.status           = 'OA_SUCCESS',
	   l.sf_id            = p_sf_account_id,
	   l.oracle_id        = l_cust_account_id,
	   l.oa_err_code      = '0',
	   l.oa_err_msg       = NULL,
	   l.last_update_date = SYSDATE
        WHERE  l.oracle_event_id = p_oracle_event_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF; -- return status

  END create_account_api;

  --------------------------------------------------------------------
  --  name:            create_code_assignment_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create code assignment API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --  1.1  24/11/2010  Dalit A. Raviv    when api finished with error table
  --                                     will update with warning and not error
  --------------------------------------------------------------------
  PROCEDURE create_code_assignment_api(p_oracle_event_id    IN NUMBER,
			   p_industry           IN VARCHAR2,
			   p_party_id           IN NUMBER,
			   p_account_name       IN VARCHAR2,
			   p_code_assignment_id OUT NUMBER,
			   p_err_code           OUT VARCHAR2,
			   p_err_msg            OUT VARCHAR2) IS

    l_class_code          VARCHAR2(150) := NULL;
    l_code_assignment_id  NUMBER := NULL;
    l_return_status       VARCHAR2(1);
    l_msg_count           NUMBER;
    l_msg_data            VARCHAR2(2000);
    l_data                VARCHAR2(2000);
    l_msg_index_out       NUMBER;
    t_code_assignment_rec hz_classification_v2pub.code_assignment_rec_type;
    l_err_msg             VARCHAR2(2500) := NULL;
    l_err_code            VARCHAR2(10) := 0;
  BEGIN
    fnd_msg_pub.initialize;

    SELECT lookup_code
    INTO   l_class_code
    FROM   ar_lookups t
    WHERE  lookup_type = 'Objet Business Type'
    AND    SYSDATE BETWEEN trunc(t.start_date_active) AND
           nvl(t.end_date_active, SYSDATE + 1)
    AND    t.enabled_flag = 'Y'
    AND    upper(description) = upper(ltrim(rtrim(p_industry)));

    t_code_assignment_rec.owner_table_name      := 'HZ_PARTIES';
    t_code_assignment_rec.owner_table_id        := p_party_id;
    t_code_assignment_rec.class_category        := 'Objet Business Type';
    t_code_assignment_rec.class_code            := l_class_code;
    t_code_assignment_rec.primary_flag          := 'N';
    t_code_assignment_rec.content_source_type   := 'USER_ENTERED';
    t_code_assignment_rec.start_date_active     := SYSDATE;
    t_code_assignment_rec.status                := 'A';
    t_code_assignment_rec.created_by_module     := g_create_by_module; --'SALESFORCE';
    t_code_assignment_rec.actual_content_source := 'USER_ENTERED';

    hz_classification_v2pub.create_code_assignment(p_init_msg_list       => fnd_api.g_true,
				   p_code_assignment_rec => t_code_assignment_rec,
				   x_return_status       => l_return_status,
				   x_msg_count           => l_msg_count,
				   x_msg_data            => l_msg_data,
				   x_code_assignment_id  => l_code_assignment_id);
    IF l_return_status <> fnd_api.g_ret_sts_success THEN

      p_err_msg := 'Error create code assignment: ';

      fnd_file.put_line(fnd_file.log,
		'Creation of Customer' || p_account_name ||
		' is failed.');
      fnd_file.put_line(fnd_file.log,
		'x_msg_count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);

        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2500);
      END LOOP;
      -- set out param
      p_code_assignment_id := NULL;
      p_err_code           := '1';
      -- update interface line with error only because the account did created.
      ROLLBACK;
      l_err_msg := substr(p_err_msg, 1, 2000);
      update_interface_line_error(p_status          => 'OA_WARNING',
		          p_oracle_event_id => p_oracle_event_id,
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code);
    ELSE
      p_code_assignment_id := l_code_assignment_id;
      p_err_code           := '0';
      p_err_msg            := NULL;
      COMMIT;
    END IF; -- api return status
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'invalid business type :' || p_industry;
      l_err_msg  := 'invalid business type :' || p_industry;
      update_interface_line_error(p_status          => 'OA_WARNING',
		          p_oracle_event_id => p_oracle_event_id,
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code);
  END create_code_assignment_api;

  --------------------------------------------------------------------
  --  name:            handle_api_status_return
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that handle API return error/ success
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_api_status_return(p_return_status   IN VARCHAR2,
			 p_msg_count       IN NUMBER,
			 p_oracle_event_id IN NUMBER,
			 p_msg_data        IN VARCHAR2,
			 p_entity          IN VARCHAR2,
			 p_entity_main     IN VARCHAR2,
			 p_err_code        OUT VARCHAR2,
			 p_err_msg         OUT VARCHAR2) IS
    l_data          VARCHAR2(2500) := NULL;
    l_msg_index_out NUMBER;
    l_err_msg       VARCHAR2(2500) := NULL;
    l_err_code      VARCHAR2(10) := NULL;
  BEGIN

    IF p_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Failed to create_contact_point - ' || p_entity || ' - ';
      fnd_file.put_line(fnd_file.log, 'x_msg_data = ' || p_msg_data);
      fnd_file.put_line(fnd_file.log,
		'Failed to create_contact_point - ' || p_entity);
      IF p_msg_count > 1 THEN
        FOR i IN 1 .. p_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);

          p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2500);
        END LOOP;
      END IF;

      fnd_file.put_line(fnd_file.log, 'l_msg_data      - ' || p_err_msg);
      ROLLBACK;
      -- update interface line with error only because the account did created.
      IF nvl(p_entity_main, 'INSERT') = 'INSERT' THEN
        l_err_msg := substr(p_err_msg, 1, 2000);
        update_interface_line_error(p_status          => 'OA_WARNING',
			p_oracle_event_id => p_oracle_event_id,
			p_err_msg         => l_err_msg,
			p_err_code        => l_err_code);
      END IF;
      p_err_code := '1';
    ELSE
      COMMIT;
      p_err_code := '0';
      p_err_msg  := NULL;
    END IF; --l_return_status
  END handle_api_status_return;

  --------------------------------------------------------------------
  --  name:            create_contact_point_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create create_contact_point API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_contact_point_api(p_oracle_event_id  IN NUMBER,
			 p_party_id         IN NUMBER,
			 p_phone_number     IN VARCHAR2,
			 p_fax_number       IN VARCHAR2,
			 p_url              IN VARCHAR2,
			 p_mobile_phone     IN VARCHAR2,
			 p_email            IN VARCHAR2,
			 p_entity           IN VARCHAR2 DEFAULT 'INSERT',
			 p_contact_point_id OUT NUMBER,
			 p_err_code         OUT VARCHAR2,
			 p_err_msg          OUT VARCHAR2) IS

    -- Contact points
    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    --l_edi_rec           hz_contact_point_v2pub.edi_rec_type;
    l_email_rec hz_contact_point_v2pub.email_rec_type;
    l_phone_rec hz_contact_point_v2pub.phone_rec_type;
    --l_telex_rec         hz_contact_point_v2pub.telex_rec_type;
    l_web_rec          hz_contact_point_v2pub.web_rec_type;
    l_contact_point_id NUMBER := NULL;
    l_return_status    VARCHAR2(2000) := NULL;
    l_msg_count        NUMBER := NULL;
    l_msg_data         VARCHAR2(2000) := NULL;

  BEGIN
    fnd_msg_pub.initialize;
    p_err_code := 0;
    p_err_msg  := NULL;

    -- each point type have different variable that creates the point
    -- l_contact_point_rec.owner_table_id => l_party_rel_id  is
    -- the party_id from hz_parties that is from type PARTY_RELATIONSHIP (CONT_REL_PARTY_ID)
    l_contact_point_rec.owner_table_name  := 'HZ_PARTIES';
    l_contact_point_rec.owner_table_id    := p_party_id; --'5151403';
    l_contact_point_rec.primary_flag      := 'Y';
    l_contact_point_rec.created_by_module := g_create_by_module; --'SALESFORCE';
    IF p_phone_number IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_phone_number;
      l_phone_rec.phone_line_type            := 'GEN';

      hz_contact_point_v2pub.create_phone_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec => l_contact_point_rec,
				        p_phone_rec         => l_phone_rec,
				        x_contact_point_id  => l_contact_point_id, -- o n
				        x_return_status     => l_return_status, -- o v
				        x_msg_count         => l_msg_count, -- o n
				        x_msg_data          => l_msg_data); -- o v

      handle_api_status_return(p_return_status   => l_return_status, -- o v
		       p_msg_count       => l_msg_count, -- o n
		       p_oracle_event_id => p_oracle_event_id, -- i n
		       p_msg_data        => l_msg_data, -- i v
		       p_entity          => 'PHONE_NUMBER', -- i v
		       p_entity_main     => p_entity,
		       p_err_code        => p_err_code, -- o v
		       p_err_msg         => p_err_msg); -- o v
      IF p_err_code = 1 THEN
        p_err_code := 1;
        p_err_msg  := p_err_msg ||
	          ' Failed to create Phone number - Party_id - ' ||
	          p_party_id || chr(10);
      END IF;
    END IF;
    IF p_fax_number IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Fax
      l_phone_rec.phone_number               := p_fax_number;
      l_phone_rec.phone_line_type            := 'FAX';

      hz_contact_point_v2pub.create_phone_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec => l_contact_point_rec,
				        p_phone_rec         => l_phone_rec,
				        x_contact_point_id  => l_contact_point_id, -- o n
				        x_return_status     => l_return_status, -- o v
				        x_msg_count         => l_msg_count, -- o n
				        x_msg_data          => l_msg_data); -- o v

      handle_api_status_return(p_return_status   => l_return_status, -- o v
		       p_msg_count       => l_msg_count, -- o n
		       p_oracle_event_id => p_oracle_event_id, -- i n
		       p_msg_data        => l_msg_data, -- i v
		       p_entity          => 'FAX_NUMBER', -- i v
		       p_entity_main     => p_entity,
		       p_err_code        => p_err_code, -- o v
		       p_err_msg         => p_err_msg); -- o v
      IF p_err_code = 1 THEN
        p_err_code := 1;
        p_err_msg  := p_err_msg ||
	          ' Failed to create Fax number - Party_id - ' ||
	          p_party_id || chr(10);
      END IF;
    END IF;
    IF p_mobile_phone IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_mobile_phone;
      l_phone_rec.phone_line_type            := 'MOBILE';

      hz_contact_point_v2pub.create_phone_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec => l_contact_point_rec,
				        p_phone_rec         => l_phone_rec,
				        x_contact_point_id  => l_contact_point_id, -- o n
				        x_return_status     => l_return_status, -- o v
				        x_msg_count         => l_msg_count, -- o n
				        x_msg_data          => l_msg_data); -- o v

      handle_api_status_return(p_return_status   => l_return_status, -- o v
		       p_msg_count       => l_msg_count, -- o n
		       p_oracle_event_id => p_oracle_event_id, -- i n
		       p_msg_data        => l_msg_data, -- i v
		       p_entity          => 'MOBILE_PHONE', -- i v
		       p_entity_main     => p_entity,
		       p_err_code        => p_err_code, -- o v
		       p_err_msg         => p_err_msg); -- o v
      IF p_err_code = 1 THEN
        p_err_code := 1;
        p_err_msg  := p_err_msg ||
	          ' Failed to create Mobile number - Party_id - ' ||
	          p_party_id || chr(10);
      END IF;
    END IF;
    IF p_url IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'WEB'; -- Web
      l_web_rec.web_type                     := 'HTML'; -- this is a stam value no validation
      l_web_rec.url                          := p_url;

      hz_contact_point_v2pub.create_web_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				      p_contact_point_rec => l_contact_point_rec,
				      p_web_rec           => l_web_rec,
				      x_contact_point_id  => l_contact_point_id, -- o n
				      x_return_status     => l_return_status, -- o v
				      x_msg_count         => l_msg_count, -- o n
				      x_msg_data          => l_msg_data); -- o v

      handle_api_status_return(p_return_status   => l_return_status, -- o v
		       p_msg_count       => l_msg_count, -- o n
		       p_oracle_event_id => p_oracle_event_id, -- i n
		       p_msg_data        => l_msg_data, -- i v
		       p_entity          => 'WEB_HTML', -- i v
		       p_entity_main     => p_entity,
		       p_err_code        => p_err_code, -- o v
		       p_err_msg         => p_err_msg); -- o v

      IF p_err_code = 1 THEN
        p_err_code := 1;
        p_err_msg  := p_err_msg ||
	          ' Failed to create Web HTML - Party_id - ' ||
	          p_party_id || chr(10);
      END IF;
    END IF;
    IF p_email IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'EMAIL';
      l_email_rec.email_format               := 'MAILTEXT';
      l_email_rec.email_address              := p_email;

      hz_contact_point_v2pub.create_email_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec => l_contact_point_rec,
				        p_email_rec         => l_email_rec,
				        x_contact_point_id  => l_contact_point_id, -- o n
				        x_return_status     => l_return_status, -- o v
				        x_msg_count         => l_msg_count, -- o n
				        x_msg_data          => l_msg_data); -- o v

      handle_api_status_return(p_return_status   => l_return_status, -- o v
		       p_msg_count       => l_msg_count, -- o n
		       p_oracle_event_id => p_oracle_event_id, -- i n
		       p_msg_data        => l_msg_data, -- i v
		       p_entity          => 'WEB_HTML', -- i v
		       p_entity_main     => p_entity,
		       p_err_code        => p_err_code, -- o v
		       p_err_msg         => p_err_msg); -- o v

      IF p_err_code = 1 THEN
        p_err_code := 1;
        p_err_msg  := p_err_msg || ' Failed to create EMAIL - Party_id - ' ||
	          p_party_id || chr(10);
      END IF;

    END IF;
    p_contact_point_id := l_contact_point_id;

  END create_contact_point_api;

  --------------------------------------------------------------------
  --  name:            update_contact_point_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   03/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update contact_point API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/10/2010  Dalit A. Raviv    initial build
  --  1.1  26/10/2010  Dal;it A. Raviv   add fax option
  --  1.2  11.9.16     yuval tal         INC0076039  disable phone updates
  --------------------------------------------------------------------
  PROCEDURE update_contact_point_api(p_oracle_event_id  IN NUMBER,
			 p_party_id         IN NUMBER,
			 p_phone_number     IN VARCHAR2,
			 p_mobile_phone     IN VARCHAR2,
			 p_email            IN VARCHAR2,
			 p_fax              IN VARCHAR2 DEFAULT NULL, -- Dalit A. Raviv 26/10/2010
			 p_ovn              IN NUMBER,
			 p_contact_point_id IN NUMBER,
			 p_err_code         OUT VARCHAR2,
			 p_err_msg          OUT VARCHAR2) IS

    -- Contact points
    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_email_rec         hz_contact_point_v2pub.email_rec_type;
    l_phone_rec         hz_contact_point_v2pub.phone_rec_type;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_ovn               NUMBER := NULL;
    l_data              VARCHAR2(2500) := NULL;
    l_msg_index_out     NUMBER;
  BEGIN
    fnd_msg_pub.initialize;
    p_err_code := 0;
    p_err_msg  := NULL;
    l_ovn      := p_ovn;

    -- each point type have different variable that creates the point
    -- l_contact_point_rec.owner_table_id => l_party_rel_id  is
    -- the party_id from hz_parties that is from type PARTY_RELATIONSHIP (CONT_REL_PARTY_ID)
    l_contact_point_rec.owner_table_name := 'HZ_PARTIES';
    l_contact_point_rec.owner_table_id   := p_party_id; --'5151403';
    --l_contact_point_rec.primary_flag      := 'Y';
    l_contact_point_rec.contact_point_id := p_contact_point_id;

    ---- no phone update

    /* -- yy
    IF p_phone_number IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_phone_number;
      l_phone_rec.phone_line_type            := 'GEN';

      -- phone and mobile phone
      hz_contact_point_v2pub.update_phone_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
                                                        p_contact_point_rec     => l_contact_point_rec,
                                                        p_phone_rec             => l_phone_rec,
                                                        p_object_version_number => l_ovn,
                                                        x_return_status         => l_return_status, -- o v
                                                        x_msg_count             => l_msg_count, -- o n
                                                        x_msg_data              => l_msg_data); -- o v

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        p_err_msg := 'Failed update phone contact: ' || p_contact_point_id ||
                     ' - ';

        fnd_file.put_line(fnd_file.log,
                          'Failed update phone contact: ' ||
                          p_contact_point_id);
        fnd_file.put_line(fnd_file.log,
                          'l_msg_data = ' || substr(l_msg_data, 1, 2000));
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
                          p_data          => l_data,
                          p_encoded       => fnd_api.g_false,
                          p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

          p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
        END LOOP;
        p_err_code := 1;
        ROLLBACK;
        g_num_of_api_e := g_num_of_api_e + 1;
      ELSE
        COMMIT;
        p_err_code     := 0;
        p_err_msg      := 'Success update phone contact: ' ||
                          p_contact_point_id;
        g_num_of_api_s := g_num_of_api_s + 1;
      END IF; -- Status if
    END IF; -- phone number

    IF p_mobile_phone IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_mobile_phone;
      l_phone_rec.phone_line_type            := 'MOBILE';

      -- phone and mobile phone
      hz_contact_point_v2pub.update_phone_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
                                                        p_contact_point_rec     => l_contact_point_rec,
                                                        p_phone_rec             => l_phone_rec,
                                                        p_object_version_number => l_ovn,
                                                        x_return_status         => l_return_status, -- o v
                                                        x_msg_count             => l_msg_count, -- o n
                                                        x_msg_data              => l_msg_data); -- o v

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        IF p_err_msg IS NULL THEN
          p_err_msg := 'Failed update mobile contact: ' ||
                       p_contact_point_id || ' - ';
        ELSE
          p_err_msg := p_err_msg || chr(10) ||
                       'Failed update mobile contact: ' ||
                       p_contact_point_id || ' - ';
        END IF;
        fnd_file.put_line(fnd_file.log,
                          'Failed update mobile contact: ' ||
                          p_contact_point_id);
        fnd_file.put_line(fnd_file.log,
                          'l_msg_data = ' || substr(l_msg_data, 1, 2000));
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
                          p_data          => l_data,
                          p_encoded       => fnd_api.g_false,
                          p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

          p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
        END LOOP;

        p_err_code := 1;
        ROLLBACK;
        g_num_of_api_e := g_num_of_api_e + 1;
      ELSE
        COMMIT;
        p_err_code := 0;
        IF p_err_msg IS NULL THEN
          p_err_msg := 'Success update mobile contact: ' ||
                       p_contact_point_id;
        ELSE
          p_err_msg := p_err_msg || chr(10) ||
                       'Success update mobile contact: ' ||
                       p_contact_point_id;
        END IF;
        g_num_of_api_s := g_num_of_api_s + 1;
      END IF; -- Status if
    END IF; -- Mobile phone

    -- Dalit A. Raviv 1.1 26/10/2010 add fax option
    IF p_fax IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_fax;
      l_phone_rec.phone_line_type            := 'FAX';

      -- phone and mobile phone
      hz_contact_point_v2pub.update_phone_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
                                                        p_contact_point_rec     => l_contact_point_rec,
                                                        p_phone_rec             => l_phone_rec,
                                                        p_object_version_number => l_ovn,
                                                        x_return_status         => l_return_status, -- o v
                                                        x_msg_count             => l_msg_count, -- o n
                                                        x_msg_data              => l_msg_data); -- o v

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        IF p_err_msg IS NULL THEN
          p_err_msg := 'Failed update Fax contact: ' || p_contact_point_id ||
                       ' - ';
        ELSE
          p_err_msg := p_err_msg || chr(10) ||
                       'Failed update Fax contact: ' || p_contact_point_id ||
                       ' - ';
        END IF;
        fnd_file.put_line(fnd_file.log,
                          'Failed update Fax contact: ' ||
                          p_contact_point_id);
        fnd_file.put_line(fnd_file.log,
                          'l_msg_data = ' || substr(l_msg_data, 1, 2000));
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
                          p_data          => l_data,
                          p_encoded       => fnd_api.g_false,
                          p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

          p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
        END LOOP;

        p_err_code := 1;
        ROLLBACK;
        g_num_of_api_e := g_num_of_api_e + 1;
      ELSE
        COMMIT;
        p_err_code := 0;
        IF p_err_msg IS NULL THEN
          p_err_msg := 'Success update Fax contact: ' || p_contact_point_id;
        ELSE
          p_err_msg := p_err_msg || chr(10) ||
                       'Success update Fax contact: ' || p_contact_point_id;
        END IF;
        g_num_of_api_s := g_num_of_api_s + 1;
      END IF; -- Status if
    END IF; -- fax

    --yy
    */
    -- end 26/10/2010
    IF p_email IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'EMAIL';
      l_email_rec.email_format               := 'MAILTEXT';
      l_email_rec.email_address              := p_email;

      hz_contact_point_v2pub.update_email_contact_point(p_init_msg_list         => fnd_api.g_true, -- i v 'T',
				        p_contact_point_rec     => l_contact_point_rec,
				        p_email_rec             => l_email_rec,
				        p_object_version_number => l_ovn,
				        x_return_status         => l_return_status, -- o v
				        x_msg_count             => l_msg_count, -- o n
				        x_msg_data              => l_msg_data); -- o v

      IF l_return_status <> fnd_api.g_ret_sts_success THEN
        IF p_err_msg IS NULL THEN
          p_err_msg := 'Failed update Email contact: ' ||
	           p_contact_point_id || ' - ';
        ELSE
          p_err_msg := p_err_msg || chr(10) ||
	           'Failed update Email contact: ' ||
	           p_contact_point_id || ' - ';
        END IF;
        fnd_file.put_line(fnd_file.log,
		  'Failed update Email contact: ' ||
		  p_contact_point_id);
        fnd_file.put_line(fnd_file.log,
		  'l_msg_data = ' || substr(l_msg_data, 1, 2000));
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);
          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

          p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
        END LOOP;

        p_err_code := 1;
        ROLLBACK;
        g_num_of_api_e := g_num_of_api_e + 1;
      ELSE
        COMMIT;
        p_err_code := 0;
        IF p_err_msg IS NULL THEN
          p_err_msg := 'Success update Email contact: ' ||
	           p_contact_point_id;
        ELSE
          p_err_msg := p_err_msg || chr(10) ||
	           'Success update Email contact: ' ||
	           p_contact_point_id;
        END IF;
        g_num_of_api_s := g_num_of_api_s + 1;
      END IF; -- Status if

    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_contact_point_api - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
  END update_contact_point_api;

  ----------------------------------
  PROCEDURE create_contact_point_api_all(p_oracle_event_id  IN NUMBER,
			     p_party_id         IN NUMBER,
			     p_phone_number     IN VARCHAR2,
			     p_fax_number       IN VARCHAR2,
			     p_url              IN VARCHAR2,
			     p_mobile_phone     IN VARCHAR2,
			     p_email            IN VARCHAR2,
			     p_contact_point_id OUT NUMBER,
			     p_err_code         OUT VARCHAR2,
			     p_err_msg          OUT VARCHAR2) IS

    l_contact_point_rec hz_contact_point_v2pub.contact_point_rec_type;
    l_edi_rec           hz_contact_point_v2pub.edi_rec_type;
    l_email_rec         hz_contact_point_v2pub.email_rec_type;
    l_phone_rec         hz_contact_point_v2pub.phone_rec_type;
    l_telex_rec         hz_contact_point_v2pub.telex_rec_type;
    l_web_rec           hz_contact_point_v2pub.web_rec_type;
    l_contact_point_id  NUMBER := NULL;
    l_return_status     VARCHAR2(2000) := NULL;
    l_msg_count         NUMBER := NULL;
    l_msg_data          VARCHAR2(2000) := NULL;
    l_data              VARCHAR2(2000);
    l_msg_index_out     NUMBER;

  BEGIN
    fnd_msg_pub.initialize;

    -- each point type have different variable that creates the point
    -- l_contact_point_rec.owner_table_id => l_party_rel_id  is
    -- the party_id from hz_parties that is from type PARTY_RELATIONSHIP (CONT_REL_PARTY_ID)
    l_contact_point_rec.owner_table_name  := 'HZ_PARTIES';
    l_contact_point_rec.owner_table_id    := p_party_id; --'5151403';
    l_contact_point_rec.primary_flag      := 'Y';
    l_contact_point_rec.created_by_module := g_create_by_module; --'SALESFORCE';
    IF p_phone_number IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_phone_number;
      l_phone_rec.phone_line_type            := 'GEN';
    ELSIF p_fax_number IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Fax
      l_phone_rec.phone_number               := p_fax_number;
      l_phone_rec.phone_line_type            := 'FAX';
    ELSIF p_mobile_phone IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'PHONE'; -- Phone
      l_phone_rec.phone_number               := p_mobile_phone;
      l_phone_rec.phone_line_type            := 'MOBILE';
    ELSIF p_url IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'WEB'; -- Web
      l_web_rec.web_type                     := 'HTML'; -- this is a stam value no validation
      l_web_rec.url                          := p_url;
    ELSIF p_email IS NOT NULL THEN
      l_contact_point_rec.contact_point_type := 'EMAIL';
      l_email_rec.email_format               := 'MAILTEXT';
      l_email_rec.email_address              := p_email;
    END IF;
    hz_contact_point_v2pub.create_contact_point(p_init_msg_list     => fnd_api.g_true, -- i v 'T'
				p_contact_point_rec => l_contact_point_rec, -- i contact_point_rec_type,
				p_edi_rec           => l_edi_rec, -- i edi_rec_type
				p_email_rec         => l_email_rec, -- i email_rec_type
				p_phone_rec         => l_phone_rec, -- i phone_rec_type
				p_telex_rec         => l_telex_rec, -- i telex_rec_type
				p_web_rec           => l_web_rec, -- i web_rec_type
				x_contact_point_id  => l_contact_point_id, -- o n
				x_return_status     => l_return_status, -- o v
				x_msg_count         => l_msg_count, -- o n
				x_msg_data          => l_msg_data); -- o v

    -- Handle the success/ Failure of the API
    -- 1) put messages to the log
    -- 2) do commit or rollback
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      IF l_msg_count > 1 THEN
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => i,
		  p_data          => l_data,
		  p_encoded       => fnd_api.g_false,
		  p_msg_index_out => l_msg_index_out);

          fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
          p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2500);
        END LOOP;
      END IF;
      fnd_file.put_line(fnd_file.log, 'Failed to create_contact_point');
      fnd_file.put_line(fnd_file.log, 'l_msg_data      - ' || p_err_msg);
      ROLLBACK;
      -- update interface line with error only because the account did created.
      BEGIN
        UPDATE xxobjt_sf2oa_interface_l l
        SET    l.oa_err_code      = '1',
	   l.oa_err_msg       = p_err_msg,
	   l.last_update_date = SYSDATE
        WHERE  l.oracle_event_id = p_oracle_event_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      p_contact_point_id := NULL;
      p_err_code         := '1';
    ELSE
      COMMIT;
      p_contact_point_id := l_contact_point_id;
      p_err_code         := '0';
      p_err_msg          := NULL;
    END IF; --l_return_status

  END create_contact_point_api_all;

  --------------------------------------------------------------------
  --  name:            Handle_entities_in_oracle
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that Handle only ACCOUNT DATA will get batch id
  --                   1) get population to work on
  --                   2) parse xml data
  --                   3) call API to create Account
  --                   4) update interface line table with errors / sf_id / oracle_id etc'
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --  1.1  17/10/2012  Dalit A. Raviv    add check if SF_ID allready exists in oracle.
  --  1.2   22.6.16    yuval tal         CHG0038819 use exists oracle id in case found and update success instead of err

  --------------------------------------------------------------------
  PROCEDURE handle_accounts_in_oracle(p_batch_id IN NUMBER,
			  p_err_code OUT VARCHAR2,
			  p_err_msg  OUT VARCHAR2) IS

    -- get account rows to parse and handle in oracle
    -- by batch_id , status and source.
    CURSOR get_account_pop_c(p_batch_id IN NUMBER) IS
      SELECT h.source_name,
	 l.*,
	 extractvalue(l.rec_xml, '/result/Id') sf_account_id,
	 extractvalue(l.rec_xml, '/result/Fax') fax,
	 extractvalue(l.rec_xml, '/result/Industry') industry,
	 extractvalue(l.rec_xml, '/result/Name') account_name,
	 extractvalue(l.rec_xml, '/result/Oracle_Event_ID__c') sf_oracle_event_id,
	 extractvalue(l.rec_xml, '/result/Oracle_Account_Number__c') sf_oracle_account_id,
	 extractvalue(l.rec_xml, '/result/Oracle_Status__c') oa_status,
	 extractvalue(l.rec_xml, '/result/Sales_Territory__c') sales_territory,
	 extractvalue(l.rec_xml, '/result/OwnerId') account_owner,
	 extractvalue(l.rec_xml, '/result/Phone') phone,
	 extractvalue(l.rec_xml, '/result/RecordTypeId') sales_channel_id,
	 extractvalue(l.rec_xml, '/result/Website') web
      FROM   xxobjt_sf2oa_interface_l l,
	 xxobjt_sf2oa_interface_h h
      WHERE  h.oracle_batch_id = l.oracle_batch_id
      AND    l.status = 'NEW'
      AND    l.oracle_batch_id = p_batch_id;

    -- Parse recxml field to get all needed data per row
    /*    CURSOR get_xml_pop_c(p_result IN xmltype) IS
          SELECT extractvalue(VALUE(xml), '/result/Id') sf_account_id,
                 extractvalue(VALUE(xml), '/result/Fax') fax,
                 extractvalue(VALUE(xml), '/result/Industry') industry,
                 extractvalue(VALUE(xml), '/result/Name') account_name,
                 extractvalue(VALUE(xml), '/result/Oracle_Event_ID__c') oracle_event_id,
                 extractvalue(VALUE(xml), '/result/Oracle_Account_Number__c') oracle_account_id,
                 extractvalue(VALUE(xml), '/result/Oracle_Status__c') oa_status,
                 extractvalue(VALUE(xml), '/result/Sales_Territory__c') sales_territory,
                 extractvalue(VALUE(xml), '/result/OwnerId') account_owner,
                 extractvalue(VALUE(xml), '/result/Phone') phone,
                 extractvalue(VALUE(xml), '/result/RecordTypeId') sales_channel_id,
                 extractvalue(VALUE(xml), '/result/Website') web
            FROM TABLE(xmlsequence(extract(p_result, '/result'))) xml;
    */
    l_cust_account_id    NUMBER;
    l_party_id           NUMBER;
    l_code_assignment_id NUMBER;
    l_contact_point_id   NUMBER;

    l_err_code  VARCHAR2(50) := NULL;
    l_err_msg   VARCHAR2(2500) := NULL;
    l_err_code1 VARCHAR2(50) := NULL;
    l_err_msg1  VARCHAR2(2500) := NULL;
    l_count     NUMBER := 0;
    l_exist     VARCHAR2(10) := 'N';

    general_exception EXCEPTION;
  BEGIN

    -- set g_user_id SALESFORCE User
    set_salesforce_user;
    p_err_code := 0;
    p_err_msg  := NULL;
    fnd_global.apps_initialize(user_id      => g_user_id, -- SALESFORCE
		       resp_id      => 51137, -- CRM Service Super User Objet
		       resp_appl_id => 514); -- Support (obsolete)

    FOR get_account_pop_r IN get_account_pop_c(p_batch_id) LOOP

      update_sf_id(p_sf_id           => get_account_pop_r.sf_account_id, -- i v
	       p_oracle_event_id => get_account_pop_r.oracle_event_id, -- i n
	       p_err_msg         => l_err_msg, -- o v
	       p_err_code        => l_err_code); -- o v

      update_sf_exist(p_sf_id           => get_account_pop_r.sf_account_id, -- i v
	          p_oracle_event_id => get_account_pop_r.oracle_event_id, -- i n
	          p_err_msg         => l_err_msg, -- o v
	          p_err_code        => l_err_code); -- o v

      SELECT COUNT(1)
      INTO   l_count
      FROM   xxobjt_sf2oa_interface_l l
      WHERE  l.oracle_event_id = get_account_pop_r.oracle_event_id
      AND    l.status = 'OA_HOLD';

      IF l_count = 0 THEN
        BEGIN
          -- 17/10/2012 Dalit A. Raviv
          -- 0) Check if this SF_iD exist allready in oracle
          --l_exist := 'N';
          l_exist := get_sf_id_exist(p_source_name => 'ACCOUNT',
			 p_sf_id       => get_account_pop_r.sf_account_id);
          IF l_exist IS NOT NULL THEN
	l_err_code := '0';
	l_err_msg  := 'SD_ID allready Exist in Oracle Account - hz_cust_accounts acc, attribute4 = ' ||
		  get_account_pop_r.sf_account_id;
	--yuval
	update_interface_line_status(p_status          => 'OA_SUCCESS',
			     p_oracle_id       => l_exist,
			     p_sf_id           => get_account_pop_r.sf_account_id,
			     p_oracle_event_id => get_account_pop_r.oracle_event_id,
			     p_err_code        => l_err_code,
			     p_err_msg         => l_err_msg);

	/*update_interface_line_error(p_status          => 'OA_ERR',
            p_oracle_event_id => get_account_pop_r.oracle_event_id,
            p_err_msg         => l_err_msg,
            p_err_code        => l_err_code);*/

	p_err_code := 0;
	p_err_msg  := l_err_msg;
	RAISE general_exception;
          ELSE
	-- 1) call API's
	l_err_code := '0';
	l_err_msg  := NULL;
	create_account_api(p_oracle_event_id  => get_account_pop_r.oracle_event_id, -- i n
		       p_sales_channel_id => get_account_pop_r.sales_channel_id, -- i v
		       p_account_name     => get_account_pop_r.account_name, -- i v
		       p_sf_account_id    => get_account_pop_r.sf_account_id, -- i v
		       p_org_id           => get_account_pop_r.sales_territory, -- i v
		       p_cust_account_id  => l_cust_account_id, -- o n
		       p_party_id         => l_party_id, -- o n
		       p_err_code         => l_err_code, -- o v
		       p_err_msg          => l_err_msg); -- o v
	IF l_err_code = 1 THEN
	  p_err_code := 1;
	  p_err_msg  := l_err_msg;
	  RAISE general_exception;
	END IF;
	-- 2) If API success then continue to create create_code_assignment
	l_err_code1 := '0';
	l_err_msg1  := NULL;
	create_code_assignment_api(p_oracle_event_id    => get_account_pop_r.oracle_event_id, -- i n
			   p_industry           => get_account_pop_r.industry, -- i v
			   p_party_id           => l_party_id, -- i n
			   p_account_name       => get_account_pop_r.account_name, -- i v
			   p_code_assignment_id => l_code_assignment_id, -- o n
			   p_err_code           => l_err_code1, -- o v
			   p_err_msg            => l_err_msg1); -- o v

	fnd_file.put_line(fnd_file.log,
		      'l_code_assignment_id - ' ||
		      l_code_assignment_id);

	-- 3) create contact point
	l_err_code1 := '0';
	l_err_msg1  := NULL;
	IF get_account_pop_r.phone IS NOT NULL OR
	   get_account_pop_r.fax IS NOT NULL OR
	   get_account_pop_r.web IS NOT NULL THEN

	  create_contact_point_api(p_oracle_event_id  => get_account_pop_r.oracle_event_id, -- i n
			   p_party_id         => l_party_id, -- i n
			   p_phone_number     => get_account_pop_r.phone, -- i v
			   p_fax_number       => get_account_pop_r.fax, -- i v
			   p_url              => get_account_pop_r.web, -- i v
			   p_mobile_phone     => NULL, -- i v
			   p_email            => NULL, -- i v
			   p_contact_point_id => l_contact_point_id, -- o n
			   p_err_code         => l_err_code1, -- o v
			   p_err_msg          => l_err_msg1); -- o v

	  fnd_file.put_line(fnd_file.log,
		        'l_contact_point_id - ' ||
		        l_contact_point_id);
	END IF;
          END IF; -- l_exist
        EXCEPTION
          WHEN general_exception THEN
	NULL;
        END;
      END IF; -- l_count
    --END LOOP;

    --
    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - Handle_accounts_in_oracle - p_batch_id - ' ||
	        p_batch_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - Handle_accounts_in_oracle - ' ||
		   substr(SQLERRM, 1, 240));

  END handle_accounts_in_oracle;

  --------------------------------------------------------------------
  --  name:            create_location_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create location API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --  1.1  24/11/2010  Dalit A. Raviv    add validation on state only when
  --                                     territory_code is US
  --  1.2  05/12/2010  Dalit A. Raviv    l_state was to short.
  --------------------------------------------------------------------
  PROCEDURE create_location_api(p_country         IN VARCHAR2,
		        p_address_line1   IN VARCHAR2,
		        p_city            IN VARCHAR2,
		        p_postal_code     IN VARCHAR2,
		        p_state           IN VARCHAR2,
		        p_county          IN VARCHAR2,
		        p_oracle_event_id IN NUMBER,
		        p_entity          IN VARCHAR2 DEFAULT 'INSERT',
		        p_location_id     OUT NUMBER,
		        p_err_code        OUT VARCHAR2,
		        p_err_msg         OUT VARCHAR2) IS

    l_territory_code VARCHAR2(20) := NULL;
    l_state          VARCHAR2(150) := NULL;
    t_location_rec   hz_location_v2pub.location_rec_type;
    l_location_id    NUMBER;
    l_return_status  VARCHAR2(1);
    l_msg_count      NUMBER;
    l_msg_data       VARCHAR2(2500);
    l_data           VARCHAR2(2000);
    l_msg_index_out  NUMBER;
    l_err_msg        VARCHAR2(2500) := NULL;
    l_err_code       VARCHAR2(10) := 0;

    general_exception EXCEPTION;
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;

    /*-- yuval avalara
    -- check there is no failure with the same data already sent before
    -- if exists skip api and update failure

    DECLARE
      l_concat_add VARCHAR2(1500);
      l_sf_id      VARCHAR2(50);
    BEGIN

      SELECT sf_id
      INTO   l_sf_id
      FROM   xxobjt_sf2oa_interface_l t
      WHERE  t.oracle_event_id = p_oracle_event_id;

      BEGIN
        SELECT concat_add,
               oa_err_msg
        INTO   l_concat_add,
               l_err_msg
        FROM   (SELECT row_number() over(PARTITION BY sf_id ORDER BY t.creation_date DESC) x_rownum,
                       extractvalue(rec_xml, '/result/Address_1__c') ||
                       extractvalue(rec_xml, '/result/City__c') ||
                       extractvalue(rec_xml, '/result/Country__c') ||
                       extractvalue(rec_xml, '/result/County__c') ||
                       extractvalue(rec_xml,
                                    '/result/Zipcode_Postal_Code__c') ||
                       extractvalue(rec_xml, '/result/State_Region__c') concat_add,
                       t.oa_err_msg,
                       t.status

                FROM   xxobjt_sf2oa_interface_l t
                WHERE  t.sf_id = l_sf_id
                AND    t.oracle_event_id != p_oracle_event_id
                AND    status = 'OA_ERR')
        WHERE  x_rownum = 1;

        IF l_concat_add = p_address_line1 || p_city || p_country ||
           p_county || p_postal_code || p_state THEN

          update_interface_line_error(p_status          => 'OA_ERR',
                                      p_oracle_event_id => p_oracle_event_id,
                                      p_err_msg         => l_err_msg,
                                      p_err_code        => l_err_code);
          RAISE general_exception;
        END IF;

      EXCEPTION
        WHEN no_data_found THEN
          -- no previous call for the same sf_id
          NULL;

      END;

    END;*/

    --

    ---
    IF p_country IS NOT NULL THEN
      BEGIN
        SELECT territory_code
        INTO   l_territory_code
        FROM   fnd_territories_vl t
        WHERE  upper(territory_short_name) = upper(p_country);
      EXCEPTION
        WHEN OTHERS THEN
          p_err_code := 1;
          p_err_msg  := 'create_location_api - Invalid territory :' ||
		p_country;
          IF nvl(p_entity, 'INSERT') = 'INSERT' THEN
	l_err_msg := 'create_location_api - Invalid territory :' ||
		 p_country;
	update_interface_line_error(p_status          => 'OA_ERR',
			    p_oracle_event_id => p_oracle_event_id,
			    p_err_msg         => l_err_msg,
			    p_err_code        => l_err_code);
          END IF;
          RAISE general_exception;
      END;
    ELSE
      l_territory_code := NULL;
    END IF;

    IF p_state IS NOT NULL AND nvl(l_territory_code, 'DAR') = 'US' THEN
      BEGIN
        SELECT lookup_code
        INTO   l_state
        FROM   fnd_common_lookups
        WHERE  lookup_type = 'US_STATE'
        AND    upper(meaning) = upper(p_state);

      EXCEPTION
        WHEN OTHERS THEN
          p_err_code := 1;
          p_err_msg  := 'create_location_api - Invalid state :' || p_state;
          IF nvl(p_entity, 'INSERT') = 'INSERT' THEN
	l_err_msg := 'create_location_api - Invalid state :' || p_state;
	update_interface_line_error(p_status          => 'OA_ERR',
			    p_oracle_event_id => p_oracle_event_id,
			    p_err_msg         => l_err_msg,
			    p_err_code        => l_err_code);
          END IF;
          RAISE general_exception;
      END;
    ELSE
      l_state := p_state;
    END IF;

    fnd_msg_pub.initialize;
    t_location_rec.country           := l_territory_code;
    t_location_rec.address1          := p_address_line1;
    t_location_rec.city              := p_city;
    t_location_rec.postal_code       := p_postal_code;
    t_location_rec.state             := l_state; --p_state;
    t_location_rec.county            := p_county;
    t_location_rec.created_by_module := g_create_by_module; --'SALESFORCE';

    hz_location_v2pub.create_location(p_init_msg_list => 'T',
			  p_location_rec  => t_location_rec,
			  x_location_id   => l_location_id,
			  x_return_status => l_return_status,
			  x_msg_count     => l_msg_count,
			  x_msg_data      => l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Location Api Err: ';

      fnd_file.put_line(fnd_file.log, 'Location Api Err:');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;
      p_err_code := 1;
      ROLLBACK;
      IF nvl(p_entity, 'INSERT') = 'INSERT' THEN
        l_err_msg := substr(p_err_msg, 1, 2000);
        update_interface_line_error(p_status          => 'OA_ERR',
			p_oracle_event_id => p_oracle_event_id,
			p_err_msg         => l_err_msg,
			p_err_code        => l_err_code);
      END IF;
    ELSE
      --commit;
      p_location_id := l_location_id;
      p_err_code    := 0;
      p_err_msg     := NULL;
    END IF; -- Status if
    p_location_id := l_location_id;
  EXCEPTION
    WHEN general_exception THEN
      NULL;
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Location Api Err - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
      l_err_msg  := p_err_msg;
      l_err_code := 1;
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, --p_oracle_event_id,        -- i n
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code); -- o v
  END create_location_api;

  --------------------------------------------------------------------
  --  name:            update_location_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   03/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call update location API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/109/2010 Dalit A. Raviv    initial build
  --  1.1  24/11/2010  Dalit A. Raviv    add validation on state only when
  --                                     territory_code is US
  --  1.2  05/12/2010  Dalit A. Raviv    l_state was to short.

  --------------------------------------------------------------------
  PROCEDURE update_location_api(p_country         IN VARCHAR2,
		        p_address_line1   IN VARCHAR2,
		        p_city            IN VARCHAR2,
		        p_postal_code     IN VARCHAR2,
		        p_state           IN VARCHAR2,
		        p_county          IN VARCHAR2,
		        p_oracle_event_id IN NUMBER,
		        p_ovn             IN NUMBER,
		        p_location_id     IN NUMBER,
		        p_err_code        OUT VARCHAR2,
		        p_err_msg         OUT VARCHAR2) IS

    l_territory_code VARCHAR2(20) := NULL;
    l_state          VARCHAR2(150) := NULL;
    t_location_rec   hz_location_v2pub.location_rec_type;
    l_return_status  VARCHAR2(1);
    l_msg_count      NUMBER;
    l_msg_data       VARCHAR2(2500);
    l_data           VARCHAR2(2000);
    l_msg_index_out  NUMBER;
    l_err_msg        VARCHAR2(2500) := NULL;
    l_err_code       VARCHAR2(10) := 0;
    l_ovn            NUMBER := NULL;
    general_exception EXCEPTION;

    CURSOR c_loc IS
      SELECT *
      FROM   hz_locations t
      WHERE  t.location_id = p_location_id;
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
    IF p_country IS NOT NULL THEN
      BEGIN
        SELECT territory_code
        INTO   l_territory_code
        FROM   fnd_territories_vl t
        WHERE  upper(territory_short_name) = upper(p_country);
      EXCEPTION
        WHEN OTHERS THEN
          p_err_code := 1;
          p_err_msg  := 'Update_location_api - Invalid territory :' ||
		p_country;
          l_err_msg  := 'Update_location_api - Invalid territory :' ||
		p_country;
          update_interface_line_error(p_status          => 'OA_ERR',
			  p_oracle_event_id => p_oracle_event_id,
			  p_err_msg         => l_err_msg,
			  p_err_code        => l_err_code);
          RAISE general_exception;
      END;
    ELSE
      l_territory_code := NULL;
    END IF;

    IF p_state IS NOT NULL AND nvl(l_territory_code, 'DAR') = 'US' THEN
      BEGIN
        SELECT lookup_code
        INTO   l_state
        FROM   fnd_common_lookups
        WHERE  lookup_type = 'US_STATE'
        AND    upper(meaning) = upper(p_state);

      EXCEPTION
        WHEN OTHERS THEN
          p_err_code := 1;
          p_err_msg  := 'create_location_api - Invalid state :' || p_state;

          l_err_msg := 'create_location_api - Invalid state :' || p_state;
          update_interface_line_error(p_status          => 'OA_ERR',
			  p_oracle_event_id => p_oracle_event_id,
			  p_err_msg         => l_err_msg,
			  p_err_code        => l_err_code);

          RAISE general_exception;
      END;
    ELSE
      l_state := p_state;
    END IF;

    fnd_msg_pub.initialize;
    t_location_rec.location_id := p_location_id;
    t_location_rec.country     := l_territory_code;
    t_location_rec.address1    := p_address_line1;
    t_location_rec.city        := p_city;
    t_location_rec.postal_code := p_postal_code;
    t_location_rec.state       := l_state; --p_state;
    t_location_rec.county      := p_county;

    l_ovn := p_ovn;

    --

    hz_location_v2pub.update_location(p_init_msg_list         => 'T', -- i v
			  p_location_rec          => t_location_rec,
			  p_object_version_number => l_ovn, -- i / o nocopy n
			  x_return_status         => l_return_status, -- o nocopy v
			  x_msg_count             => l_msg_count, -- o nocopy n
			  x_msg_data              => l_msg_data); -- o nocopy v

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Location Api Err: ' || p_location_id || ' - ';

      fnd_file.put_line(fnd_file.log, 'Failed update location: ');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'Location Api Err - ' || l_data);

        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;
      p_err_code := 1;
      ROLLBACK;
      g_num_of_api_e := g_num_of_api_e + 1;

    ELSE
      COMMIT;
      p_err_code     := 0;
      p_err_msg      := 'Success update location - ' || p_location_id;
      g_num_of_api_s := g_num_of_api_s + 1;
    END IF; -- Status if

  EXCEPTION
    WHEN general_exception THEN
      NULL;
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Location Api Err - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
      l_err_msg  := p_err_msg;
      l_err_code := 1;
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, --p_oracle_event_id,        -- i n
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code); -- o v
  END update_location_api;

  --------------------------------------------------------------------
  --  name:            create_party_site_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create party site API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --  1.1  02/01/2010  Dalit A. Raviv    change party_site_name from country
  --                                     to party_name
  --------------------------------------------------------------------
  PROCEDURE create_party_site_api(p_location_id     IN NUMBER,
		          p_cust_account_id IN NUMBER,
		          p_oracle_event_id IN NUMBER,
		          --p_country         IN VARCHAR2,
		          p_party_id      IN NUMBER,
		          p_entity        IN VARCHAR2 DEFAULT 'INSERT', --'UPDATE'
		          p_party_site_id OUT NUMBER,
		          p_err_code      OUT VARCHAR2,
		          p_err_msg       OUT VARCHAR2) IS

    t_party_site_rec    hz_party_site_v2pub.party_site_rec_type;
    l_party_id          NUMBER := NULL;
    l_party_site_number NUMBER := NULL;
    l_party_site_id     NUMBER := NULL;
    l_return_status     VARCHAR2(1);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2500);
    l_data              VARCHAR2(2000);
    l_msg_index_out     NUMBER;
    l_err_msg           VARCHAR2(2500) := NULL;
    l_err_code          VARCHAR2(10) := 0;
    -- 1.1 Dalit A. Raviv 02/01/2011
    l_party_name VARCHAR2(360) := NULL;
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;
    --------------------------------
    --  Get party id, party name  --
    --------------------------------
    IF p_party_id IS NULL THEN
      -- 1.1 Dalit A. Raviv 02/01/2011
      SELECT hca.party_id,
	 hp.party_name
      INTO   l_party_id,
	 l_party_name
      FROM   hz_cust_accounts hca,
	 hz_parties       hp
      WHERE  hca.cust_account_id = p_cust_account_id
      AND    hca.party_id = hp.party_id;
    ELSE
      l_party_id := p_party_id;
      -- 1.1 Dalit A. Raviv 02/01/2011
      SELECT hp.party_name
      INTO   l_party_name
      FROM   hz_parties hp
      WHERE  hp.party_id = l_party_id;
    END IF;
    fnd_msg_pub.initialize;

    t_party_site_rec.party_id    := l_party_id;
    t_party_site_rec.location_id := p_location_id;
    --t_party_site_rec.identifying_address_flag := 'Y';
    t_party_site_rec.created_by_module := g_create_by_module; --'SALESFORCE';
    t_party_site_rec.party_site_name   := l_party_name; --p_country; -- p_site_name;

    hz_party_site_v2pub.create_party_site(p_init_msg_list     => 'T',
			      p_party_site_rec    => t_party_site_rec,
			      x_party_site_id     => l_party_site_id,
			      x_party_site_number => l_party_site_number,
			      x_return_status     => l_return_status,
			      x_msg_count         => l_msg_count,
			      x_msg_data          => l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN

      p_err_msg := 'Error create party site: ';
      fnd_file.put_line(fnd_file.log, 'Creation of Party Site Failed ');
      fnd_file.put_line(fnd_file.log,
		'l_Msg_Count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log, 'l_Msg_Data = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        p_err_msg := p_err_msg || l_data || chr(10);
      END LOOP;
      p_party_site_id := -99;
      p_err_code      := 1;
      ROLLBACK;
      IF nvl(p_entity, 'INSERT') = 'INSERT' THEN
        l_err_msg := substr(p_err_msg, 1, 2000);
        update_interface_line_error(p_status          => 'OA_ERR',
			p_oracle_event_id => p_oracle_event_id,
			p_err_msg         => l_err_msg,
			p_err_code        => l_err_code);
      END IF;
    ELSE
      --commit;
      p_party_site_id := l_party_site_id;
      p_err_msg       := NULL;
      p_err_code      := 0;
    END IF; --  party Status
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_party_site_api - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
      l_err_msg  := p_err_msg;
      l_err_code := 1;
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, --p_oracle_event_id,        -- i n
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code); -- o v
  END create_party_site_api;

  --------------------------------------------------------------------
  --  name:            create_party_site_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create party site API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_cust_account_site_api(p_cust_account_id   IN NUMBER,
			     p_oracle_event_id   IN NUMBER,
			     p_party_site_id     IN NUMBER,
			     p_sf_id             IN VARCHAR2,
			     p_cust_acct_site_id OUT NUMBER,
			     p_org_id            OUT NUMBER,
			     p_party_name        OUT VARCHAR2,
			     p_err_code          OUT VARCHAR2,
			     p_err_msg           OUT VARCHAR2) IS

    t_cust_acct_site_rec hz_cust_account_site_v2pub.cust_acct_site_rec_type;
    l_party_id           NUMBER := NULL;
    l_org_id             NUMBER := NULL;
    l_cust_acct_site_id  NUMBER := NULL;
    l_return_status      VARCHAR2(1);
    l_msg_count          NUMBER;
    l_msg_data           VARCHAR2(2500);
    l_data               VARCHAR2(2000);
    l_msg_index_out      NUMBER;
    l_err_msg            VARCHAR2(2500) := NULL;
    l_err_code           VARCHAR2(10) := NULL;
    l_party_name         VARCHAR2(360) := NULL;
  BEGIN
    --- org_id will come from att3 of hz_party
    SELECT hca.party_id,
           hp.attribute3,
           hp.party_name
    INTO   l_party_id,
           l_org_id,
           l_party_name
    FROM   hz_cust_accounts hca,
           hz_parties       hp
    WHERE  hca.cust_account_id = p_cust_account_id
    AND    hp.party_id = hca.party_id;

    p_org_id     := l_org_id;
    p_party_name := l_party_name;
    fnd_msg_pub.initialize;

    t_cust_acct_site_rec.cust_account_id   := p_cust_account_id;
    t_cust_acct_site_rec.party_site_id     := p_party_site_id;
    t_cust_acct_site_rec.created_by_module := g_create_by_module; --'SALESFORCE';
    t_cust_acct_site_rec.org_id            := l_org_id;
    t_cust_acct_site_rec.attribute1        := p_sf_id;

    --IF nvl(g_org_id, 1) <> l_org_id THEN
    --  g_org_id := l_org_id;

    mo_global.set_org_access(p_org_id_char     => l_org_id,
		     p_sp_id_char      => NULL,
		     p_appl_short_name => 'AR');
    --END IF;

    hz_cust_account_site_v2pub.create_cust_acct_site(p_init_msg_list      => 'T',
				     p_cust_acct_site_rec => t_cust_acct_site_rec,
				     x_cust_acct_site_id  => l_cust_acct_site_id,
				     x_return_status      => l_return_status,
				     x_msg_count          => l_msg_count,
				     x_msg_data           => l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN

      p_err_msg := 'Error create site account: ';
      fnd_file.put_line(fnd_file.log,
		'Creation of Customer Account Site Failed ');
      fnd_file.put_line(fnd_file.log,
		' l_Msg_Count = ' || to_char(l_msg_count));
      fnd_file.put_line(fnd_file.log, ' l_Msg_Data  = ' || l_msg_data);
      p_cust_acct_site_id := -99;
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        p_err_msg := p_err_msg || l_data || chr(10);
      END LOOP;
      ROLLBACK;
      l_err_msg := substr(p_err_msg, 1, 2000);
      update_interface_line_error(p_status          => 'OA_ERR',
		          p_oracle_event_id => p_oracle_event_id,
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code);
    ELSE
      --commit;
      p_err_code          := 0;
      p_err_msg           := NULL;
      p_cust_acct_site_id := l_cust_acct_site_id;
      p_org_id            := l_org_id;
      p_party_name        := l_party_name;

    END IF; -- Customer Site Status
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_cust_account_site_api - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
      l_err_msg  := p_err_msg;
      l_err_code := 1;
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, --p_oracle_event_id,        -- i n
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code); -- o v
  END create_cust_account_site_api;

  --------------------------------------------------------------------
  --  name:            create_party_site_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create party site API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --  1.1  21/12/2010  Dalit A. Raviv    t_cust_site_use_rec.location have only 40 char
  --                                     the data we send is bigger - p_party_name || ' - ' ||l_location_s
  --                                     solution to sorten p_party_name to 30 char
  --------------------------------------------------------------------
  PROCEDURE create_cust_site_use_api(p_oracle_event_id   IN NUMBER,
			 p_cust_acct_site_id IN NUMBER,
			 p_org_id            IN NUMBER,
			 p_primary_bill      IN VARCHAR2, -- to translate from false / true
			 p_primary_ship      IN VARCHAR2, -- to translate from false / true
			 p_site_usage        IN VARCHAR2,
			 p_party_name        IN VARCHAR2,
			 p_ship_site_use_id  OUT NUMBER,
			 p_bill_site_use_id  OUT NUMBER,
			 p_err_code          OUT VARCHAR2,
			 p_err_msg           OUT VARCHAR2) IS

    t_cust_site_use_rec    hz_cust_account_site_v2pub.cust_site_use_rec_type;
    t_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type;
    l_return_status        VARCHAR2(2000);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(2000);
    l_data                 VARCHAR2(1000);
    l_msg_index_out        NUMBER;
    l_bill_site_use_id     NUMBER := NULL;
    l_ship_site_use_id     NUMBER := NULL;
    l_err_msg              VARCHAR2(2500) := NULL;
    l_err_code             VARCHAR2(10) := 0;
    l_flag                 VARCHAR2(2) := 'N';
    l_location_s           NUMBER := 0;
  BEGIN
    fnd_msg_pub.initialize;

    SELECT xxobjt_sf2oa_location_id_s.nextval
    INTO   l_location_s
    FROM   dual;
    ---------------------------------
    -- Create an account site use  --
    ---------------------------------
    t_cust_site_use_rec.cust_acct_site_id := p_cust_acct_site_id;
    t_cust_site_use_rec.org_id            := p_org_id;
    t_cust_site_use_rec.created_by_module := g_create_by_module; --'SALESFORCE';
    t_cust_site_use_rec.location          := substr(p_party_name, 1, 32) ||
			         ' - ' || l_location_s;

    IF p_site_usage <> 'Ship To' THEN
      -- will be BillTo or BillTo/ShipTo
      t_cust_site_use_rec.primary_flag  := p_primary_bill;
      t_cust_site_use_rec.site_use_code := 'BILL_TO';
      hz_cust_account_site_v2pub.create_cust_site_use(p_init_msg_list        => 'T',
				      p_cust_site_use_rec    => t_cust_site_use_rec,
				      p_customer_profile_rec => t_customer_profile_rec,
				      p_create_profile       => 'F',
				      p_create_profile_amt   => 'F',
				      x_site_use_id          => l_bill_site_use_id,
				      x_return_status        => l_return_status,
				      x_msg_count            => l_msg_count,
				      x_msg_data             => l_msg_data);
      fnd_file.put_line(fnd_file.log,
		'BILL_TO - l_bill_site_use_id  = ' ||
		l_bill_site_use_id);
    END IF;

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Error create cust site use: ';
      fnd_file.put_line(fnd_file.log,
		'Error create cust site use: oracle event id' ||
		p_oracle_event_id || ' p_cust_acct_site_id - ' ||
		p_cust_acct_site_id);
      fnd_file.put_line(fnd_file.log, ' l_msg_data  = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        p_err_msg := p_err_msg || l_data || chr(10);
        fnd_file.put_line(fnd_file.log,
		  'BILL_TO l_msg_data  = ' || l_msg_data);
      END LOOP;
      p_err_code := 1;
      --p_ship_site_use_id := null;
      p_bill_site_use_id := NULL;
      ROLLBACK;
      l_err_msg := substr(p_err_msg, 1, 2000);
      update_interface_line_error(p_status          => 'OA_WARNING',
		          p_oracle_event_id => p_oracle_event_id,
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code);
    ELSE
      COMMIT;
      l_flag     := 'Y';
      p_err_code := 0;
      p_err_msg  := NULL;
      --p_ship_site_use_id := l_ship_site_use_id;
      p_bill_site_use_id := l_bill_site_use_id;
    END IF;

    IF p_site_usage <> 'Bill To' THEN
      -- will be ShipTo or BillTo/ShipTo
      t_cust_site_use_rec.primary_flag  := p_primary_ship;
      t_cust_site_use_rec.site_use_code := 'SHIP_TO';
      hz_cust_account_site_v2pub.create_cust_site_use(p_init_msg_list        => 'T',
				      p_cust_site_use_rec    => t_cust_site_use_rec,
				      p_customer_profile_rec => t_customer_profile_rec,
				      p_create_profile       => 'F',
				      p_create_profile_amt   => 'F',
				      x_site_use_id          => l_ship_site_use_id,
				      x_return_status        => l_return_status,
				      x_msg_count            => l_msg_count,
				      x_msg_data             => l_msg_data);

    END IF;

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Error create cust site use: ';
      fnd_file.put_line(fnd_file.log,
		'Error create cust site use: oracle event id' ||
		p_oracle_event_id || ' p_cust_acct_site_id - ' ||
		p_cust_acct_site_id);
      fnd_file.put_line(fnd_file.log,
		'SHIP_TO l_msg_data  = ' || l_msg_data);
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        l_err_msg := substr(l_err_msg, 1, 1000) || l_data || chr(10);
        fnd_file.put_line(fnd_file.log, ' l_msg_data  = ' || l_err_msg);
      END LOOP;
      IF l_flag = 'Y' THEN
        p_err_msg := l_err_msg;
      ELSE
        p_err_msg := p_err_msg || chr(10) || l_err_msg;
      END IF;

      p_err_code         := 1;
      p_ship_site_use_id := NULL;
      ROLLBACK;
      --l_err_msg  := substr(p_err_msg,1,2000);
      update_interface_line_error(p_status          => 'OA_WARNING',
		          p_oracle_event_id => p_oracle_event_id,
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code);
    ELSE
      COMMIT;
      p_err_code         := 0;
      p_err_msg          := NULL;
      p_ship_site_use_id := l_ship_site_use_id;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_cust_site_use_api - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
      l_err_msg  := p_err_msg;
      l_err_code := 1;
      update_interface_line_error(p_status          => 'OA_WARNING', -- i n
		          p_oracle_event_id => p_oracle_event_id, --p_oracle_event_id,        -- i n
		          p_err_msg         => l_err_msg,
		          p_err_code        => l_err_code); -- o v
  END create_cust_site_use_api;

  --------------------------------------------------------------------
  --  name:            Handle_entities_in_oracle
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that Handle only SITE DATA will get batch id
  --                   1) get population to work on
  --                   2) parse xml data
  --                   3) call API to create SITE
  --                   4) update interface line table with errors / sf_id / oracle_id etc'
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/09/2010  Dalit A. Raviv    initial build
  --  1.1  11/11/2010  Dalit A. Raviv    enter parse select to the main select
  --  1.2  17/10/2012  Dalit A. Raviv    add check if SD_ID exists in oracle
  --  1.3  31/10/2012  Dalit A. Raviv    add commit and rollback
  --  1.4  22.6.16     yuval tal         CHG0038819 use exists oracle id in case found and update success instead of err

  --------------------------------------------------------------------
  PROCEDURE handle_sites_in_oracle(p_batch_id IN NUMBER,
		           p_err_code OUT VARCHAR2,
		           p_err_msg  OUT VARCHAR2) IS

    -- get site rows to parse and handle in oracle
    -- by batch_id , status and source.
    CURSOR get_account_pop_c(p_batch_id IN NUMBER) IS
      SELECT h.source_name,
	 l.*,
	 extractvalue(l.rec_xml, '/result/Account__c') sf_account_id,
	 extractvalue(l.rec_xml, '/result/Id') sf_site_id,
	 extractvalue(l.rec_xml, '/result/Address__c') site_address,
	 extractvalue(l.rec_xml, '/result/City__c') site_city,
	 extractvalue(l.rec_xml, '/result/Zipcode_Postal_Code__c') site_postal_code,
	 extractvalue(l.rec_xml, '/result/County__c') site_county,
	 extractvalue(l.rec_xml, '/result/State_Region__c') site_state,
	 extractvalue(l.rec_xml, '/result/Country__c') site_country,
	 extractvalue(l.rec_xml, '/result/Site_Usage__c') site_usage,
	 decode(extractvalue(l.rec_xml,
		         '/result/Primary_Billing_Address__c'),
	        'false',
	        'N',
	        'Y') primary_bill_to,
	 decode(extractvalue(l.rec_xml,
		         '/result/Primary_Shipping_Address__c'),
	        'false',
	        'N',
	        'Y') primary_ship_to,
	 extractvalue(l.rec_xml, '/result/Site_Status__c') site_status,
	 extractvalue(l.rec_xml, '/result/Oracle_Event_ID__c') sf_oracle_event_id,
	 extractvalue(l.rec_xml, '/result/OE_ID__c') sf_oracle_site_id
      FROM   xxobjt_sf2oa_interface_l l,
	 xxobjt_sf2oa_interface_h h
      WHERE  h.oracle_batch_id = l.oracle_batch_id
      AND    l.oracle_batch_id = p_batch_id
      AND    l.status = 'NEW';

    l_err_code          VARCHAR2(50) := NULL;
    l_err_msg           VARCHAR2(2500) := NULL;
    l_location_id       NUMBER := NULL;
    l_party_site_id     NUMBER := NULL;
    l_cust_acct_site_id NUMBER := NULL;
    l_cust_account_id   NUMBER := NULL;
    l_org_id            NUMBER := NULL;
    l_ship_site_use_id  NUMBER := NULL;
    l_bill_site_use_id  NUMBER := NULL;
    l_party_name        VARCHAR2(360) := NULL;
    l_count             NUMBER := 0;
    l_exist             VARCHAR2(10) := 'N';

    general_exception EXCEPTION;
  BEGIN

    -- set g_user_id SALESFORCE User
    set_salesforce_user;

    fnd_global.apps_initialize(user_id      => g_user_id, -- SALESFORCE
		       resp_id      => 51137, -- CRM Service Super User Objet
		       resp_appl_id => 514); -- Support (obsolete)

    p_err_code := 0;
    p_err_msg  := NULL;
    FOR get_account_pop_r IN get_account_pop_c(p_batch_id) LOOP
      update_sf_id(p_sf_id           => get_account_pop_r.sf_site_id, -- i v
	       p_oracle_event_id => get_account_pop_r.oracle_event_id, -- i n
	       p_err_msg         => l_err_msg, -- o v
	       p_err_code        => l_err_code); -- o v

      update_sf_exist(p_sf_id           => get_account_pop_r.sf_site_id, -- i v
	          p_oracle_event_id => get_account_pop_r.oracle_event_id, -- i n
	          p_err_msg         => l_err_msg, -- o v
	          p_err_code        => l_err_code); -- o v

      SELECT COUNT(1)
      INTO   l_count
      FROM   xxobjt_sf2oa_interface_l l
      WHERE  l.oracle_event_id = get_account_pop_r.oracle_event_id
      AND    l.status = 'OA_HOLD';

      IF l_count = 0 THEN
        BEGIN
          -- 17/10/2012 Dalit A. Raviv
          -- 0) Check if this SF_iD exist allready in oracle
          l_exist := get_sf_id_exist(p_source_name => 'SITE',
			 p_sf_id       => get_account_pop_r.sf_site_id);
          IF l_exist IS NOT NULL THEN
	l_err_code := '0';
	l_err_msg  := 'SD_ID allready Exist in Oracle Site - hz_cust_acct_sites_all s, attribute1 = ' ||
		  get_account_pop_r.sf_site_id;
	update_interface_line_status(p_status          => 'OA_SUCCESS',
			     p_oracle_id       => l_exist,
			     p_sf_id           => get_account_pop_r.sf_site_id,
			     p_oracle_event_id => get_account_pop_r.oracle_event_id,
			     p_err_code        => l_err_code,
			     p_err_msg         => l_err_msg);

	/*update_interface_line_error(p_status          => 'OA_ERR',
            p_oracle_event_id => get_account_pop_r.oracle_event_id,
            p_err_msg         => l_err_msg,
            p_err_code        => l_err_code);*/
	p_err_code := 0;
	p_err_msg  := l_err_msg;
	RAISE general_exception;
          ELSE

	--l_cust_account_id   := null;
	l_location_id       := NULL;
	l_party_site_id     := NULL;
	l_cust_acct_site_id := NULL;

	l_cust_account_id := get_cust_account_id_by_sf_id(get_account_pop_r.sf_account_id);
	IF l_cust_account_id IS NULL THEN
	  p_err_code := 1;
	  p_err_msg  := 'Procedure - handle_sites_in_oracle - did not find account for sf_id - ' ||
		    get_account_pop_r.sf_account_id;

	  -- update interface line with error
	  l_err_msg := 'Procedure - handle_sites_in_oracle - did not find account for sf_id - ' ||
		   get_account_pop_r.sf_account_id;
	  update_interface_line_error(p_status          => 'OA_ERR', -- i n
			      p_oracle_event_id => get_account_pop_r.oracle_event_id, --p_oracle_event_id,        -- i n
			      p_err_msg         => l_err_msg, -- i/o/v
			      p_err_code        => l_err_code); -- o v
	ELSE
	  -- 1) call API's
	  l_err_code := 0;
	  l_err_msg  := NULL;
	  create_location_api(p_country         => get_account_pop_r.site_country, -- i v
		          p_address_line1   => get_account_pop_r.site_address, -- i v
		          p_city            => get_account_pop_r.site_city, -- i v
		          p_postal_code     => get_account_pop_r.site_postal_code, -- i v
		          p_state           => get_account_pop_r.site_state, -- i v
		          p_county          => get_account_pop_r.site_county, -- i v
		          p_oracle_event_id => get_account_pop_r.oracle_event_id, --get_xml_pop_r.oracle_event_id,  -- i n
		          p_location_id     => l_location_id, -- o n
		          p_err_code        => l_err_code, -- o v
		          p_err_msg         => l_err_msg); -- o v

	  IF l_err_code = 1 THEN
	    p_err_code := 1;
	    p_err_msg  := l_err_msg;
	    RAISE general_exception;
	  END IF;
	  l_err_code := 0;
	  l_err_msg  := NULL;
	  create_party_site_api(p_location_id     => l_location_id, -- i n
			p_cust_account_id => l_cust_account_id, -- get_xml_pop_r.sf_account_id,   -- i n ????????
			p_oracle_event_id => get_account_pop_r.oracle_event_id, --get_xml_pop_r.oracle_event_id, -- i n
			--p_country         => get_account_pop_r.site_country, -- i v
			p_party_id      => NULL, -- i v
			p_party_site_id => l_party_site_id, -- o n
			p_err_code      => l_err_code, -- o v
			p_err_msg       => l_err_msg); -- o v

	  IF l_err_code = 1 THEN
	    p_err_code := 1;
	    p_err_msg  := l_err_msg;
	    RAISE general_exception;
	  END IF;
	  create_cust_account_site_api(p_cust_account_id   => l_cust_account_id, -- get_xml_pop_r.sf_account_id,   -- i n ????????
			       p_oracle_event_id   => get_account_pop_r.oracle_event_id, --get_xml_pop_r.oracle_event_id, -- i n
			       p_sf_id             => get_account_pop_r.sf_site_id, -- i v
			       p_party_site_id     => l_party_site_id, -- o n
			       p_cust_acct_site_id => l_cust_acct_site_id, -- o n
			       p_org_id            => l_org_id, -- o n
			       p_party_name        => l_party_name, -- o v
			       p_err_code          => l_err_code, -- o v
			       p_err_msg           => l_err_msg); -- o v

	  IF l_err_code = 0 THEN
	    update_interface_line_status(p_status          => 'OA_SUCCESS',
			         p_oracle_id       => l_cust_acct_site_id,
			         p_sf_id           => get_account_pop_r.sf_site_id,
			         p_oracle_event_id => get_account_pop_r.oracle_event_id,
			         p_err_code        => l_err_code,
			         p_err_msg         => l_err_msg);
	  ELSE
	    p_err_code := 1;
	    p_err_msg  := l_err_msg;
	    RAISE general_exception;
	  END IF;
	  l_err_code := '0';
	  l_err_msg  := NULL;
	  create_cust_site_use_api(p_oracle_event_id   => get_account_pop_r.oracle_event_id, --get_xml_pop_r.oracle_event_id, -- i n
			   p_cust_acct_site_id => l_cust_acct_site_id, -- i n
			   p_org_id            => l_org_id, -- i n
			   p_primary_bill      => get_account_pop_r.primary_bill_to, -- i v
			   p_primary_ship      => get_account_pop_r.primary_ship_to, -- i v
			   p_site_usage        => get_account_pop_r.site_usage, -- i v
			   p_party_name        => l_party_name, -- i v
			   p_ship_site_use_id  => l_ship_site_use_id, -- o n
			   p_bill_site_use_id  => l_bill_site_use_id, -- o n
			   p_err_code          => l_err_code, -- o v
			   p_err_msg           => l_err_msg); -- o v
	  IF l_err_code = 1 THEN
	    p_err_code := 1;
	    p_err_msg  := l_err_msg;
	    RAISE general_exception;
	  ELSE
	    COMMIT; -- 31/10/2012 Dalit A. Raviv
	  END IF;
	END IF; -- l_cust_account_id is null
          END IF; -- l_exist
        EXCEPTION
          WHEN general_exception THEN
	ROLLBACK; -- 31/10/2012 Dalit A. Raviv
	NULL;
        END;
      END IF; -- l_count

    END LOOP; -- population

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - Handle_sites_in_oracle - p_batch_id - ' ||
	        p_batch_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - Handle_sites_in_oracle - ' ||
		   substr(SQLERRM, 1, 240));

  END handle_sites_in_oracle;

  --------------------------------------------------------------------
  --  name:            create_person_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call create Person API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/09/2010  Dalit A. Raviv    initial build
  --  1.1  28/10/2010  Dalit A. Raviv    add person prefix  (sf_salutation)
  --------------------------------------------------------------------
  PROCEDURE create_person_api(p_oracle_event_id IN NUMBER,
		      p_first_name      IN VARCHAR2,
		      p_last_name       IN VARCHAR2,
		      p_sf_salutation   IN VARCHAR2,
		      p_person_party_id OUT NUMBER,
		      p_err_code        OUT VARCHAR2,
		      p_err_msg         OUT VARCHAR2) IS

    l_upd_person    hz_party_v2pub.person_rec_type;
    l_success       VARCHAR2(1) := 'T';
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    x_party_id      NUMBER;
    x_party_number  VARCHAR2(2000);
    x_profile_id    NUMBER;
    l_err_code      VARCHAR2(10) := 0;
    l_err_msg       VARCHAR2(2500) := NULL;
    l_prefix        VARCHAR2(150) := NULL;
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;

    fnd_msg_pub.initialize;

    -- Create contact as person. If OK Continue to RelationShip
    l_upd_person.person_first_name := p_first_name;
    l_upd_person.person_last_name  := p_last_name;
    l_upd_person.created_by_module := g_create_by_module; -- SALESFORCE
    l_upd_person.party_rec.status  := 'A';
    --l_upd_person.person_title      := p_sf_Salutation;
    IF p_sf_salutation IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_prefix
        FROM   ar_lookups al
        WHERE  al.lookup_type = 'CONTACT_TITLE'
        AND    al.meaning = p_sf_salutation; --'Mrs.'

        l_upd_person.person_pre_name_adjunct := l_prefix;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    hz_party_v2pub.create_person(l_success,
		         l_upd_person,
		         x_party_id,
		         x_party_number,
		         x_profile_id,
		         l_return_status,
		         l_msg_count,
		         l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Failed create Contact: ';

      fnd_file.put_line(fnd_file.log, 'Failed create Contact:');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;
      p_err_code := 1;
      ROLLBACK;
      -- update interface line with error
      l_err_msg := substr(p_err_msg, 1, 2000);
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, -- i n
		          p_err_msg         => l_err_msg, -- i/o/v
		          p_err_code        => l_err_code); -- o v
    ELSE
      --commit;
      p_person_party_id := x_party_id;
      p_err_code        := 0;
      p_err_msg         := NULL;
    END IF; -- Status if

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_person_api - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - create_person_api - ' ||
		   substr(SQLERRM, 1, 240));
      l_err_msg  := p_err_msg;
      l_err_code := NULL;
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, -- i n
		          p_err_msg         => l_err_msg, -- i/o/v
		          p_err_code        => l_err_code); -- o v
  END create_person_api;

  --------------------------------------------------------------------
  --  name:            update_person_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   03/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that call update Person API
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/10/2010  Dalit A. Raviv    initial build
  --  1.1  28/10/2010  Dalit A. Raviv    add person prefix  (sf_salutation)
  --------------------------------------------------------------------
  PROCEDURE update_person_api(p_oracle_event_id IN NUMBER,
		      p_first_name      IN VARCHAR2,
		      p_last_name       IN VARCHAR2,
		      p_ovn             IN NUMBER,
		      p_party_id        IN NUMBER,
		      p_sf_salutation   IN VARCHAR2,
		      p_err_code        OUT VARCHAR2,
		      p_err_msg         OUT VARCHAR2) IS

    l_upd_person    hz_party_v2pub.person_rec_type;
    l_success       VARCHAR2(1) := 'T';
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_data          VARCHAR2(2000);
    l_msg_index_out NUMBER;
    x_profile_id    NUMBER;
    l_ovn           NUMBER := NULL;
    l_prefix        VARCHAR2(150) := NULL;
    l_err_msg       VARCHAR2(2500) := NULL;
    l_err_code      VARCHAR2(10) := NULL;
  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;

    fnd_msg_pub.initialize;

    -- Create contact as person. If OK Continue to RelationShip
    l_upd_person.person_first_name  := p_first_name;
    l_upd_person.person_last_name   := p_last_name;
    l_upd_person.party_rec.status   := 'A';
    l_upd_person.party_rec.party_id := p_party_id;
    --l_upd_person.person_title       := p_sf_Salutation;

    IF p_sf_salutation IS NOT NULL THEN
      BEGIN
        SELECT lookup_code
        INTO   l_prefix
        FROM   ar_lookups al
        WHERE  al.lookup_type = 'CONTACT_TITLE'
        AND    al.meaning = p_sf_salutation; --'Mrs.'

        l_upd_person.person_pre_name_adjunct := l_prefix;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF;

    l_ovn := p_ovn;
    hz_party_v2pub.update_person(p_init_msg_list               => l_success, -- i v 'T'
		         p_person_rec                  => l_upd_person, -- i PERSON_REC_TYPE
		         p_party_object_version_number => l_ovn, -- i / o nocopy n
		         x_profile_id                  => x_profile_id, -- o nocopy n
		         x_return_status               => l_return_status, -- o nocopy v
		         x_msg_count                   => l_msg_count, -- o nocopy n
		         x_msg_data                    => l_msg_data -- o nocopy v
		         );

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Failed update Contact: ' || p_party_id || ' - ';

      fnd_file.put_line(fnd_file.log, 'Failed Update Contact -');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);

        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;
      p_err_code := 1;
      ROLLBACK;
      g_num_of_api_e := g_num_of_api_e + 1;
    ELSE
      COMMIT;
      g_num_of_api_s := g_num_of_api_s + 1;
      p_err_code     := 0;
      p_err_msg      := 'Success update Contact - ' || p_party_id;
    END IF; -- Status if

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_person_api - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - update_person_api - ' ||
		   substr(SQLERRM, 1, 240));
      l_err_msg  := p_err_msg;
      l_err_code := 1;
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, -- i n
		          p_err_msg         => l_err_msg, -- i/o/v
		          p_err_code        => l_err_code); -- o v
  END update_person_api;

  --------------------------------------------------------------------
  --  name:            create_person_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/09/2010  Dalit A. Raviv    initial build
  --  1.1  15/04/2012  Dalit A. Raviv    There is a problem that new job_title at SF did not enter
  --                                     to lookup 'RESPONSIBILITY'. this cause that person do create at
  --                                     oracle but because of the job title error SF do not update with oracle_id
  --                                     and therefor continue sending (and creating) each hour the same data
  --                                     to update oracle. the solution is to mark the row as OA_WARNING
  --                                     and oracle_id istead of OA_ERR.
  --                                     1) add global variable g_job_title
  --                                     2) init and call this global from procedure create_org_contact_api
  --                                     3) refer to this global at procedure create_new_contact.
  --------------------------------------------------------------------
  PROCEDURE create_org_contact_api(p_subject_id       IN NUMBER,
		           p_subject_type     IN VARCHAR2,
		           p_object_id        IN NUMBER,
		           p_object_type      IN VARCHAR2,
		           p_relation_code    IN VARCHAR2,
		           p_relation_type    IN VARCHAR2,
		           p_object_tble_name IN VARCHAR2,
		           p_title            IN VARCHAR2,
		           p_oracle_event_id  IN NUMBER,
		           p_contact_party    OUT NUMBER,
		           p_party_number     OUT NUMBER,
		           p_err_code         OUT VARCHAR2,
		           p_err_msg          OUT VARCHAR2) IS

    l_success         VARCHAR2(1) := 'T';
    p_org_contact_rec hz_party_contact_v2pub.org_contact_rec_type;
    l_return_status   VARCHAR2(2000);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    x_party_rel_id    NUMBER;
    x_party_id        NUMBER;
    x_party_number    VARCHAR2(2000);
    x_org_contact_id  NUMBER;
    l_msg_index_out   NUMBER;
    l_data            VARCHAR2(2000);
    l_err_msg         VARCHAR2(2500) := NULL;
    l_err_code        VARCHAR2(10) := 0;
    l_sf_title        VARCHAR2(150) := NULL;

  BEGIN

    p_err_msg        := 0;
    p_err_code       := NULL;
    l_return_status  := NULL;
    l_msg_count      := NULL;
    l_msg_data       := NULL;
    x_org_contact_id := NULL;
    x_party_id       := NULL;
    x_party_number   := NULL;
    -- 1.1 15/04/2012 Dalit A. Raviv
    g_job_title := 'N';
    --
    fnd_msg_pub.initialize;

    IF p_title IS NOT NULL THEN
      BEGIN
        SELECT flv.lookup_code
        INTO   l_sf_title
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = 'RESPONSIBILITY'
        AND    flv.language = 'US'
        AND    flv.enabled_flag = 'Y'
        AND    nvl(flv.end_date_active, SYSDATE + 1) > SYSDATE
        AND    upper(flv.meaning) = upper(p_title);

        p_org_contact_rec.job_title_code := l_sf_title; --p_title;
        p_org_contact_rec.job_title      := p_title; --p_title;
      EXCEPTION
        WHEN OTHERS THEN
          -- 1.1 15/04/2012 Dalit A. Raviv
          g_job_title := 'Y';
          --p_err_code  := 1;
        --p_err_msg   := 'create_org_contact_api - Invalid Title :' || p_title;
        --l_err_msg   := 'create_org_contact_api - Invalid Title :' || p_title;
        /*
        update_interface_line_error(p_status          => 'OA_ERR',
                                    p_oracle_event_id => p_oracle_event_id,
                                    p_err_msg         => l_err_msg,
                                    p_err_code        => l_err_code);
        */
        -- end 1.1
      END;
    END IF; -- p_title

    p_org_contact_rec.created_by_module := g_create_by_module; --'SALESFORCE';

    p_org_contact_rec.party_rel_rec.subject_id         := p_subject_id;
    p_org_contact_rec.party_rel_rec.subject_type       := p_subject_type;
    p_org_contact_rec.party_rel_rec.subject_table_name := 'HZ_PARTIES';
    p_org_contact_rec.party_rel_rec.object_id          := p_object_id;
    p_org_contact_rec.party_rel_rec.object_type        := p_object_type;
    p_org_contact_rec.party_rel_rec.object_table_name  := p_object_tble_name;
    p_org_contact_rec.party_rel_rec.relationship_code  := p_relation_code;
    p_org_contact_rec.party_rel_rec.relationship_type  := p_relation_type;
    p_org_contact_rec.party_rel_rec.start_date         := SYSDATE;
    p_org_contact_rec.party_rel_rec.status             := 'A';

    hz_party_contact_v2pub.create_org_contact(l_success,
			          p_org_contact_rec,
			          x_org_contact_id,
			          x_party_rel_id,
			          x_party_id,
			          x_party_number,
			          l_return_status,
			          l_msg_count,
			          l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Error create org contact: ';

      fnd_file.put_line(fnd_file.log, 'Creation of org contact Failed -');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;
      p_err_code := 1;
      ROLLBACK;

      -- update interface line with error
      l_err_msg := substr(p_err_msg, 1, 2000);
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, -- i n
		          p_err_msg         => l_err_msg, -- i/o/v
		          p_err_code        => l_err_code); -- o v
    ELSE
      --commit;
      p_contact_party := x_party_id;
      p_party_number  := x_party_number;
    END IF; -- Status if
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_org_contact_api - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - create_org_contact_api - ' ||
		   substr(SQLERRM, 1, 240));
      l_err_msg  := p_err_msg;
      l_err_code := NULL;
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, -- i n
		          p_err_msg         => l_err_msg, -- i/o/v
		          p_err_code        => l_err_code); -- o v
  END create_org_contact_api;

  --------------------------------------------------------------------
  --  name:            update_person_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   26/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Update job title at org contact details
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  26/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_org_contact_api(p_title           IN VARCHAR2,
		           p_sf_title        IN VARCHAR2,
		           p_oracle_event_id IN NUMBER,
		           p_cont_ovn        IN NUMBER,
		           p_rel_ovn         IN NUMBER,
		           p_party_ovn       IN NUMBER,
		           p_org_contact_id  IN NUMBER,
		           p_err_code        OUT VARCHAR2,
		           p_err_msg         OUT VARCHAR2) IS

    l_success         VARCHAR2(1) := 'T';
    l_org_contact_rec hz_party_contact_v2pub.org_contact_rec_type;
    l_return_status   VARCHAR2(2000);
    l_msg_count       NUMBER;
    l_msg_data        VARCHAR2(2000);
    l_msg_index_out   NUMBER;
    l_data            VARCHAR2(2000);
    l_cont_ovn        NUMBER := NULL;
    l_rel_ovn         NUMBER := NULL;
    l_party_ovn       NUMBER := NULL;
    l_err_msg         VARCHAR2(2500) := NULL;
    l_err_code        VARCHAR2(10) := NULL;

  BEGIN

    p_err_msg  := 0;
    p_err_code := NULL;

    l_return_status := NULL;
    l_msg_count     := NULL;
    l_msg_data      := NULL;

    fnd_msg_pub.initialize;

    l_org_contact_rec.job_title_code := p_title;
    l_org_contact_rec.job_title      := p_sf_title;
    l_org_contact_rec.org_contact_id := p_org_contact_id;

    l_cont_ovn  := p_cont_ovn;
    l_rel_ovn   := p_rel_ovn;
    l_party_ovn := p_party_ovn;
    hz_party_contact_v2pub.update_org_contact(p_init_msg_list               => l_success, -- i v
			          p_org_contact_rec             => l_org_contact_rec, -- i   ORG_CONTACT_REC_TYPE
			          p_cont_object_version_number  => l_cont_ovn, -- i/o nocopy n
			          p_rel_object_version_number   => l_rel_ovn, -- i/o nocopy n
			          p_party_object_version_number => l_party_ovn, -- i/o nocopy n
			          x_return_status               => l_return_status, -- o   nocopy v
			          x_msg_count                   => l_msg_count, -- o   nocopy n
			          x_msg_data                    => l_msg_data); -- o   nocopy v

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Failed Update org contact: p_org_contact_id - ' ||
	       p_org_contact_id || ' - ';

      fnd_file.put_line(fnd_file.log, 'Failed Update org contact -');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;
      p_err_code := 1;
      ROLLBACK;

    ELSE
      COMMIT;
      p_err_code := 0;
      p_err_msg  := 'Success Update org contact: org_contact_id: ' ||
	        p_org_contact_id;
    END IF; -- Status if
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_org_contact_api - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - update_org_contact_api - ' ||
		   substr(SQLERRM, 1, 240));
      l_err_msg  := p_err_msg;
      l_err_code := 1;
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, -- i n
		          p_err_msg         => l_err_msg, -- i/o/v
		          p_err_code        => l_err_code); -- o v
  END update_org_contact_api;

  --------------------------------------------------------------------
  --  name:            create_cust_account_role_api
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   27/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that create cust account role
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_cust_account_role_api(p_contact_party        IN NUMBER,
			     p_cust_account_id      IN NUMBER,
			     p_oracle_event_id      IN NUMBER,
			     p_sf_id                IN VARCHAR2,
			     p_cust_account_role_id OUT NUMBER,
			     p_err_code             OUT VARCHAR2,
			     p_err_msg              OUT VARCHAR2) IS

    l_success              VARCHAR2(1) := 'T';
    x_cust_account_role_id NUMBER(10);
    l_return_status        VARCHAR2(2000);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(2000);
    l_msg_index_out        NUMBER;
    l_data                 VARCHAR2(2000);
    l_err_msg              VARCHAR2(2500) := NULL;
    l_err_code             VARCHAR2(10) := 0;
    l_cr_cust_acc_role_rec hz_cust_account_role_v2pub.cust_account_role_rec_type;

  BEGIN
    p_err_msg  := 0;
    p_err_code := NULL;

    l_cr_cust_acc_role_rec.party_id          := p_contact_party;
    l_cr_cust_acc_role_rec.cust_account_id   := p_cust_account_id;
    l_cr_cust_acc_role_rec.primary_flag      := 'N';
    l_cr_cust_acc_role_rec.role_type         := 'CONTACT';
    l_cr_cust_acc_role_rec.created_by_module := g_create_by_module; --'SALESFORCE';
    l_cr_cust_acc_role_rec.attribute1        := p_sf_id;

    fnd_msg_pub.initialize;
    hz_cust_account_role_v2pub.create_cust_account_role(l_success,
				        l_cr_cust_acc_role_rec,
				        x_cust_account_role_id,
				        l_return_status,
				        l_msg_count,
				        l_msg_data);

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      p_err_msg := 'Error create cust account role: ';

      fnd_file.put_line(fnd_file.log,
		'Creation of cust account role Failed -');
      fnd_file.put_line(fnd_file.log,
		'l_msg_data = ' || substr(l_msg_data, 1, 2000));
      FOR i IN 1 .. l_msg_count LOOP
        fnd_msg_pub.get(p_msg_index     => i,
		p_data          => l_data,
		p_encoded       => fnd_api.g_false,
		p_msg_index_out => l_msg_index_out);
        fnd_file.put_line(fnd_file.log, 'l_Data - ' || l_data);
        p_err_msg := substr(p_err_msg || l_data || chr(10), 1, 2000);
      END LOOP;
      p_err_code := 1;
      ROLLBACK;
      -- update interface line with error
      l_err_msg := substr(p_err_msg, 1, 2000);
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, -- i n
		          p_err_msg         => l_err_msg, -- i/o/v
		          p_err_code        => l_err_code); -- o v
    ELSE
      --commit;
      p_cust_account_role_id := x_cust_account_role_id;
    END IF; -- Status if

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - create_cust_account_role_api - p_oracle_event_id - ' ||
	        p_oracle_event_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - create_cust_account_role_api - ' ||
		   substr(SQLERRM, 1, 240));
      l_err_msg  := p_err_msg;
      l_err_code := NULL;
      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, -- i n
		          p_err_msg         => l_err_msg, -- i/o/v
		          p_err_code        => l_err_code); -- o v
  END create_cust_account_role_api;

  --------------------------------------------------------------------
  --  name:            create_new_contact
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   03/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that Handle update CONTACTS
  --                   1) check and update person details
  --                   2) check and update location details
  --                   3) check and update org_contact job title code
  --                   4) check and update contact point details (phone, mobile, email)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/10/2010  Dalit A. Raviv    initial build
  --  1.1  26/10/2010  Dalit A. Raviv    add sf_fax number option
  --  1.2  28/10/2010  Dalit A. Raviv    add person prefix (sf_salutation)
  --  1.3  15.8.2016   yuval tal         INC0066076  check when no need to update location
  --  1.4  11.9 2016   yuval tal         INC0076039 disable phone updates
  --------------------------------------------------------------------
  PROCEDURE update_new_contact(p_cust_account_role_id IN NUMBER,
		       p_oracle_event_id      IN NUMBER, --get_account_pop_r.oracle_event_id
		       p_sf_first_name        IN VARCHAR2, --get_xml_pop_r.sf_firstname
		       p_sf_last_name         IN VARCHAR2, --get_xml_pop_r.sf_lastname
		       p_sf_country           IN VARCHAR2, --get_xml_pop_r.sf_country
		       p_sf_address_line1     IN VARCHAR2, --get_xml_pop_r.sf_address_1
		       p_sf_city              IN VARCHAR2, --get_xml_pop_r.sf_city
		       p_sf_postal_code       IN VARCHAR2, --get_xml_pop_r.sf_zipcode_postal_code
		       p_sf_state             IN VARCHAR2, --get_xml_pop_r.sf_state_region
		       p_sf_county            IN VARCHAR2, --get_xml_pop_r.sf_county
		       p_sf_title             IN VARCHAR2, --get_xml_pop_r.sf_title
		       p_sf_phone_number      IN VARCHAR2, --get_xml_pop_r.sf_phone
		       p_sf_mobile_phone      IN VARCHAR2, --get_xml_pop_r.sf_mobilephone
		       p_sf_email             IN VARCHAR2, --get_xml_pop_r.sf_email
		       p_sf_fax               IN VARCHAR2, --get_xml_pop_r.sf_fax
		       p_sf_salutation        IN VARCHAR2, --get_xml_pop_r.sf_Salutation
		       p_sf_contact_id        IN VARCHAR2, --get_xml_pop_r.sf_contact_id
		       p_sf_account_id        IN VARCHAR2,
		       p_err_code             OUT VARCHAR2,
		       p_err_msg              OUT VARCHAR2) IS

    CURSOR get_contact_upd_pop_c IS
      SELECT hcar.party_id contact_party_id,
	 hps.location_id location_id,
	 hl.country country,
	 hl.county county,
	 hl.state state,
	 hl.city city,
	 hl.address1 address1,
	 hl.postal_code postal_code,
	 hl.object_version_number location_ovn, --
	 hr.subject_id person_party_id, -- person party id
	 hr.object_id hz_party_id, -- party_id (cust account)
	 hp.person_first_name person_first_name,
	 hp.person_last_name person_last_name,
	 hp.person_pre_name_adjunct,
	 hp.object_version_number hp_ovn, --
	 nvl(hoc.job_title_code, 'DAR') job_title_code,
	 hoc.org_contact_id org_contact_id,
	 hoc.object_version_number hoc_ovn, --
	 hr.relationship_id relationship_id,
	 hr.object_version_number rel_ovn, --
	 (SELECT hp.object_version_number
	  FROM   hz_parties hp
	  WHERE  hp.party_id = hr.subject_id) person_ovn
      FROM   hz_cust_account_roles hcar,
	 hz_party_sites        hps,
	 hz_locations          hl,
	 hz_relationships      hr,
	 hz_parties            hp,
	 hz_org_contacts       hoc
      WHERE  hcar.cust_account_role_id = p_cust_account_role_id --668045
      AND    hps.party_id(+) = hcar.party_id -- contact_party_id
      AND    hps.location_id = hl.location_id(+)
      AND    hr.subject_type = 'PERSON'
      AND    hr.party_id = hcar.party_id -- contact_party_id
      AND    hp.party_id = hr.subject_id -- person_party_id
      AND    hoc.party_relationship_id = hr.relationship_id;

    --phone_line_type    = null,    'FAX', 'GEN', 'MOBILE'
    --contact_point_type = 'EMAIL', 'PHONE'
    CURSOR get_contact_point_details_c(p_contact_party_id   IN NUMBER,
			   p_contact_point_type IN VARCHAR2,
			   p_line_type          IN VARCHAR2) IS
      SELECT *
      FROM   hz_contact_points hcp
      WHERE  hcp.owner_table_id = p_contact_party_id -- 1618046 -- contact_party_id
      AND    hcp.contact_point_type = p_contact_point_type
      AND    hcp.created_by_module = 'SALESFORCE'
      AND    ((p_line_type = 'GEN' AND hcp.primary_flag = 'Y' AND
	hcp.phone_line_type = p_line_type) OR
	(hcp.phone_line_type = p_line_type OR p_line_type IS NULL));

    l_err_code         VARCHAR2(5) := NULL;
    l_err_msg          VARCHAR2(2500) := NULL;
    l_territory_code   VARCHAR2(5) := NULL;
    l_sf_title         VARCHAR2(150) := NULL;
    l_location_id      NUMBER := NULL;
    l_cust_account_id  NUMBER := NULL;
    l_party_site_id    NUMBER := NULL;
    l_count            NUMBER := 0;
    l_contact_point_id NUMBER := 0;
    l_change           VARCHAR2(5) := 'N';
    l_prefix           VARCHAR2(150) := NULL;
    l_tmp              NUMBER;
  BEGIN
    p_err_code     := 0;
    p_err_msg      := NULL;
    g_num_of_api_e := 0;
    g_num_of_api_s := 0;

    FOR get_contact_upd_pop_r IN get_contact_upd_pop_c LOOP
      -----------------------------------------
      -- 1) check and update person
      -----------------------------------------

      IF p_sf_salutation IS NOT NULL THEN
        BEGIN
          SELECT lookup_code
          INTO   l_prefix
          FROM   ar_lookups al
          WHERE  al.lookup_type = 'CONTACT_TITLE'
          AND    al.meaning = p_sf_salutation; --'Mrs.'
        EXCEPTION
          WHEN OTHERS THEN
	l_prefix := NULL;
        END;
      END IF;

      IF (p_sf_first_name <> get_contact_upd_pop_r.person_first_name AND
         p_sf_first_name IS NOT NULL) OR
         (p_sf_last_name <> get_contact_upd_pop_r.person_last_name AND
         p_sf_last_name IS NOT NULL) OR
         (l_prefix <> get_contact_upd_pop_r.person_pre_name_adjunct AND
         p_sf_salutation IS NOT NULL) THEN
        l_err_code := 0;
        l_err_msg  := NULL;
        update_person_api(p_oracle_event_id => p_oracle_event_id, -- i n
		  p_first_name      => p_sf_first_name, -- i v
		  p_last_name       => p_sf_last_name, -- i v
		  p_ovn             => get_contact_upd_pop_r.person_ovn, -- i n
		  p_party_id        => get_contact_upd_pop_r.person_party_id, -- i n
		  p_sf_salutation   => p_sf_salutation,
		  p_err_code        => l_err_code, -- o v
		  p_err_msg         => l_err_msg); -- o v
        IF l_err_code <> 0 THEN
          p_err_code := 1;
          p_err_msg  := p_err_msg || ' - ' || l_err_msg;
        END IF;
        update_interface_line_status(p_status          => 'OA_SUCCESS',
			 p_oracle_id       => p_cust_account_role_id, -- i n
			 p_sf_id           => p_sf_contact_id, -- i v
			 p_oracle_event_id => p_oracle_event_id, -- i n
			 p_entity          => 'UPDATE', -- i v
			 p_msg             => l_err_msg, -- i v
			 p_err_code        => l_err_code, -- o v
			 p_err_msg         => l_err_msg); -- o v
      END IF;
      -----------------------------------------
      -- 2) check and update location
      -----------------------------------------
      BEGIN
        IF p_sf_country IS NOT NULL THEN
          SELECT territory_code
          INTO   l_territory_code
          FROM   fnd_territories_vl t
          WHERE  upper(territory_short_name) = upper(p_sf_country);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          l_territory_code := NULL;
      END;

      --- INC0066076  check no need to update location
      -- check duplicate call /no change in location compare with last call
      -- get last rec  set cursor variables with new values instead of those pulled from hz_location

      BEGIN
        SELECT --h.source_name,
         l.oracle_event_id,
         extractvalue(l.rec_xml, '/result/Address_1__c') sf_address_1, --
         extractvalue(l.rec_xml, '/result/City__c') sf_city, --
         extractvalue(l.rec_xml, '/result/Country__c') sf_country, --
         extractvalue(l.rec_xml, '/result/County__c') sf_county, --
         extractvalue(l.rec_xml, '/result/State_Region__c') sf_state_region, --
         extractvalue(l.rec_xml, '/result/Zipcode_Postal_Code__c') sf_zipcode_postal_code --
        INTO   l_tmp,
	   get_contact_upd_pop_r.address1,
	   get_contact_upd_pop_r.city,
	   get_contact_upd_pop_r.country,
	   get_contact_upd_pop_r.county,
	   get_contact_upd_pop_r.state,
	   get_contact_upd_pop_r.postal_code

        FROM   xxobjt_sf2oa_interface_l l
        WHERE  l.oracle_id = p_cust_account_role_id
        AND    oracle_event_id =
	   (SELECT MAX(oracle_event_id)
	     FROM   xxobjt_sf2oa_interface_l l2
	     WHERE  /* l2.status IN ('OA_SUCCESS', 'OA_HOLD')
                                                                                                                                                                                                                                              AND   */
	      oracle_event_id < p_oracle_event_id
	  AND    l.oracle_id = l2.oracle_id);
        /* dbms_output.put_line('found last request for :' ||
                             p_oracle_event_id || 'l_tmp=' || l_tmp);

        dbms_output.put_line('current  location details:' ||
                             p_sf_address_line1 || '- ' || p_sf_city || '-' ||
                             p_sf_country || ' -' || p_sf_county || '-' ||
                             p_sf_state || '- ' || p_sf_postal_code);
        dbms_output.put_line('last     location details:' ||
                             get_contact_upd_pop_r.address1 || '-' ||
                             get_contact_upd_pop_r.city || '-' ||
                             get_contact_upd_pop_r.country || '-' ||
                             get_contact_upd_pop_r.county || '-' ||
                             get_contact_upd_pop_r.state || '-' ||
                             get_contact_upd_pop_r.postal_code);*/

      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
      --- end INC0066076  check no need to update location
      ----INC0066076 add trim
      IF nvl(TRIM(p_sf_address_line1), 'DAR') <>
         nvl(TRIM(get_contact_upd_pop_r.address1), 'DAR') OR
         nvl(TRIM(p_sf_city), 'DAR') <>
         nvl(TRIM(get_contact_upd_pop_r.city), 'DAR') OR
         nvl(TRIM(p_sf_postal_code), 'DAR') <>
         nvl(TRIM(get_contact_upd_pop_r.postal_code), 'DAR') OR
         nvl(TRIM(p_sf_state), 'DAR') <>
         nvl(TRIM(get_contact_upd_pop_r.state), 'DAR') OR
         nvl(TRIM(p_sf_county), 'DAR') <>
         nvl(TRIM(get_contact_upd_pop_r.county), 'DAR') OR
         nvl(TRIM(p_sf_country), 'DAR') <>
         nvl(TRIM(get_contact_upd_pop_r.country), 'DAR') THEN
        --  dbms_output.put_line('location changed  :' || p_oracle_event_id);
        --------------------------
        -- Update exsist location
        --------------------------
        IF get_contact_upd_pop_r.location_id IS NOT NULL THEN
          l_err_code := 0;
          l_err_msg  := NULL;
          update_location_api(p_country         => p_sf_country, -- i v
		      p_address_line1   => p_sf_address_line1, -- i v
		      p_city            => p_sf_city, -- i v
		      p_postal_code     => p_sf_postal_code, -- i v
		      p_state           => p_sf_state, -- i v
		      p_county          => p_sf_county, -- i v
		      p_oracle_event_id => p_oracle_event_id, -- i n
		      p_ovn             => get_contact_upd_pop_r.location_ovn, -- i n
		      p_location_id     => get_contact_upd_pop_r.location_id, -- i n
		      p_err_code        => l_err_code, -- o v
		      p_err_msg         => l_err_msg); -- o v
          IF l_err_code <> 0 THEN
	p_err_code := 1;
	p_err_msg  := p_err_msg || ' - ' || l_err_msg;
          END IF;
          update_interface_line_status(p_status          => 'OA_SUCCESS',
			   p_oracle_id       => p_cust_account_role_id, -- i n
			   p_sf_id           => p_sf_contact_id, -- i v
			   p_oracle_event_id => p_oracle_event_id, -- i n
			   p_entity          => 'UPDATE', -- i v
			   p_msg             => l_err_msg, -- i v
			   p_err_code        => l_err_code, -- o v
			   p_err_msg         => l_err_msg); -- o v
          -----------------------
          -- Create new location
          -----------------------
        ELSE
          l_err_code := 0;
          l_err_msg  := NULL;
          create_location_api(p_country         => p_sf_country, -- i v
		      p_address_line1   => p_sf_address_line1, -- i v
		      p_city            => p_sf_city, -- i v
		      p_postal_code     => p_sf_postal_code, -- i v
		      p_state           => p_sf_state, -- i v
		      p_county          => p_sf_county, -- i v
		      p_oracle_event_id => p_oracle_event_id, -- i n
		      p_entity          => 'UPDATE', -- i v
		      p_location_id     => l_location_id, -- o n
		      p_err_code        => l_err_code, -- o v
		      p_err_msg         => l_err_msg); -- o v
          IF l_err_code = 1 THEN
	p_err_code     := 1;
	p_err_msg      := l_err_msg;
	g_num_of_api_e := g_num_of_api_e + 1;
	update_interface_line_status(p_status          => 'OA_SUCCESS',
			     p_oracle_id       => p_cust_account_role_id, -- i n
			     p_sf_id           => p_sf_contact_id, -- i v
			     p_oracle_event_id => p_oracle_event_id, -- i n
			     p_entity          => 'UPDATE', -- i v
			     p_msg             => 'Failed create location (upd) - ' ||
					  l_err_msg, -- i v
			     p_err_code        => l_err_code, -- o v
			     p_err_msg         => l_err_msg); -- o v
          ELSE
	dbms_output.put_line('create location - location id - ' ||
		         l_location_id);
          END IF;

          IF l_location_id IS NOT NULL THEN
	BEGIN
	  SELECT hca.cust_account_id
	  INTO   l_cust_account_id
	  FROM   hz_cust_accounts hca
	  WHERE  hca.attribute4 = p_sf_account_id;
	  dbms_output.put_line('l_cust_account_id - ' ||
		           l_cust_account_id);
	EXCEPTION
	  WHEN OTHERS THEN
	    l_cust_account_id := NULL;
	END;
	create_party_site_api(p_location_id     => l_location_id, -- i n
		          p_cust_account_id => l_cust_account_id, -- i n get_xml_pop_r.sf_account_id
		          p_oracle_event_id => p_oracle_event_id, -- i n get_xml_pop_r.oracle_event_id
		          --p_country         => p_sf_country, -- i v get_xml_pop_r.sf_country
		          p_party_id      => get_contact_upd_pop_r.contact_party_id, -- i v
		          p_entity        => 'UPDATE', -- i v
		          p_party_site_id => l_party_site_id, -- o n
		          p_err_code      => l_err_code, -- o v
		          p_err_msg       => l_err_msg); -- o v

	IF l_err_code = 1 THEN
	  p_err_code     := 1;
	  p_err_msg      := l_err_msg;
	  g_num_of_api_e := g_num_of_api_e + 1;
	  ROLLBACK;
	  update_interface_line_status(p_status          => 'OA_SUCCESS',
			       p_oracle_id       => p_cust_account_role_id, -- i n
			       p_sf_id           => p_sf_contact_id, -- i v
			       p_oracle_event_id => p_oracle_event_id, -- i n
			       p_entity          => 'UPDATE', -- i v
			       p_msg             => 'Failed create_party_site (upd) - ' ||
					    l_err_msg, -- i v
			       p_err_code        => l_err_code, -- o v
			       p_err_msg         => l_err_msg); -- o v
	ELSE
	  dbms_output.put_line('Create party site - party site id - ' ||
		           l_party_site_id);
	  COMMIT;
	  g_num_of_api_s := g_num_of_api_s + 1;
	  update_interface_line_status(p_status          => 'OA_SUCCESS',
			       p_oracle_id       => p_cust_account_role_id, -- i n
			       p_sf_id           => p_sf_contact_id, -- i v
			       p_oracle_event_id => p_oracle_event_id, -- i n
			       p_entity          => 'UPDATE', -- i v
			       p_msg             => 'Success create party site and location (upd)' ||
					    'Location id - ' ||
					    l_location_id, -- i v
			       p_err_code        => l_err_code, -- o v
			       p_err_msg         => l_err_msg); -- o v
	END IF;
          ELSE
	ROLLBACK;
          END IF;
        END IF;
      ELSE
        dbms_output.put_line('no need to update location ');
      END IF;
      -----------------------------------------
      -- 3) check and update org_contact job title code
      -----------------------------------------
      IF p_sf_title IS NOT NULL THEN
        BEGIN
          SELECT flv.lookup_code
          INTO   l_sf_title
          FROM   fnd_lookup_values flv
          WHERE  flv.lookup_type = 'RESPONSIBILITY'
          AND    flv.language = 'US'
          AND    flv.enabled_flag = 'Y'
          AND    nvl(flv.end_date_active, SYSDATE + 1) > SYSDATE
          AND    upper(flv.meaning) = upper(p_sf_title);
        EXCEPTION
          WHEN OTHERS THEN
	l_sf_title := NULL;
	update_interface_line_status(p_status          => 'OA_WARNING',
			     p_oracle_id       => p_cust_account_role_id, -- i n
			     p_sf_id           => p_sf_contact_id, -- i v
			     p_oracle_event_id => p_oracle_event_id, -- i n
			     p_entity          => 'UPDATE', -- i v
			     p_msg             => 'Update org contact failed, title is not valid: ' ||
					  p_sf_title, -- i v
			     p_err_code        => l_err_code, -- o v
			     p_err_msg         => l_err_msg); -- o v
        END;
        IF (l_sf_title <> get_contact_upd_pop_r.job_title_code AND
           l_sf_title IS NOT NULL) THEN
          l_err_code := 0;
          l_err_msg  := NULL;
          update_org_contact_api(p_title           => l_sf_title, --p_sf_title,        -- i v
		         p_sf_title        => p_sf_title,
		         p_oracle_event_id => p_oracle_event_id, -- i n
		         p_cont_ovn        => get_contact_upd_pop_r.hoc_ovn, -- i n
		         p_rel_ovn         => get_contact_upd_pop_r.rel_ovn, -- i n
		         p_party_ovn       => get_contact_upd_pop_r.hp_ovn, -- i n
		         p_org_contact_id  => get_contact_upd_pop_r.org_contact_id, -- i n
		         p_err_code        => l_err_code, -- o v
		         p_err_msg         => l_err_msg); -- o v
          IF l_err_code <> 0 THEN
	p_err_code := 1;
	p_err_msg  := p_err_msg || ' - ' || l_err_msg;
          END IF;

          update_interface_line_status(p_status          => 'OA_SUCCESS',
			   p_oracle_id       => p_cust_account_role_id, -- i n
			   p_sf_id           => p_sf_contact_id, -- i v
			   p_oracle_event_id => p_oracle_event_id, -- i n
			   p_entity          => 'UPDATE', -- i v
			   p_msg             => l_err_msg, -- i v
			   p_err_code        => l_err_code, -- o v
			   p_err_msg         => l_err_msg); -- o v
        END IF;
      END IF;
      -----------------------------------------
      -- 4) check and update contact point
      -----------------------------------------
      -- Handle Phone number
      -- yy avoid phone manipulation in contact update mode
      /*   iF p_sf_phone_number IS NOT NULL THEN

            -- check contact exist in oracle and update if not create

            l_count    := 0;
            l_err_code := 0;
            l_err_msg  := NULL;
            l_change   := 'N';
            SELECT COUNT(1)
            INTO   l_count
            FROM   hz_contact_points hcp
            WHERE  hcp.owner_table_id = get_contact_upd_pop_r.contact_party_id
            AND    hcp.contact_point_type = 'PHONE'
            AND    hcp.phone_line_type = 'GEN'
            AND    hcp.created_by_module = 'SALESFORCE';

            IF l_count <> 0 THEN

              FOR get_contact_point_details_r IN get_contact_point_details_c(get_contact_upd_pop_r.contact_party_id,
                                                                             'PHONE',
                                                                             'GEN') LOOP
                IF p_sf_phone_number <>
                   get_contact_point_details_r.phone_number THEN
                  l_change := 'Y';
                  update_contact_point_api(p_oracle_event_id  => p_oracle_event_id, -- i n
                                           p_party_id         => get_contact_upd_pop_r.contact_party_id, -- i n
                                           p_phone_number     => p_sf_phone_number, -- i v
                                           p_mobile_phone     => NULL, -- i v
                                           p_email            => NULL, -- i v
                                           p_fax              => NULL, -- i v
                                           p_ovn              => get_contact_point_details_r.object_version_number, -- i n
                                           p_contact_point_id => get_contact_point_details_r.contact_point_id, -- i n
                                           p_err_code         => l_err_code, -- o v
                                           p_err_msg          => l_err_msg); -- o v
                END IF;
              END LOOP;

              --- need to create new phone contact point
            ELSE
              l_change := 'Y';
              create_contact_point_api(p_oracle_event_id  => p_oracle_event_id, -- i n
                                       p_party_id         => get_contact_upd_pop_r.person_party_id, -- i n
                                       p_phone_number     => p_sf_phone_number, -- i v
                                       p_fax_number       => NULL,
                                       p_url              => NULL,
                                       p_mobile_phone     => NULL,
                                       p_email            => NULL,
                                       p_entity           => 'UPDATE',
                                       p_contact_point_id => l_contact_point_id, -- o n
                                       p_err_code         => l_err_code, -- o v
                                       p_err_msg          => l_err_msg); -- o v
            END IF; -- l_count
            IF l_change = 'Y' THEN
              IF l_err_code <> 0 THEN
                p_err_code     := 1;
                p_err_msg      := p_err_msg || ' - ' || l_err_msg;
                g_num_of_api_e := g_num_of_api_e + 1;
              ELSE
                g_num_of_api_s := g_num_of_api_s + 1;
                l_err_msg      := l_err_msg || ' Success create Phone contact';
              END IF;
              update_interface_line_status(p_status          => 'OA_SUCCESS',
                                           p_oracle_id       => p_cust_account_role_id, -- i n
                                           p_sf_id           => p_sf_contact_id, -- i v
                                           p_oracle_event_id => p_oracle_event_id, -- i n
                                           p_entity          => 'UPDATE', -- i v
                                           p_msg             => 'Phone - ' ||
                                                                l_err_msg, -- i v
                                           p_err_code        => l_err_code, -- o v
                                           p_err_msg         => l_err_msg); -- o v
            END IF; -- l_changed
          END IF; -- phone

        -- Handle Mobile Phone number
        IF p_sf_mobile_phone IS NOT NULL THEN
          -- check contact exist in oracle and update if not create
          l_count    := 0;
          l_err_code := 0;
          l_err_msg  := NULL;
          l_change   := 'N';
          SELECT COUNT(1)
          INTO   l_count
          FROM   hz_contact_points hcp
          WHERE  hcp.owner_table_id = get_contact_upd_pop_r.contact_party_id
          AND    hcp.contact_point_type = 'PHONE'
          AND    hcp.phone_line_type = 'MOBILE'
          AND    hcp.created_by_module = 'SALESFORCE';

          IF l_count <> 0 THEN
            FOR get_contact_point_details_r IN get_contact_point_details_c(get_contact_upd_pop_r.contact_party_id,
                                                                           'PHONE',
                                                                           'MOBILE') LOOP
              IF p_sf_mobile_phone <>
                 get_contact_point_details_r.phone_number THEN
                l_change := 'Y';
                update_contact_point_api(p_oracle_event_id  => p_oracle_event_id, -- i n
                                         p_party_id         => get_contact_upd_pop_r.contact_party_id, -- i n
                                         p_phone_number     => NULL, -- i v
                                         p_mobile_phone     => p_sf_mobile_phone, -- i v
                                         p_email            => NULL, -- i v
                                         p_fax              => NULL, -- i v
                                         p_ovn              => get_contact_point_details_r.object_version_number, -- i n
                                         p_contact_point_id => get_contact_point_details_r.contact_point_id, -- i n
                                         p_err_code         => l_err_code, -- o v
                                         p_err_msg          => l_err_msg); -- o v
              END IF;
            END LOOP;
            --- need to create new Mobile contact point
          ELSE
            l_change := 'Y';
            create_contact_point_api(p_oracle_event_id  => p_oracle_event_id, -- i n
                                     p_party_id         => get_contact_upd_pop_r.person_party_id, -- i n
                                     p_phone_number     => NULL, -- i v
                                     p_fax_number       => NULL,
                                     p_url              => NULL,
                                     p_mobile_phone     => p_sf_mobile_phone,
                                     p_email            => NULL,
                                     p_entity           => 'UPDATE',
                                     p_contact_point_id => l_contact_point_id, -- o n
                                     p_err_code         => l_err_code, -- o v
                                     p_err_msg          => l_err_msg); -- o v
          END IF;
          IF l_change = 'Y' THEN
            IF l_err_code <> 0 THEN
              p_err_code     := 1;
              p_err_msg      := p_err_msg || ' - ' || l_err_msg;
              g_num_of_api_e := g_num_of_api_e + 1;
            ELSE
              g_num_of_api_s := g_num_of_api_s + 1;
              l_err_msg      := l_err_msg || ' Success create Mobile contact';
            END IF;
            update_interface_line_status(p_status          => 'OA_SUCCESS',
                                         p_oracle_id       => p_cust_account_role_id, -- i n
                                         p_sf_id           => p_sf_contact_id, -- i v
                                         p_oracle_event_id => p_oracle_event_id, -- i n
                                         p_entity          => 'UPDATE', -- i v
                                         p_msg             => 'Mobile - ' ||
                                                              l_err_msg, -- i v
                                         p_err_code        => l_err_code, -- o v
                                         p_err_msg         => l_err_msg); -- o v
          END IF; -- l_change
        END IF; -- mobile phone

        -- Handle Fax number Dalit A. Raviv 26/10/2010
        IF p_sf_fax IS NOT NULL THEN
          -- check contact exist in oracle and update if not create
          l_count    := 0;
          l_err_code := 0;
          l_err_msg  := NULL;
          l_change   := 'N';
          SELECT COUNT(1)
          INTO   l_count
          FROM   hz_contact_points hcp
          WHERE  hcp.owner_table_id = get_contact_upd_pop_r.contact_party_id
          AND    hcp.contact_point_type = 'PHONE'
          AND    hcp.phone_line_type = 'FAX'
          AND    hcp.created_by_module = 'SALESFORCE';

          IF l_count <> 0 THEN
            FOR get_contact_point_details_r IN get_contact_point_details_c(get_contact_upd_pop_r.contact_party_id,
                                                                           'PHONE',
                                                                           'FAX') LOOP
              IF p_sf_fax <> get_contact_point_details_r.phone_number THEN
                l_change := 'Y';
                update_contact_point_api(p_oracle_event_id  => p_oracle_event_id, -- i n
                                         p_party_id         => get_contact_upd_pop_r.contact_party_id, -- i n
                                         p_phone_number     => NULL, -- i v
                                         p_mobile_phone     => NULL, -- i v
                                         p_email            => NULL, -- i v
                                         p_fax              => p_sf_fax,
                                         p_ovn              => get_contact_point_details_r.object_version_number, -- i n
                                         p_contact_point_id => get_contact_point_details_r.contact_point_id, -- i n
                                         p_err_code         => l_err_code, -- o v
                                         p_err_msg          => l_err_msg); -- o v
              END IF;
            END LOOP;
            --- need to create new Mobile contact point
          ELSE
            l_change := 'Y';
            create_contact_point_api(p_oracle_event_id  => p_oracle_event_id, -- i n
                                     p_party_id         => get_contact_upd_pop_r.person_party_id, -- i n
                                     p_phone_number     => NULL, -- i v
                                     p_fax_number       => p_sf_fax,
                                     p_url              => NULL,
                                     p_mobile_phone     => NULL,
                                     p_email            => NULL,
                                     p_entity           => 'UPDATE',
                                     p_contact_point_id => l_contact_point_id, -- o n
                                     p_err_code         => l_err_code, -- o v
                                     p_err_msg          => l_err_msg); -- o v
          END IF;
          IF l_change = 'Y' THEN
            IF l_err_code <> 0 THEN
              p_err_code     := 1;
              p_err_msg      := p_err_msg || ' - ' || l_err_msg;
              g_num_of_api_e := g_num_of_api_e + 1;
            ELSE
              g_num_of_api_s := g_num_of_api_s + 1;
              l_err_msg      := l_err_msg || ' Success create Fax contact';
            END IF;
            update_interface_line_status(p_status          => 'OA_SUCCESS',
                                         p_oracle_id       => p_cust_account_role_id, -- i n
                                         p_sf_id           => p_sf_contact_id, -- i v
                                         p_oracle_event_id => p_oracle_event_id, -- i n
                                         p_entity          => 'UPDATE', -- i v
                                         p_msg             => 'Fax - ' ||
                                                              l_err_msg, -- i v
                                         p_err_code        => l_err_code, -- o v
                                         p_err_msg         => l_err_msg); -- o v
          END IF; -- l_change
        END IF; -- Fax
      */ -- yy
      -- Handle Email number
      IF p_sf_email IS NOT NULL THEN
        -- check contact exist in oracle and update if not create
        l_count    := 0;
        l_err_code := 0;
        l_err_msg  := NULL;
        l_change   := 'N';
        SELECT COUNT(1)
        INTO   l_count
        FROM   hz_contact_points hcp
        WHERE  hcp.owner_table_id = get_contact_upd_pop_r.contact_party_id
        AND    hcp.contact_point_type = 'EMAIL'
        AND    hcp.created_by_module = 'SALESFORCE';

        IF l_count <> 0 THEN
          FOR get_contact_point_details_r IN get_contact_point_details_c(get_contact_upd_pop_r.contact_party_id,
						 'EMAIL',
						 NULL) LOOP
	IF p_sf_email <> get_contact_point_details_r.email_address THEN
	  l_change := 'Y';
	  update_contact_point_api(p_oracle_event_id  => p_oracle_event_id, -- i n
			   p_party_id         => get_contact_upd_pop_r.contact_party_id, -- i n
			   p_phone_number     => NULL, -- i v
			   p_mobile_phone     => NULL, -- i v
			   p_email            => p_sf_email, -- i v
			   p_fax              => NULL, -- i v
			   p_ovn              => get_contact_point_details_r.object_version_number, -- i n
			   p_contact_point_id => get_contact_point_details_r.contact_point_id, -- i n
			   p_err_code         => l_err_code, -- o v
			   p_err_msg          => l_err_msg); -- o v
	END IF;
          END LOOP;
          --- need to create new Email contact point
        ELSE
          l_change := 'Y';
          create_contact_point_api(p_oracle_event_id  => p_oracle_event_id, -- i n
		           p_party_id         => get_contact_upd_pop_r.person_party_id, -- i n
		           p_phone_number     => NULL, -- i v
		           p_fax_number       => NULL,
		           p_url              => NULL,
		           p_mobile_phone     => NULL,
		           p_email            => p_sf_email,
		           p_entity           => 'UPDATE',
		           p_contact_point_id => l_contact_point_id, -- o n
		           p_err_code         => l_err_code, -- o v
		           p_err_msg          => l_err_msg); -- o v
        END IF;
        IF l_change = 'Y' THEN
          IF l_err_code <> 0 THEN
	p_err_code     := 1;
	p_err_msg      := p_err_msg || ' - ' || l_err_msg;
	g_num_of_api_e := g_num_of_api_e + 1;
          ELSE
	g_num_of_api_s := g_num_of_api_s + 1;
	l_err_msg      := l_err_msg || ' Success create Email contact';
          END IF;
          update_interface_line_status(p_status          => 'OA_SUCCESS',
			   p_oracle_id       => p_cust_account_role_id, -- i n
			   p_sf_id           => p_sf_contact_id, -- i v
			   p_oracle_event_id => p_oracle_event_id, -- i n
			   p_entity          => 'UPDATE', -- i v
			   p_msg             => 'Emaile - ' ||
					l_err_msg, -- i v
			   p_err_code        => l_err_code, -- o v
			   p_err_msg         => l_err_msg); -- o v
        END IF; -- l_change
      END IF; -- Email

    END LOOP; -- get_contact_upd_pop_c
    IF g_num_of_api_e = 0 AND g_num_of_api_s = 0 THEN
      update_interface_line_status(p_status          => 'OA_SUCCESS',
		           p_oracle_id       => p_cust_account_role_id, -- i n
		           p_sf_id           => p_sf_contact_id, -- i v
		           p_oracle_event_id => p_oracle_event_id, -- i n
		           p_entity          => 'UPDATE', -- i v
		           p_msg             => 'No data to Update', -- i v
		           p_err_code        => l_err_code, -- o v
		           p_err_msg         => l_err_msg); -- o v
    ELSIF g_num_of_api_e = 0 AND g_num_of_api_s <> 0 THEN
      update_interface_line_status(p_status          => 'OA_SUCCESS',
		           p_oracle_id       => p_cust_account_role_id, -- i n
		           p_sf_id           => p_sf_contact_id, -- i v
		           p_oracle_event_id => p_oracle_event_id, -- i n
		           p_entity          => 'INSERT', -- i v
		           p_msg             => NULL, -- i v
		           p_err_code        => l_err_code, -- o v
		           p_err_msg         => l_err_msg); -- o v
    END IF;
  END update_new_contact;

  --------------------------------------------------------------------
  --  name:            create_new_contact
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that Handle create CONTACTS
  --                   1) create_person_api
  --                   2) create_location_api
  --                   3) create_org_contact_api
  --                   4) create_party_site_api
  --                   5) create_cust_account_role_api
  --                   6) update_interface_line_status - if success untill this point
  --                   7) create_contact_point_api
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/09/2010  Dalit A. Raviv    initial build
  --  1.1  26/10/2010  Dalit A. Raviv    add sf_fax number option
  --  1.2  28/10/2010  Dalit A. Raviv    add person prefix (sf_salutation)
  --  1.3  15/04/2012  Dalit A. Raviv    There is a problem that new job_title at SF did not enter
  --                                     to lookup 'RESPONSIBILITY'. this cause that person do create at
  --                                     oracle but because of the job title error SF do not update with oracle_id
  --                                     and therefor continue sending (and creating) each hour the same data
  --                                     to update oracle. the solution is to mark the row as OA_WARNING
  --                                     and oracle_id istead of OA_ERR.
  --                                     1) add global variable g_job_title
  --                                     2) init and call this global from procedure create_org_contact_api
  --                                     3) refer to this global at procedure create_new_contact.
  --  1.4  31/10/2012  Dalit A. Raviv    add handle of rollback
  --------------------------------------------------------------------
  PROCEDURE create_new_contact(p_sf_account_id    IN VARCHAR2, --get_xml_pop_r.sf_account_id
		       p_oracle_event_id  IN NUMBER, --get_account_pop_r.oracle_event_id
		       p_sf_first_name    IN VARCHAR2, --get_xml_pop_r.sf_firstname
		       p_sf_last_name     IN VARCHAR2, --get_xml_pop_r.sf_lastname
		       p_sf_country       IN VARCHAR2, --get_xml_pop_r.sf_country
		       p_sf_address_line1 IN VARCHAR2, --get_xml_pop_r.sf_address_1
		       p_sf_city          IN VARCHAR2, --get_xml_pop_r.sf_city
		       p_sf_postal_code   IN VARCHAR2, --get_xml_pop_r.sf_zipcode_postal_code
		       p_sf_state         IN VARCHAR2, --get_xml_pop_r.sf_state_region
		       p_sf_county        IN VARCHAR2, --get_xml_pop_r.sf_county
		       p_sf_title         IN VARCHAR2, --get_xml_pop_r.sf_title
		       p_sf_contact_id    IN VARCHAR2, --get_xml_pop_r.sf_contact_id
		       p_sf_phone_number  IN VARCHAR2, --get_xml_pop_r.sf_phone
		       p_sf_mobile_phone  IN VARCHAR2, --get_xml_pop_r.sf_mobilephone
		       p_sf_email         IN VARCHAR2, --get_xml_pop_r.sf_email
		       p_sf_fax           IN VARCHAR2, --get_xml_pop_r.sf_fax
		       p_sf_salutation    IN VARCHAR2, -- iv
		       p_err_code         OUT VARCHAR2,
		       p_err_msg          OUT VARCHAR2) IS

    l_person_party_id      NUMBER := NULL;
    l_err_code             VARCHAR2(5) := 0;
    l_err_msg              VARCHAR2(2500) := NULL;
    l_err_code1            VARCHAR2(5) := 0;
    l_err_msg1             VARCHAR2(2500) := NULL;
    l_org_id               NUMBER := NULL;
    l_party_id             NUMBER := NULL;
    l_cust_account_id      NUMBER := NULL;
    l_contact_party_id     NUMBER := NULL;
    l_party_number         VARCHAR2(150) := NULL;
    l_location_id          NUMBER := NULL;
    l_cust_account_role_id NUMBER := NULL;
    l_contact_point_id     NUMBER := NULL;
    l_party_site_id        NUMBER := NULL;

    general_exception EXCEPTION;

  BEGIN
    p_err_code := 0;
    p_err_msg  := NULL;

    l_err_code        := 0;
    l_err_msg         := NULL;
    l_org_id          := NULL;
    l_party_id        := NULL;
    l_cust_account_id := NULL;
    -- Get cust_account , party and org id
    BEGIN
      SELECT hp.attribute3,
	 hp.party_id,
	 hca.cust_account_id
      INTO   l_org_id,
	 l_party_id,
	 l_cust_account_id
      FROM   hz_cust_accounts hca,
	 hz_parties       hp
      WHERE  hca.party_id = hp.party_id
      AND    hca.attribute4 = p_sf_account_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_org_id := NULL;
    END;

    IF l_org_id IS NOT NULL THEN
      --IF nvl(g_org_id, 1) <> l_org_id THEN
      --  g_org_id := l_org_id;

      mo_global.set_org_access(p_org_id_char     => l_org_id,
		       p_sp_id_char      => NULL,
		       p_appl_short_name => 'AR');
      --END IF;
      -- Create person (party of type person)
      l_err_code        := 0;
      l_err_msg         := NULL;
      l_person_party_id := NULL;
      create_person_api(p_oracle_event_id => p_oracle_event_id, -- i n
		p_first_name      => p_sf_first_name, -- i v get_xml_pop_r.sf_firstname,
		p_last_name       => p_sf_last_name, -- i v get_xml_pop_r.sf_lastname,
		p_sf_salutation   => p_sf_salutation, -- i v
		p_person_party_id => l_person_party_id, -- o n
		p_err_code        => l_err_code, -- o v
		p_err_msg         => l_err_msg); -- o v
      IF l_err_code = 1 THEN
        p_err_code := 1;
        p_err_msg  := l_err_msg;
        RAISE general_exception;
      ELSE
        dbms_output.put_line('Create Person - person party id - ' ||
		     l_person_party_id);
      END IF;
      l_err_code    := 0;
      l_err_msg     := NULL;
      l_location_id := NULL;
      -- If success to create person
      -- Create location for the person
      IF p_sf_address_line1 IS NOT NULL AND p_sf_country IS NOT NULL THEN

        create_location_api(p_country         => p_sf_country, -- i v get_xml_pop_r.sf_country
		    p_address_line1   => p_sf_address_line1, -- i v get_xml_pop_r.sf_address_1
		    p_city            => p_sf_city, -- i v get_xml_pop_r.sf_city
		    p_postal_code     => p_sf_postal_code, -- i v get_xml_pop_r.sf_zipcode_postal_code
		    p_state           => p_sf_state, -- i v get_xml_pop_r.sf_state_region
		    p_county          => p_sf_county, -- i v get_xml_pop_r.sf_county
		    p_oracle_event_id => p_oracle_event_id, -- i n
		    p_location_id     => l_location_id, -- o n
		    p_err_code        => l_err_code, -- o v
		    p_err_msg         => l_err_msg); -- o v
        IF l_err_code = 1 THEN
          p_err_code := 1;
          p_err_msg  := l_err_msg;
          RAISE general_exception;
        ELSE
          dbms_output.put_line('Create location - Location id - ' ||
		       l_location_id);
        END IF;
      END IF;
      l_err_code         := 0;
      l_err_msg          := NULL;
      l_contact_party_id := NULL;
      l_party_number     := NULL;
      -- create org_contact conect the person to party
      create_org_contact_api(p_subject_id       => l_person_party_id, -- i n (party id that just created)
		     p_subject_type     => 'PERSON', -- i v
		     p_object_id        => l_party_id, -- i n (account party id)
		     p_object_type      => 'ORGANIZATION', -- i v
		     p_relation_code    => 'CONTACT_OF', -- i v
		     p_relation_type    => 'CONTACT', -- i v
		     p_object_tble_name => 'HZ_PARTIES', -- i v
		     p_title            => p_sf_title, -- i v get_xml_pop_r.sf_title
		     p_oracle_event_id  => p_oracle_event_id, -- i n
		     p_contact_party    => l_contact_party_id, -- o n
		     p_party_number     => l_party_number, -- o n
		     p_err_code         => l_err_code, -- o v
		     p_err_msg          => l_err_msg); -- o v

      IF l_err_code = 1 THEN
        p_err_code := 1;
        p_err_msg  := l_err_msg;
        RAISE general_exception;
      ELSE
        dbms_output.put_line('Create org contact - Contact party id - ' ||
		     l_contact_party_id);
      END IF;
      l_err_code      := 0;
      l_err_msg       := NULL;
      l_party_site_id := NULL;
      IF p_sf_address_line1 IS NOT NULL AND p_sf_country IS NOT NULL THEN
        create_party_site_api(p_location_id     => l_location_id, -- i n
		      p_cust_account_id => l_cust_account_id, -- i n get_xml_pop_r.sf_account_id
		      p_oracle_event_id => p_oracle_event_id, -- i n get_xml_pop_r.oracle_event_id
		      --p_country         => p_sf_country,     -- i v get_xml_pop_r.sf_country
		      p_party_id      => l_contact_party_id, -- i v
		      p_party_site_id => l_party_site_id, -- o n
		      p_err_code      => l_err_code, -- o v
		      p_err_msg       => l_err_msg); -- o v

        IF l_err_code = 1 THEN
          p_err_code := 1;
          p_err_msg  := l_err_msg;
          RAISE general_exception;
        ELSE
          dbms_output.put_line('Create party site - party site id - ' ||
		       l_party_site_id);
        END IF;
      END IF;
      l_err_code             := 0;
      l_err_msg              := NULL;
      l_cust_account_role_id := NULL;
      -- create cust_account role
      create_cust_account_role_api(p_contact_party        => l_contact_party_id, -- i n
		           p_cust_account_id      => l_cust_account_id, -- i n
		           p_oracle_event_id      => p_oracle_event_id, -- i n
		           p_sf_id                => p_sf_contact_id, -- i v get_xml_pop_r.sf_contact_id
		           p_cust_account_role_id => l_cust_account_role_id, -- o n
		           p_err_code             => l_err_code, -- o v
		           p_err_msg              => l_err_msg); -- o v
      IF l_err_code = 1 THEN
        p_err_code := 1;
        p_err_msg  := l_err_msg;
        --rollback;  ------------------------------------------------------
        RAISE general_exception;
      ELSE
        dbms_output.put_line('Create cust account role - Cust account role id - ' ||
		     l_cust_account_role_id);
        COMMIT; -- commit for all API's
        -- 1.3  15/04/2012  Dalit A. Raviv
        -- if there is a problem with sf_job_title (customer did not enter value
        -- to lookup RESPONSIBILITY) we do want to proceed with the flow of creation
        -- but steel give warning about it to customer.
        -- i need to use global variable because the stage the error create i do not have
        -- cust_account_role_id. this value is important for SF update, and stoping Sf sending
        -- this contact.
        IF g_job_title = 'Y' THEN
          l_err_msg1 := 'create_org_contact_api - Invalid Title :' ||
		p_sf_title;
          update_interface_line_status(p_status          => 'OA_WARNING',
			   p_oracle_id       => l_cust_account_role_id,
			   p_sf_id           => p_sf_contact_id, --get_xml_pop_r.sf_contact_id
			   p_oracle_event_id => p_oracle_event_id,
			   p_err_code        => l_err_code, -----------------
			   p_err_msg         => l_err_msg1);

        ELSE
          update_interface_line_status(p_status          => 'OA_SUCCESS',
			   p_oracle_id       => l_cust_account_role_id,
			   p_sf_id           => p_sf_contact_id, --get_xml_pop_r.sf_contact_id
			   p_oracle_event_id => p_oracle_event_id,
			   p_err_code        => l_err_code1,
			   p_err_msg         => l_err_msg1);
        END IF;
        ----------------------------------------
        /* IF l_err_code1 = 0 THEN
          l_err_code         := 0;
          l_err_msg          := NULL;
          l_contact_point_id := NULL;

          IF p_sf_phone_number IS NOT NULL OR p_sf_mobile_phone IS NOT NULL OR
             p_sf_email IS NOT NULL THEN

            create_contact_point_api(p_oracle_event_id  => p_oracle_event_id, -- i n
                                     p_party_id         => l_contact_party_id,-- i n
                                     p_phone_number     => p_sf_phone_number, -- i v get_xml_pop_r.sf_phone
                                     p_fax_number       => p_sf_fax,          -- i v
                                     p_url              => NULL,              -- i v
                                     p_mobile_phone     => p_sf_mobile_phone, -- i v get_xml_pop_r.sf_mobilephone
                                     p_email            => p_sf_email,        -- i v get_xml_pop_r.sf_email
                                     p_contact_point_id => l_contact_point_id,-- o n
                                     p_err_code         => l_err_code, -- o v
                                     p_err_msg          => l_err_msg); -- o v
          END IF;
        END IF;*/
        -----
      END IF;

      IF l_err_code1 = 0 THEN
        l_err_code         := 0;
        l_err_msg          := NULL;
        l_contact_point_id := NULL;

        IF p_sf_phone_number IS NOT NULL OR p_sf_mobile_phone IS NOT NULL OR
           p_sf_email IS NOT NULL THEN

          create_contact_point_api(p_oracle_event_id  => p_oracle_event_id, -- i n
		           p_party_id         => l_contact_party_id, -- i n
		           p_phone_number     => p_sf_phone_number, -- i v get_xml_pop_r.sf_phone
		           p_fax_number       => p_sf_fax, -- i v
		           p_url              => NULL, -- i v
		           p_mobile_phone     => p_sf_mobile_phone, -- i v get_xml_pop_r.sf_mobilephone
		           p_email            => p_sf_email, -- i v get_xml_pop_r.sf_email
		           p_contact_point_id => l_contact_point_id, -- o n
		           p_err_code         => l_err_code, -- o v
		           p_err_msg          => l_err_msg); -- o v
        END IF;
      END IF;
    ELSE
      -- update interface line with error
      l_err_msg := 'Handle_contacts_in_oracle - ' ||
	       'Can not find Org_id, cust_account_id and party_id for sf_id - ' ||
	       p_sf_account_id; /*get_xml_pop_r.sf_account_id*/

      update_interface_line_error(p_status          => 'OA_ERR', -- i n
		          p_oracle_event_id => p_oracle_event_id, -- i n
		          p_err_msg         => l_err_msg, -- i/o/v
		          p_err_code        => l_err_code); -- o v

    END IF; -- l_org_id
  EXCEPTION
    WHEN general_exception THEN
      ROLLBACK; -- 31/10/2012 Dalit A. Raviv
      NULL;
  END create_new_contact;

  --------------------------------------------------------------------
  --  name:            handle_contacts_in_oracle
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   21/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that Handle only CONTACTS DATA will get batch id
  --                   1) get population to work on
  --                   2) parse xml data
  --                   3) call API to create Contacts
  --                   4) update interface line table with errors / sf_id / oracle_id etc'
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  21/09/2010  Dalit A. Raviv    initial build
  --  1.1  26/10/2010  Dalit A. Raviv    add fax number option
  --  1.2  28/10/2010  Dalit A. Raviv    add person prefix (sf_salutation)
  --  1.3  11/11/2010  Dalit A. Raviv    enter parse select to the main select
  --  1.4  17/10/2012  Dalit A. Raviv    add check if SF_ID allready exists in oracle.
  -- 1.5   22.6.2016  yuval tal         CHG0038819 use exists oracle id in case found and update success instead of err

  --------------------------------------------------------------------
  PROCEDURE handle_contacts_in_oracle(p_batch_id IN NUMBER,
			  p_err_code OUT VARCHAR2,
			  p_err_msg  OUT VARCHAR2) IS

    -- get contacts rows to parse and handle in oracle
    -- by batch_id , status and source.
    CURSOR get_account_pop_c(p_batch_id IN NUMBER) IS
      SELECT h.source_name,
	 l.*,
	 extractvalue(l.rec_xml, '/result/FirstName') sf_firstname, --
	 extractvalue(l.rec_xml, '/result/LastName') sf_lastname, --
	 extractvalue(l.rec_xml, '/result/Title') sf_title_old, --
	 extractvalue(l.rec_xml, '/result/Title__c') sf_title, --
	 extractvalue(l.rec_xml, '/result/Phone') sf_phone,
	 extractvalue(l.rec_xml, '/result/MobilePhone') sf_mobilephone,
	 extractvalue(l.rec_xml, '/result/Email') sf_email,
	 extractvalue(l.rec_xml, '/result/Id') sf_contact_id, --
	 extractvalue(l.rec_xml, '/result/OE_ID__c') oa_account_role_id,
	 extractvalue(l.rec_xml, '/result/Oracle_Contact_ID__c') oa_oracle_contact_id,
	 extractvalue(l.rec_xml, '/result/Oracle_Event_ID__c') sf_oracle_event_id, --
	 extractvalue(l.rec_xml, '/result/AccountId') sf_account_id, --
	 extractvalue(l.rec_xml, '/result/Address_1__c') sf_address_1, --
	 extractvalue(l.rec_xml, '/result/City__c') sf_city, --
	 extractvalue(l.rec_xml, '/result/Country__c') sf_country, --
	 extractvalue(l.rec_xml, '/result/County__c') sf_county, --
	 extractvalue(l.rec_xml, '/result/Sales_Territory__c') sf_sales_territory,
	 extractvalue(l.rec_xml, '/result/State_Region__c') sf_state_region, --
	 extractvalue(l.rec_xml, '/result/Zipcode_Postal_Code__c') sf_zipcode_postal_code, --
	 extractvalue(l.rec_xml, '/result/Fax') sf_fax,
	 extractvalue(l.rec_xml, '/result/Salutation') sf_salutation
      FROM   xxobjt_sf2oa_interface_l l,
	 xxobjt_sf2oa_interface_h h
      WHERE  h.oracle_batch_id = l.oracle_batch_id
      AND    l.oracle_batch_id = p_batch_id
	--AND    l.oracle_event_id = 56723552
      AND    l.status = 'NEW';

    /*    -- Parse recxml field to get all needed data per row
        CURSOR get_xml_pop_c(p_result IN xmltype) IS
          SELECT extractvalue(VALUE(xml), '/result/FirstName') sf_firstname, --
                 extractvalue(VALUE(xml), '/result/LastName') sf_lastname, --
                 extractvalue(VALUE(xml), '/result/Title') sf_title_old, --
                 extractvalue(VALUE(xml), '/result/Title__c') sf_title, --
                 extractvalue(VALUE(xml), '/result/Phone') sf_phone,
                 extractvalue(VALUE(xml), '/result/MobilePhone') sf_mobilephone,
                 extractvalue(VALUE(xml), '/result/Email') sf_email,
                 extractvalue(VALUE(xml), '/result/Id') sf_contact_id, --
                 extractvalue(VALUE(xml), '/result/OE_ID__c') oa_account_role_id,
                 extractvalue(VALUE(xml), '/result/Oracle_Contact_ID__c') oa_oracle_contact_id,
                 extractvalue(VALUE(xml), '/result/Oracle_Event_ID__c') oracle_event_id, --
                 extractvalue(VALUE(xml), '/result/AccountId') sf_account_id, --
                 extractvalue(VALUE(xml), '/result/Address_1__c') sf_address_1, --
                 extractvalue(VALUE(xml), '/result/City__c') sf_city, --
                 extractvalue(VALUE(xml), '/result/Country__c') sf_country, --
                 extractvalue(VALUE(xml), '/result/County__c') sf_county, --
                 extractvalue(VALUE(xml), '/result/Sales_Territory__c') sf_sales_territory,
                 extractvalue(VALUE(xml), '/result/State_Region__c') sf_state_region, --
                 extractvalue(VALUE(xml), '/result/Zipcode_Postal_Code__c') sf_zipcode_postal_code, --
                 extractvalue(VALUE(xml), '/result/Fax') sf_Fax,
                 extractvalue(VALUE(xml), '/result/Salutation') sf_Salutation
            FROM TABLE(xmlsequence(extract(p_result, '/result'))) xml;
    */
    l_err_code VARCHAR2(5) := 0;
    l_err_msg  VARCHAR2(2500) := NULL;
    l_count    NUMBER := 0;
    l_exist    VARCHAR2(10) := 'N';
    --general_exception EXCEPTION;
  BEGIN
    -- set g_user_id SALESFORCE User
    set_salesforce_user;

    fnd_global.apps_initialize(user_id      => g_user_id, -- SALESFORCE
		       resp_id      => 51137, -- CRM Service Super User Objet
		       resp_appl_id => 514); -- Support (obsolete)
    p_err_code := 0;
    p_err_msg  := NULL;
    FOR get_account_pop_r IN get_account_pop_c(p_batch_id) LOOP
      --FOR get_xml_pop_r IN get_xml_pop_c(get_account_pop_r.rec_xml) LOOP

      update_sf_id(p_sf_id           => get_account_pop_r.sf_contact_id, -- i v
	       p_oracle_event_id => get_account_pop_r.oracle_event_id, -- i n
	       p_err_msg         => l_err_msg, -- o v
	       p_err_code        => l_err_code); -- o v

      update_sf_exist(p_sf_id           => get_account_pop_r.sf_contact_id, -- i v
	          p_oracle_event_id => get_account_pop_r.oracle_event_id, -- i n
	          p_err_msg         => l_err_msg, -- o v
	          p_err_code        => l_err_code); -- o v

      SELECT COUNT(1)
      INTO   l_count
      FROM   xxobjt_sf2oa_interface_l l
      WHERE  l.oracle_event_id = get_account_pop_r.oracle_event_id
      AND    l.status = 'OA_HOLD';

      IF l_count = 0 THEN
        IF get_account_pop_r.oa_account_role_id IS NULL THEN
          -- 17/10/2012 Dalit A. Raviv
          -- 0) Check if this SF_iD exist allready in oracle
          l_exist := get_sf_id_exist(p_source_name => 'CONTACT',
			 p_sf_id       => get_account_pop_r.sf_contact_id);
          IF l_exist IS NOT NULL THEN
	l_err_code := 0;
	l_err_msg  := 'SD_ID allready Exist in Oracle Contact - hz_cust_account_roles, attribute1 = ' ||
		  get_account_pop_r.sf_contact_id;

	update_interface_line_status(p_status          => 'OA_SUCCESS',
			     p_oracle_id       => l_exist,
			     p_sf_id           => get_account_pop_r.sf_contact_id,
			     p_oracle_event_id => get_account_pop_r.oracle_event_id,
			     p_err_code        => l_err_code,
			     p_err_msg         => l_err_msg);
	l_err_code := 0;
	--p_err_msg  := l_err_msg;
	--RAISE general_exception;
          ELSE
	l_err_code := 0;
	l_err_msg  := NULL;
	create_new_contact(p_sf_account_id    => get_account_pop_r.sf_account_id, -- i v
		       p_oracle_event_id  => get_account_pop_r.oracle_event_id, -- i n
		       p_sf_first_name    => get_account_pop_r.sf_firstname, -- i v
		       p_sf_last_name     => get_account_pop_r.sf_lastname, -- i v
		       p_sf_country       => get_account_pop_r.sf_country, -- i v
		       p_sf_address_line1 => get_account_pop_r.sf_address_1, -- i v
		       p_sf_city          => get_account_pop_r.sf_city, -- i v
		       p_sf_postal_code   => get_account_pop_r.sf_zipcode_postal_code, -- i v
		       p_sf_state         => get_account_pop_r.sf_state_region, -- i v
		       p_sf_county        => get_account_pop_r.sf_county, -- i v
		       p_sf_title         => get_account_pop_r.sf_title, -- i v
		       p_sf_contact_id    => get_account_pop_r.sf_contact_id, -- i v
		       p_sf_phone_number  => get_account_pop_r.sf_phone, -- i v
		       p_sf_mobile_phone  => get_account_pop_r.sf_mobilephone, -- i v
		       p_sf_email         => get_account_pop_r.sf_email, -- i v
		       p_sf_fax           => get_account_pop_r.sf_fax, -- i v
		       p_sf_salutation    => get_account_pop_r.sf_salutation, -- iv
		       p_err_code         => l_err_code, -- o v
		       p_err_msg          => l_err_msg); -- o v
          END IF; -- l_exist
        ELSE

          dbms_output.put_line('update contact  :');
          l_err_code := 0;
          l_err_msg  := NULL;
          update_new_contact(p_cust_account_role_id => get_account_pop_r.oa_account_role_id, -- i n
		     p_oracle_event_id      => get_account_pop_r.oracle_event_id, -- i n
		     p_sf_first_name        => get_account_pop_r.sf_firstname, -- i v
		     p_sf_last_name         => get_account_pop_r.sf_lastname, -- i v
		     p_sf_country           => get_account_pop_r.sf_country, -- i v
		     p_sf_address_line1     => get_account_pop_r.sf_address_1, -- i v
		     p_sf_city              => get_account_pop_r.sf_city, -- i v
		     p_sf_postal_code       => get_account_pop_r.sf_zipcode_postal_code, -- i v
		     p_sf_state             => get_account_pop_r.sf_state_region, -- i v
		     p_sf_county            => get_account_pop_r.sf_county, -- i v
		     p_sf_title             => get_account_pop_r.sf_title, -- i v
		     p_sf_phone_number      => get_account_pop_r.sf_phone, -- i v
		     p_sf_mobile_phone      => get_account_pop_r.sf_mobilephone, -- i v
		     p_sf_email             => get_account_pop_r.sf_email, -- i v
		     p_sf_fax               => get_account_pop_r.sf_fax, -- i v
		     p_sf_salutation        => get_account_pop_r.sf_salutation, -- iv
		     p_sf_contact_id        => get_account_pop_r.sf_contact_id, -- i v
		     p_sf_account_id        => get_account_pop_r.sf_account_id, -- i v
		     p_err_code             => l_err_code, -- o v
		     p_err_msg              => l_err_msg); -- o v

        END IF; -- ins or update
        IF l_err_code = 1 THEN
          p_err_code := l_err_code;
          p_err_msg  := l_err_msg;
        END IF;
      END IF; -- l_count
    --END LOOP;

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - Handle_contacts_in_oracle - p_batch_id - ' ||
	        p_batch_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - Handle_contacts_in_oracle - ' ||
		   substr(SQLERRM, 1, 240));

  END handle_contacts_in_oracle;

  --------------------------------------------------------------------
  --  name:            Handle_entities_in_oracle
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that will go by source_name and batch id
  --                   and will exctrat the xml, get sf_id, and data to handle
  --                   at oracle. account / site will insert to oracle, contact
  --                   will insert or update (check if oracle_id is null or not).
  --                   * This Procedure is an envelope to each entity handling.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_entities_in_oracle(p_batch_id    IN NUMBER,
			  p_source_name IN VARCHAR2,
			  p_err_code    OUT VARCHAR2,
			  p_err_msg     OUT VARCHAR2) IS

    l_err_code VARCHAR2(50) := 0;
    l_err_msg  VARCHAR2(2500) := NULL;
  BEGIN

    IF p_source_name = 'ACCOUNT' THEN
      handle_accounts_in_oracle(p_batch_id => p_batch_id, -- i n
		        p_err_code => l_err_code, -- o v
		        p_err_msg  => l_err_msg); -- o v

    ELSIF p_source_name = 'SITE' THEN
      handle_sites_in_oracle(p_batch_id => p_batch_id, -- i n
		     p_err_code => l_err_code, -- o v
		     p_err_msg  => l_err_msg); -- o v

    ELSIF p_source_name = 'CONTACT' THEN
      handle_contacts_in_oracle(p_batch_id => p_batch_id, -- i n
		        p_err_code => l_err_code, -- o v
		        p_err_msg  => l_err_msg); -- o v
    END IF;
    p_err_code := l_err_code;
    p_err_msg  := l_err_msg;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - Handle_entities_in_oracle - p_batch_id - ' ||
	        p_batch_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - Handle_entities_in_oracle - ' ||
		   substr(SQLERRM, 1, 240));
  END handle_entities_in_oracle;

  --------------------------------------------------------------------
  --  name:            update_SF_Data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that will be call from BPEL process
  --                   and update for batch the instance id, and respond xml
  --                   from Bpel. (all the data we need to process)
  --                   1) update Header interface with the respond xml data
  --                   2) insert rows to line interface (parse the respond from header to each line)
  --                   3) Start to process entities at Oracle. - parse the xml from the line and
  --                      activate the needed API, + update interface line table with status,
  --                      sf_id (from xml) , oracle_id and process mode (INSERT/UPDATE)
  --                      this is needed for the Bpel to send back to SF if suceess to
  --                      upd/ins in oracle.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_sf_data(p_batch_id    IN NUMBER,
		   p_bpel_id     IN NUMBER,
		   p_respond     IN xmltype,
		   p_source_name IN VARCHAR2,
		   p_err_code    OUT VARCHAR2,
		   p_err_msg     OUT VARCHAR2) IS

    l_err_code    VARCHAR2(10) := NULL;
    l_err_msg     VARCHAR2(2500) := NULL;
    l_source_name VARCHAR2(250) := NULL;
    l_respond     xmltype;
  BEGIN

    l_respond := remove_xmlns(p_respond);
    -- 1) update Header interface with the respond xml data
    update_sf_header_xml_data(p_batch_id    => p_batch_id, -- i n
		      p_bpel_id     => p_bpel_id, -- i n
		      p_respond     => l_respond, -- i XMLTYPE,
		      p_source_name => p_source_name, -- i v
		      p_err_code    => l_err_code, -- o v
		      p_err_msg     => l_err_msg); -- o v

    IF l_err_code = 1 THEN
      p_err_code := l_err_code;
      p_err_msg  := l_err_msg;
    ELSE
      l_err_code := 0;
      l_err_msg  := NULL;
      -- 2) insert rows to line interface
      insert_sf_line_xml_data(p_batch_id    => p_batch_id, -- i n
		      p_source_name => l_source_name, -- OUT VARCHAR2,
		      p_err_code    => l_err_code, -- o v
		      p_err_msg     => l_err_msg); -- o v
      IF l_err_code = 1 THEN
        p_err_code := l_err_code;
        p_err_msg  := l_err_msg;
      ELSE
        l_err_code := 0;
        l_err_msg  := NULL;
        -- 3) Start to process entities at Oracle.
        handle_entities_in_oracle(p_batch_id    => p_batch_id, -- i n
		          p_source_name => l_source_name, -- i v
		          p_err_code    => l_err_code, -- o v
		          p_err_msg     => l_err_msg); -- o v
        p_err_code := l_err_code;
        p_err_msg  := l_err_msg;
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_SF_Data - p_batch_id -' || p_batch_id ||
	        ' - ' || 'p_bpel_id=' || p_bpel_id || ' - ' ||
	        substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - update_SF_Data - ' ||
		   substr(SQLERRM, 1, 240));
  END update_sf_data;

  --------------------------------------------------------------------
  --  name:            update_SF_callback_results header and lines
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        update SF callback response
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/09/2010  YUVAL TAL    initial build
  --------------------------------------------------------------------
  PROCEDURE update_sf_callback_results(p_batch_id    IN NUMBER,
			   p_respond     IN xmltype,
			   p_source_name IN VARCHAR2,
			   p_err_code    OUT VARCHAR2,
			   p_err_msg     OUT VARCHAR2) IS

    l_respond xmltype;
    CURSOR c_callback_rsponse IS
      SELECT extractvalue(VALUE(xml), 'REC_SET/SF_ID') sf_id,
	 extractvalue(VALUE(xml), 'REC_SET/ERR_CODE') err_code,
	 extractvalue(VALUE(xml), 'REC_SET/ORACLE_EVENT_ID') oracle_event_id,
	 extractvalue(VALUE(xml), 'REC_SET/ORACLE_ID') oracle_id,
	 extractvalue(VALUE(xml), 'REC_SET/ERR_MSG') err_msg
      FROM   TABLE(xmlsequence(extract(l_respond,
			   '/RESPONSE/SF_RESULTS/REC_SET'))) xml;

    /*
    <RESPONSE><SF_RESULTS><REC_SET><SF_ID>001Q000000EdbizIAB</SF_ID>
    <ORACLE_ID>365078</ORACLE_ID><ERR_CODE>0</ERR_CODE></REC_SET><REC_SET><SF_ID>001Q000000EPpkGIAT</SF_ID>
    <ORACLE_ID>365076</ORACLE_ID><ERR_CODE>0</ERR_CODE></REC_SET></SF_RESULTS></RESPONSE>*/
  BEGIN

    -- first update header tbl
    l_respond := remove_xmlns(p_respond);

    UPDATE xxobjt_sf2oa_interface_h xsaih
    SET    xsaih.sf_callback_response = l_respond
    WHERE  xsaih.oracle_batch_id = p_batch_id;

    COMMIT;

    FOR i IN c_callback_rsponse LOOP

      UPDATE xxobjt_sf2oa_interface_l l
      SET    l.sf_err_code = i.err_code,
	 l.sf_err_msg  = i.err_msg,
	 l.status      = decode(i.err_code, 1, 'SF_ERR', l.status)
      WHERE  l.oracle_event_id = i.oracle_event_id;
      COMMIT;
    END LOOP;

    --

    --
    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - update_sf_callback_results - p_batch_id - ' ||
	        p_batch_id || ' , source - ' || p_source_name || ' - ' ||
	        substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - update_sf_callback_results ' ||
		   substr(SQLERRM, 1, 240));
  END update_sf_callback_results;

  --------------------------------------------------------------------
  --  name:            upd_system_err
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that will update header interface tbl
  --                   if there are BPEL system errors
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_system_err(p_batch_id IN NUMBER,
		   p_err_code IN OUT VARCHAR2,
		   p_err_msg  IN OUT VARCHAR2) IS

    PRAGMA AUTONOMOUS_TRANSACTION;

  BEGIN
    UPDATE xxobjt_sf2oa_interface_h xsoi
    SET    xsoi.oa_err_code      = p_err_code,
           xsoi.oa_err_msg       = p_err_msg,
           xsoi.last_update_date = SYSDATE,
           xsoi.last_updated_by  = g_user_id,
           xsoi.creation_date    = SYSDATE,
           xsoi.created_by       = g_user_id
    WHERE  xsoi.oracle_batch_id = p_batch_id;
    COMMIT;

    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 1;
      p_err_msg  := 'Gen EXC - upd_system_err - p_batch_id - ' ||
	        p_batch_id || ' - ' || substr(SQLERRM, 1, 240);
      dbms_output.put_line('Gen EXC - upd_system_err - ' ||
		   substr(SQLERRM, 1, 240));
  END upd_system_err;

  --------------------------------------------------------------------
  --  name:            Call_Bpel_Process
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Call Bpel Process xxSF2OA_interfaces
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  --  1.1  21.9.14     yuval tal         CHG0031514 - modify call to bpel 11g
  -- 2.1 04/05/2016   yuval tal         CHG0037918 migration to 12c support redirect between 2 servers
  --                                    accorrding to profile XXOBJT_SF2OA_SOA_SRV_NUM
  --
  --------------------------------------------------------------------
  PROCEDURE call_bpel_process(p_source_name IN VARCHAR2,
		      p_batch_id    IN NUMBER,
		      p_status      OUT VARCHAR2,
		      p_message     OUT VARCHAR2,
		      p_respond     OUT sys.xmltype) IS

    service_            sys.utl_dbws.service;
    call_               sys.utl_dbws.call;
    service_qname       sys.utl_dbws.qname;
    response            sys.xmltype;
    request             sys.xmltype;
    l_string_type_qname sys.utl_dbws.qname;
    v_error             VARCHAR2(1000);
    l_err_code          VARCHAR2(100) := NULL;
    l_err_msg           VARCHAR2(2500) := NULL;
    l_env               VARCHAR2(20) := NULL;
    l_user              VARCHAR2(150) := NULL;
    l_password          VARCHAR2(150) := NULL;
    l_jndi_name         VARCHAR2(150) := NULL;
    l_endpoint_service  VARCHAR2(150) := NULL;
    l_endpoint_login    VARCHAR2(150) := NULL;
  BEGIN
    p_status := 'S';
    xxobjt_bpel_utils_pkg.get_sf_login_params(p_user_name        => l_user, -- o v
			          p_password         => l_password, -- o v
			          p_env              => l_env, -- o v
			          p_jndi_name        => l_jndi_name, -- o v
			          p_endpoint_service => l_endpoint_service, -- o v
			          p_endpoint_login   => l_endpoint_login, -- o v
			          p_err_code         => l_err_code, -- o v
			          p_err_msg          => l_err_msg); -- o v
    /*xxobjt_oa2sf_interface_pkg.Get_sf_user_pass ( p_user_name => l_user,    -- o v
    p_password  => l_password,-- o v
    p_env       => l_env,     -- o v
    p_jndi_name => l_jndi_name, -- o v
    p_err_code  => l_err_code,-- o v
    p_err_msg   => l_err_msg);-- o v */

    service_qname       := sys.utl_dbws.to_qname('http://xmlns.oracle.com/xxSF2OA_interfaces',
				 'xxSF2OA_interfaces');
    l_string_type_qname := sys.utl_dbws.to_qname('http://www.w3.org/2001/XMLSchema',
				 'string');
    service_            := sys.utl_dbws.create_service(service_qname);
    call_               := sys.utl_dbws.create_call(service_);

    --   IF nvl(fnd_profile.value('XXSF2OA_ENABLE_BPEL_11G'), 'N') = 'Y' THEN -- CHG0037918
    fnd_file.put_line(fnd_file.log,
	          'XXOBJT_SF2OA_SOA_SRV_NUM=' ||
	          fnd_profile.value('XXOBJT_SF2OA_SOA_SRV_NUM'));

    IF nvl(fnd_profile.value('XXOBJT_SF2OA_SOA_SRV_NUM'), '1') = '1' THEN
      -- CHG0037918
      sys.utl_dbws.set_target_endpoint_address(call_,
			           xxobjt_bpel_utils_pkg.get_bpel_host_srv1 ||
			           '/soa-infra/services/sf/xxSF2OA_interfaces/client?WSDL');

    ELSE
      sys.utl_dbws.set_target_endpoint_address(call_,
			           xxobjt_bpel_utils_pkg.get_bpel_host_srv2 ||
			           '/soa-infra/services/sf/xxSF2OA_interfaces/client?WSDL');

    END IF;

    sys.utl_dbws.set_property(call_, 'SOAPACTION_USE', 'TRUE');
    sys.utl_dbws.set_property(call_, 'SOAPACTION_URI', 'process');
    sys.utl_dbws.set_property(call_, 'OPERATION_STYLE', 'document');
    sys.utl_dbws.set_property(call_,
		      'ENCODINGSTYLE_URI',
		      'http://schemas.xmlsoap.org/soap/encoding/');
    sys.utl_dbws.add_parameter(call_,
		       'source_name',
		       l_string_type_qname,
		       'ParameterMode.IN');
    sys.utl_dbws.add_parameter(call_,
		       'batch_id',
		       l_string_type_qname,
		       'ParameterMode.IN');
    sys.utl_dbws.set_return_type(call_, l_string_type_qname);
    -- Set the input
    request := sys.xmltype('<ns1:xxSF2OA_interfacesProcessRequest xmlns:ns1="http://xmlns.oracle.com/xxSF2OA_interfaces">
		      <ns1:source_name>' || p_source_name ||
		   '</ns1:source_name>' || '<ns1:batch_id>' ||
		   p_batch_id || '</ns1:batch_id>' || '<ns1:user>' ||
		   l_user || '</ns1:user>' || '<ns1:pass>' ||
		   l_password || '</ns1:pass>' || '<ns1:jndi_name>' ||
		   /*'eis/DB/oa'*/
		   l_jndi_name || '</ns1:jndi_name>' ||
		   '<ns1:endpoint_login_url>' || l_endpoint_login ||
		   '</ns1:endpoint_login_url>' ||
		   '<ns1:endpoint_services_url>' ||
		   l_endpoint_service ||
		   '</ns1:endpoint_services_url>' ||
		   '</ns1:xxSF2OA_interfacesProcessRequest>');

    response := sys.utl_dbws.invoke(call_, request);
    sys.utl_dbws.release_call(call_);
    sys.utl_dbws.release_service(service_);
    --v_error   := response.getstringval();
    p_respond := response; --response;

    /*<xxSF2OA_interfacesProcessResponse xmlns="http://xmlns.oracle.com/xxSF2OA_interfaces">
      <BPEL_ERR_CODE>0</BPEL_ERR_CODE>
      <BPEL_ERR_MSG>Completed successfully</BPEL_ERR_MSG>
      <BPEL_INSTANCE_ID>4995771</BPEL_INSTANCE_ID>
    </xxSF2OA_interfacesProcessResponse>
    */

    dbms_output.put_line(response.getstringval());

    fnd_file.put_line(fnd_file.log,
	          'Call BPEL Process responde - ' ||
	          response.getstringval());

    ------

    ------

  EXCEPTION
    WHEN OTHERS THEN
      --fnd_file.put_line(fnd_file.log,response.getstringval());
      dbms_output.put_line(substr(SQLERRM, 1, 250));
      --dbms_output.put_line('response.getstringval - '||response.getstringval());
      v_error    := substr(SQLERRM, 1, 250);
      p_status   := 'ERR';
      p_message  := 'Error Run Bpel Interface: p_batch_id - ' || p_batch_id ||
	        ' - ' || v_error;
      l_err_msg  := 'Error Run Bpel Interface: p_batch_id - ' || p_batch_id ||
	        ' - ' || v_error;
      l_err_code := '1';
      sys.utl_dbws.release_call(call_);
      sys.utl_dbws.release_service(service_);
      upd_system_err(p_batch_id => p_batch_id, -- i n
	         p_err_code => l_err_code, -- i/o v
	         p_err_msg  => l_err_msg); -- i/o v

  END call_bpel_process;

  --------------------------------------------------------------------
  --  name:            Main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/09/2010  Dalit A. Raviv    initial build
  -- 1.1   11.5.2014   yuval tal         change CHG0031508 insert to oa2sf interface table for ID's backwards update
  -- 1.2   04.03.19     Lingaraj          INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
  --------------------------------------------------------------------
  PROCEDURE main(errbuf        OUT VARCHAR2,
	     retcode       OUT VARCHAR2,
	     p_source_name IN VARCHAR2) IS

    CURSOR respond_c(p_respond xmltype) IS
      SELECT extractvalue(VALUE(xml),
		  '/xxSF2OA_interfacesProcessResponse/BPEL_ERR_CODE') bpel_err_code,
	 extractvalue(VALUE(xml),
		  '/xxSF2OA_interfacesProcessResponse/BPEL_ERR_MSG') bpel_err_msg,
	 extractvalue(VALUE(xml),
		  '/xxSF2OA_interfacesProcessResponse/BPEL_INSTANCE_ID') bpel_instance_id
      FROM   TABLE(xmlsequence(extract(p_respond,
			   '/xxSF2OA_interfacesProcessResponse'))) xml;

    l_batch_id         NUMBER := NULL;
    l_err_code         VARCHAR2(50) := NULL;
    l_err_msg          VARCHAR2(2500) := NULL;
    l_status           VARCHAR2(10) := NULL;
    l_message          VARCHAR2(2500) := NULL;
    l_respond          sys.xmltype;
    l_count_header_err NUMBER := 0;
    l_count_line_err   NUMBER := 0;
    l_flag             VARCHAR2(2) := 'N';
  BEGIN
    -- set g_user_id SALESFORCE User
    set_salesforce_user;

    -- Insert row to interface haeder tbl
    insert_into_header(p_source_name => p_source_name, -- i v
	           p_batch_id    => l_batch_id, -- o n
	           p_err_code    => l_err_code, -- o v
	           p_err_msg     => l_err_msg); -- o v

    -- handle call bpel
    call_bpel_process(p_source_name => p_source_name, -- i v
	          p_batch_id    => l_batch_id, -- i n
	          p_status      => l_status, -- o v
	          p_message     => l_message, -- o v
	          p_respond     => l_respond); -- o sys.xmltype)

    l_respond := remove_xmlns(l_respond);
    FOR respond_r IN respond_c(l_respond) LOOP

      IF respond_r.bpel_err_code <> 0 THEN
        l_flag  := 'Y';
        retcode := 1;
        errbuf  := 'Bpel Return with errors - source - ' || p_source_name ||
	       ' Batch id - ' || l_batch_id || ' - ' || ' substr(' ||
	       respond_r.bpel_err_msg || ',1,1000)';
      ELSE
        retcode := 0;
        errbuf  := 'Success create - ' || p_source_name;
      END IF;
      UPDATE xxobjt_sf2oa_interface_h h
      SET    h.oa_err_code      = respond_r.bpel_err_code,
	 h.oa_err_msg       = substr(respond_r.bpel_err_msg, 1, 2000),
	 h.bpel_instance_id = respond_r.bpel_instance_id
      WHERE  h.oracle_batch_id = l_batch_id
	--and  h.bpel_instance_id       = respond_r.bpel_instance_id
      AND    (h.oa_err_code IS NULL OR h.oa_err_code = 0);
      COMMIT;
    END LOOP;

    IF l_flag = 'N' THEN
      SELECT nvl(COUNT(1), 0)
      INTO   l_count_header_err
      FROM   xxobjt_sf2oa_interface_h h
      WHERE  h.oracle_batch_id = l_batch_id
      AND    h.oa_err_code = 1
      AND    h.oracle_batch_id = l_batch_id;

      SELECT nvl(COUNT(1), 0)
      INTO   l_count_line_err
      FROM   xxobjt_sf2oa_interface_l l
      WHERE  l.oracle_batch_id = l_batch_id
      AND    l.oa_err_code = 1
      AND    l.oracle_batch_id = l_batch_id;

      IF l_count_header_err > 0 OR l_count_line_err > 0 THEN
        retcode := 1;
        errbuf  := 'Failed to create - ' || p_source_name ||
	       ' In Oracle, Batch Id - ' || l_batch_id;
      ELSE
        retcode := 0;
        errbuf  := 'Success to create - ' || p_source_name || ' In Oracle' ||
	       ' Batch id - ' || l_batch_id;
      END IF;
    END IF;

    --------------------------
    /*INC0148774 Commented
    --- CHG0031508
    --- insert to oa2sf interface table for ID's backwards update
    fnd_file.put_line(fnd_file.log,
	          '.. Before insert to oa-sf interface table ');
    DECLARE
      l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
      l_status    VARCHAR2(50) := NULL;
      l_oracle_id NUMBER;
      l_err_code  VARCHAR2(10) := 0;
      l_err_desc  VARCHAR2(2500) := NULL;

      CURSOR c IS
        SELECT t.status,
	   t.oracle_id,
	   h.source_name,
	   h.oa_err_code

        FROM   xxobjt_sf2oa_interface_l t,
	   xxobjt_sf2oa_interface_h h
        WHERE  t.oracle_batch_id = h.oracle_batch_id
        AND    t.oracle_batch_id = l_batch_id;
    BEGIN
      FOR i IN c LOOP
        \* xxobjt_debug_proc(p_message1 => 'i.oracle_id=' || i.oracle_id ||
        ' i.source_name=' || i.source_name ||
        ' i.oa_err_code' || i.oa_err_code);*\
        IF i.oracle_id IS NOT NULL AND i.source_name IS NOT NULL AND
           i.status != 'SF_ERR' AND i.oa_err_code = 0 THEN
          fnd_file.put_line(fnd_file.log,
		    'i.oracle_id ' || i.oracle_id ||
		    ' i.source_name-' || i.source_name);

          dbms_output.put_line('i.oracle_id ' || i.oracle_id ||
		       ' i.source_name-' || i.source_name);
          l_oa2sf_rec.source_id   := i.oracle_id;
          l_oa2sf_rec.source_name := i.source_name;
          xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				           p_err_code  => l_err_code, -- o v
				           p_err_msg   => l_err_desc); -- o v

        END IF;

      END LOOP;
      COMMIT;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
      WHEN too_many_rows THEN
        NULL;
    END;
    */--INC0148774 Comment End
    --------------------------
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Gen EXC - main - ' || substr(SQLERRM, 1, 240);
  END main;

  --------------------------------------------------------------------
  --  name:            purge_log_tables
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/07/2012
  --------------------------------------------------------------------
  --  purpose :        Procedure that cwill delete xxobjt_sf2oa_interface_l table
  --                   data that is older then 6 month.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/07/2012  Dalit A. Raviv    initial build
  --  1.1 22.6.16      yuval tal change   CHG0038819 purge logic
  --------------------------------------------------------------------
  PROCEDURE purge_log_tables(errbuf        OUT VARCHAR2,
		     retcode       OUT VARCHAR2,
		     p_num_of_days IN NUMBER) IS

    --l_days number := 0;
  BEGIN
    -- xxobjt_sf2oa_interface_h
    -- xxobjt_sf2oa_interface_l
    errbuf  := NULL;
    retcode := 0;

    --l_days := fnd_profile.value('XXOBJT_FS2OA_NUM_OF_MONTHS_TO_PURGE');

    -- DELETE xxobjt_sf2oa_interface_l l
    -- WHERE  l.creation_date < SYSDATE - p_num_of_days;

    DELETE FROM xxobjt_sf2oa_interface_l
    WHERE  oracle_event_id IN
           (SELECT oracle_event_id
	FROM   (SELECT oracle_event_id,
		   sf_id,
		   status,
		   t.oa_err_code,
		   t.creation_date,
		   row_number() over(PARTITION BY sf_id ORDER BY t.creation_date DESC) x_rownum

	        -- into l_rec_xml,l_sf_id
	        FROM   xxobjt_sf2oa_interface_l t
	        WHERE  t.creation_date < SYSDATE - p_num_of_days)
	WHERE  x_rownum != 1);
    errbuf := 'Num of records deleted from xxobjt_sf2oa_interface_l: ' ||
	  SQL%ROWCOUNT;

    COMMIT;

    fnd_file.put_line(fnd_file.log, errbuf);
    -- DELETE xxobjt_sf2oa_interface_h h
    --  WHERE  h.creation_date < SYSDATE - p_num_of_days;

    DELETE FROM xxobjt_sf2oa_interface_h h
    WHERE  NOT EXISTS (SELECT 1
	FROM   xxobjt_sf2oa_interface_l l
	WHERE  l.oracle_batch_id = h.oracle_batch_id)
    AND    h.creation_date < SYSDATE - p_num_of_days;

    fnd_file.put_line(fnd_file.log,
	          'Num of records deleted from xxobjt_sf2oa_interface_h: ' ||
	          SQL%ROWCOUNT);

    COMMIT;

    BEGIN
      EXECUTE IMMEDIATE ('alter table xxobjt.XXOBJT_SF2OA_INTERFACE_H enable row movement');
      EXECUTE IMMEDIATE ('alter table xxobjt.XXOBJT_SF2OA_INTERFACE_H shrink space compact');
      EXECUTE IMMEDIATE ('alter table xxobjt.XXOBJT_SF2OA_INTERFACE_H shrink space');
      EXECUTE IMMEDIATE ('alter table xxobjt.XXOBJT_SF2OA_INTERFACE_H shrink space cascade');
      EXECUTE IMMEDIATE ('alter table xxobjt.XXOBJT_SF2OA_INTERFACE_L enable row movement');
      EXECUTE IMMEDIATE ('alter table xxobjt.XXOBJT_SF2OA_INTERFACE_L shrink space compact');
      EXECUTE IMMEDIATE ('alter table xxobjt.XXOBJT_SF2OA_INTERFACE_L shrink space');
      EXECUTE IMMEDIATE ('alter table xxobjt.XXOBJT_SF2OA_INTERFACE_L shrink space cascade');
    END;

  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'purge_log_tables failed - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END purge_log_tables;

  --------------------------------------------------------------------
  --  name:            get_sf_id_exist
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/10/2012
  --------------------------------------------------------------------
  --  purpose :        function that check if sf_id already exist in oracle.
  --                   if yes this is a mistake and we do not want the program
  --                   create new object that is allready exists.
  --
  --  Return:          N - did not found any rows match -> This case will continue the program
  --                   Y - found at list one row match  -> This case will update row with error.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/10/2012  Dalit A. Raviv    initial build
  --  1.1 22.6.16      yuval tal         CHG0038819  - return oracle id if found
  --------------------------------------------------------------------
  FUNCTION get_sf_id_exist(p_source_name IN VARCHAR2,
		   p_sf_id       IN VARCHAR2) RETURN VARCHAR2 IS

    l_oracle_id NUMBER := 0;
  BEGIN
    IF p_source_name = 'ACCOUNT' THEN

      SELECT acc.cust_account_id
      INTO   l_oracle_id
      FROM   hz_cust_accounts acc
      WHERE  acc.attribute4 = p_sf_id
      AND    acc.status = 'A';

    ELSIF p_source_name = 'SITE' THEN

      SELECT site.cust_acct_site_id
      INTO   l_oracle_id
      FROM   hz_cust_acct_sites_all site
      WHERE  attribute1 = p_sf_id
      AND    site.status = 'A';

    ELSIF p_source_name = 'CONTACT' THEN

      SELECT roles.cust_account_role_id
      INTO   l_oracle_id
      FROM   hz_cust_account_roles roles
      WHERE  roles.attribute1 = p_sf_id
      AND    roles.status = 'A';

    END IF;

    RETURN l_oracle_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;

  END get_sf_id_exist;

END xxobjt_sf2oa_interface_pkg;
/