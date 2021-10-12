CREATE OR REPLACE PACKAGE BODY APPS.xxinv_kanban_card_pkg AS
---------------------------------------------------------------------------------------
--  Name:            xxinv_kanban_card_pkg
--  Created By:      Hubert, Eric
--  Revision:        1.0
--  Creation Date:   25-MAY-2018
--  Object Type :    Package Body
---------------------------------------------------------------------------------------
--  Purpose: Print Kanban Cards with emphasis on flexible parameters and sorting.
---------------------------------------------------------------------------------------
--  ver  date          name                 desc
--  1.0  25-MAY-2018   Eric Hubert          CHG0043094 - Initial build
---------------------------------------------------------------------------------------
    g_pkg_name         CONSTANT VARCHAR2(30) := 'xxinv_kanban_card_pkg';
    g_printer_name     VARCHAR2(150);

	---------------------------------------------------------------------------------------
	--  Name:            write_message
	--  Created By:      
	--  Revision:        1.0
	--  Creation Date:   25-MAY-2018
	---------------------------------------------------------------------------------------
	--  Purpose: 
	---------------------------------------------------------------------------------------
	--  ver  date          name                 desc
	--  1.0  25-MAY-2018   Eric Hubert          CHG0043094 - Initial build
	---------------------------------------------------------------------------------------
    PROCEDURE write_message(p_msg         VARCHAR2,
                            p_destination VARCHAR2 DEFAULT fnd_file.log) IS
    BEGIN
        IF fnd_global.conc_request_id = '-1' THEN
            dbms_output.put_line(p_msg);
        ELSE
            fnd_file.put_line(p_destination,
                            p_msg);
        END IF;
    END write_message;

	---------------------------------------------------------------------------------------
	--  Name:            beforereport
	--  Created By:      Hubert, Eric
	--  Revision:        1.0
	--  Creation Date:   25-MAY-2018
	---------------------------------------------------------------------------------------
	--  Purpose: 
	---------------------------------------------------------------------------------------
	--  ver  date          name                 desc
	--  1.0  25-MAY-2018   Eric Hubert          CHG0043094 - Initial build
	---------------------------------------------------------------------------------------
    FUNCTION beforereport RETURN BOOLEAN IS
    BEGIN
        fnd_file.put_line(fnd_file.log, 'DEBUG: Starting BEFOREREPORT.');
        p_conc_request_id := fnd_global.conc_request_id;

        BEGIN
            /* Call custom function to specify the sorting for the data template's main query.*/
            p_lexical_order_by_clause_main := order_by_clause;
            /* Log the lexical values returned to the data template.*/
            fnd_file.put_line(fnd_file.log, 'DEBUG: p_lexical_order_by_clause_main: "' || p_lexical_order_by_clause_main || '"');
        END;

        /* Exclude/include reprints */
        DECLARE
            l_temp_where VARCHAR2(200);
        BEGIN
            IF p_include_reprints <> 'Y' THEN
                fnd_file.put_line(fnd_file.log, 'DEBUG: do not include reprints.');
                /* If the Print Event DFF (attribute1) is not null then the kanban
                card has been printed before.  Unless the user explicitly indicates
                that they want to include reprints, we will exclude them. */
                l_temp_where := l_temp_where || ' AND skc.print_event_dff IS NULL';
                p_lexical_where_clause_main := p_lexical_where_clause_main || l_temp_where;
            ELSE
                fnd_file.put_line(fnd_file.log, 'DEBUG: include reprints.');
            END IF;
        END;
        
----What is this for below?  Do I need it?  g_printer_name does not seem to be used (but I have been getting warning when printing to a physical printer)
----        BEGIN
----            /* Get the printer name for the Concurrent Request*/
----            SELECT printer
----            INTO   g_printer_name
----            FROM   fnd_conc_req_summary_v
----            WHERE  request_id = p_conc_request_id;
----        END;
 
        fnd_file.put_line(fnd_file.log, 'DEBUG: End of BEFOREREPORT.');
        RETURN TRUE;
    END beforereport;

	---------------------------------------------------------------------------------------
	--  Name:            afterreport
	--  Created By:      Hubert, Eric
	--  Revision:        1.0
	--  Creation Date:   25-MAY-2018
	---------------------------------------------------------------------------------------
	--  Purpose: 
	---------------------------------------------------------------------------------------
	--  ver  date          name                 desc
	--  1.0  25-MAY-2018   Eric Hubert          CHG0043094 - Initial build
	---------------------------------------------------------------------------------------
    FUNCTION afterreport RETURN BOOLEAN IS
    BEGIN
        fnd_file.put_line(fnd_file.log, 'DEBUG: Starting of AFTERREPORT.');
        /*SRW.USER_EXIT('FND SRWEXIT')*/
        NULL;
        fnd_file.put_line(fnd_file.log, 'DEBUG: End of AFTERREPORT.');
        RETURN(TRUE);
    END afterreport;
  
    /* Dynamically build a WHERE clause for the query.*/
    FUNCTION afterpform RETURN BOOLEAN IS
        l_temp_where VARCHAR2(200);
    BEGIN
        fnd_file.put_line(fnd_file.log, 'DEBUG: Starting AFTERPFORM.');
        IF p_kanban_card_number_low IS NOT NULL THEN
            l_temp_where := ' AND skc.kanban_card_number >= :p_kanban_card_number_low';
            p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_kanban_card_number_high IS NOT NULL THEN
            l_temp_where := ' AND skc.kanban_card_number <= :p_kanban_card_number_high';
            p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_pull_sequence_id IS NOT NULL THEN
            l_temp_where := ' AND skc.pull_sequence_id = :p_pull_sequence_id';
            p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_card_created_by IS NOT NULL THEN
            l_temp_where := ' AND skc.card_created_by = :p_card_created_by';
            p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_card_created_date_low IS NOT NULL THEN
            l_temp_where := ' AND skc.card_creation_date >= :p_card_created_date_low';
            p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_card_created_date_high IS NOT NULL THEN
            l_temp_where := ' AND skc.card_creation_date <= :p_card_created_date_high';
            p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        /* Inventory source location paramaters */
        IF p_source_subinv IS NOT NULL THEN
             l_temp_where := ' AND skc.source_subinventory = :p_source_subinv';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        /* Destination parameters */
        IF p_dest_subinv IS NOT NULL THEN
             l_temp_where := ' AND skc.destination_subinventory = :p_dest_subinv';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_dest_locator_id IS NOT NULL THEN
             l_temp_where := ' AND skc.destination_locator_id = :p_dest_locator_id';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_dest_locator_segment_01 IS NOT NULL THEN
             l_temp_where := ' AND skc.dest_locator_segment_01 = :p_dest_locator_segment_01';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_dest_locator_segment_02 IS NOT NULL THEN
             l_temp_where := ' AND skc.dest_locator_segment_02 = :p_dest_locator_segment_02';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_dest_locator_segment_03 IS NOT NULL THEN
             l_temp_where := ' AND skc.dest_locator_segment_03 = :p_dest_locator_segment_03';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_dest_locator_segment_04 IS NOT NULL THEN
             l_temp_where := ' AND skc.dest_locator_segment_04 = :p_dest_locator_segment_04';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        /* Ultimate Deliver-To parameters*/
        IF p_udt_subinv IS NOT NULL THEN
             l_temp_where := ' AND sps.udt_subinventory = :p_udt_subinv';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_udt_locator_id IS NOT NULL THEN
             l_temp_where := ' AND sps.udt_locator_id = :p_udt_locator_id';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_udt_locator_segment_01 IS NOT NULL THEN
             l_temp_where := ' AND sps.udt_locator_segment_01 = :p_udt_locator_segment_01';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_udt_locator_segment_02 IS NOT NULL THEN
             l_temp_where := ' AND sps.udt_locator_segment_02 = :p_udt_locator_segment_02';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_udt_locator_segment_03 IS NOT NULL THEN
             l_temp_where := ' AND sps.udt_locator_segment_03 = :p_udt_locator_segment_03';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_udt_locator_segment_04 IS NOT NULL THEN
             l_temp_where := ' AND sps.udt_locator_segment_04 = :p_udt_locator_segment_04';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_source_type IS NOT NULL THEN
             l_temp_where := ' AND source_type = :p_source_type';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_card_type IS NOT NULL THEN
             l_temp_where := ' AND kanban_card_type = :p_card_type';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_supply_status IS NOT NULL THEN
             l_temp_where := ' AND supply_status = :p_supply_status';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_item_low IS NOT NULL THEN
             l_temp_where := ' AND item_number >= :p_item_low';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_item_high IS NOT NULL THEN
             l_temp_where := ' AND item_number <= :p_item_high';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_supplier_id IS NOT NULL THEN
             l_temp_where := ' AND supplier_id = :p_supplier_id';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_supplier_site_id IS NOT NULL THEN
             l_temp_where := ' AND supplier_site_id = :p_supplier_site_id';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_sourcing_org_id IS NOT NULL THEN
             l_temp_where := ' AND sourcing_org_id = :p_sourcing_org_id';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_wip_line_id IS NOT NULL THEN
             l_temp_where := ' AND wip_line_id = :p_wip_line_id';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        IF p_kanban_card_id IS NOT NULL THEN
             l_temp_where := ' AND kanban_card_id = :p_kanban_card_id';
             p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;
        
        IF p_print_event IS NOT NULL THEN
            l_temp_where := ' AND skc.print_event_dff = :p_print_event';
            p_lexical_where_clause_main  := p_lexical_where_clause_main || l_temp_where;
        END IF;

        /* Log the lexical values returned to the data template.*/
        fnd_file.put_line(fnd_file.log, 'DEBUG: Lexical values from AFTERPFORM below:');
        fnd_file.put_line(fnd_file.log, 'DEBUG: p_lexical_where_clause_main: "' || p_lexical_where_clause_main || '"');

        COMMIT;
        fnd_file.put_line(fnd_file.log, 'DEBUG: End of AFTERFORM.');
        RETURN(TRUE);
    END afterpform;
 
	---------------------------------------------------------------------------------------
	--  Name:            order_by_clause
	--  Created By:      Hubert, Eric
	--  Revision:        1.0
	--  Creation Date:   25-MAY-2018
	---------------------------------------------------------------------------------------
	--  Purpose: 
	--  1) This function will dynamically build the ORDER BY clause for the report.
	--  2) It uses the sort field parameter values provided by the user.
	--  3) The validation of the field names is not part of this function and is
	--     instead handled by a value set.
	---------------------------------------------------------------------------------------
	--  ver  date          name                 desc
	--  1.0  25-MAY-2018   Eric Hubert          CHG0043094 - Initial build
	---------------------------------------------------------------------------------------
	FUNCTION order_by_clause RETURN VARCHAR2 IS
        c_sort_field_count       CONSTANT NUMBER := 3; --Number of sorting parameters supported (we can go up to six with minimal effort as the concurrent program is ready for six).
        c_clause_prefix          CONSTANT VARCHAR2(10) := 'ORDER BY'; --Order By keyword
        c_delimiter              CONSTANT VARCHAR2(1) := ','; --Character that delimits fields in order by clause
        c_separator              CONSTANT VARCHAR2(1) := ' '; --Character that separates the field name from the sort direction
        c_default_return_value   CONSTANT VARCHAR2(1) := ' '; --Value to return if no sort is specified (a zero-length string returns an error so at least use a space character).
        c_sort_ascending         CONSTANT VARCHAR2(4) := 'ASC'; --Value to return if no sort is specified
        c_sort_descending        CONSTANT VARCHAR2(4) := 'DESC'; --Value to return if no sort is specified
        c_default_sort_direction CONSTANT VARCHAR2(4) := c_sort_ascending; --Sort direction if not explicitly specified

        i                NUMBER; --Looping variable
        l_sort_direction VARCHAR2(4); --Contains explicti or inferred sort direction
        l_temp           VARCHAR2(1000) := c_clause_prefix; --Used to build the order by clause
        l_result         VARCHAR2(1000) := NULL; --Returned value from function

        /* Array to hold sort parameter values*/
        TYPE t_string_array IS VARRAY(3) OF VARCHAR2(30); --Array of strings.  Size needs to match c_sort_field_count. (We can quickly go up to six sort fields)
        l_field_name_array     t_string_array;
        l_sort_direction_array t_string_array;
	BEGIN
        /* debug statments for log file*/
        fnd_file.put_line(fnd_file.log, 'DEBUG: Starting ORDER_BY_CLAUSE.');

        /* Build arrays from sort parameter values (We can un-comment out sort fields 4-6, if/when requierd by the business.)*/
        l_field_name_array := t_string_array(p_sort_field_01,
                         p_sort_field_02,
                         p_sort_field_03); --, P_SORT_FIELD_04, P_SORT_FIELD_05, P_SORT_FIELD_06);
        l_sort_direction_array := t_string_array(p_sort_field_01_direction,
                         p_sort_field_02_direction,
                         p_sort_field_03_direction); -- ,P_SORT_FIELD_04_DIRECTION, P_SORT_FIELD_05_DIRECTION, P_SORT_FIELD_06_DIRECTION);

        fnd_file.put_line(fnd_file.log, 'P_SORT_FIELD_01: ' || p_sort_field_01);
        fnd_file.put_line(fnd_file.log,
                  'P_SORT_FIELD_01_DIRECTION: ' ||
                  p_sort_field_01_direction);
        fnd_file.put_line(fnd_file.log, 'P_SORT_FIELD_02: ' || p_sort_field_02);
        fnd_file.put_line(fnd_file.log,
                  'P_SORT_FIELD_02_DIRECTION: ' ||
                  p_sort_field_02_direction);
        fnd_file.put_line(fnd_file.log, 'P_SORT_FIELD_03: ' || p_sort_field_03);
        fnd_file.put_line(fnd_file.log,
                  'P_SORT_FIELD_03_DIRECTION: ' ||
                  p_sort_field_03_direction);
        fnd_file.put_line(fnd_file.log, 'P_SORT_FIELD_04: ' || p_sort_field_04);
        fnd_file.put_line(fnd_file.log,
                  'P_SORT_FIELD_04_DIRECTION: ' ||
                  p_sort_field_04_direction);
        fnd_file.put_line(fnd_file.log, 'P_SORT_FIELD_05: ' || p_sort_field_05);
        fnd_file.put_line(fnd_file.log,
                  'P_SORT_FIELD_05_DIRECTION: ' ||
                  p_sort_field_05_direction);
        fnd_file.put_line(fnd_file.log, 'P_SORT_FIELD_06: ' || p_sort_field_06);
        fnd_file.put_line(fnd_file.log,
                  'P_SORT_FIELD_06_DIRECTION: ' ||
                  p_sort_field_06_direction);

        /* Check that the associateive arrays are of the correct size. */
        CASE
          WHEN (l_field_name_array.count <> c_sort_field_count) OR
               (l_sort_direction_array.count <> c_sort_field_count) THEN
            --dbms_output.put_line('Error: invalid array length.');
            fnd_file.put_line(fnd_file.log, 'Error: invalid array length.');
          ELSE
            --dbms_output.put_line('Array length is correct');
            fnd_file.put_line(fnd_file.log, 'Array length is correct');
        END CASE;

        /* Build dynamic order by clause. */
        FOR i IN 1 .. c_sort_field_count LOOP
          fnd_file.put_line(fnd_file.log, 'Loop iteration #: ' || i);
          dbms_output.put_line(l_field_name_array(i) || ',' ||
               l_sort_direction_array(i));
          IF l_field_name_array(i) IS NOT NULL THEN

            /* Prefix with a comma if not first field */
            IF (l_temp <> c_clause_prefix) AND (i <> 1) THEN
              l_temp := l_temp || c_delimiter || c_separator;
              /* Put space between order by clause and first field name. */
            ELSIF (l_temp = c_clause_prefix) THEN
              l_temp := l_temp || c_separator;
            END IF;

            /* Determine the sort order with some validation*/
            l_sort_direction := l_sort_direction_array(i);

            IF l_sort_direction NOT IN (c_sort_ascending, c_sort_descending) THEN
              l_sort_direction := c_default_sort_direction;
            END IF;

            /* Rebuild Order By clause to reflect current sort field and direction*/
            l_temp := l_temp || l_field_name_array(i) || c_separator ||
              l_sort_direction;

          END IF;
          fnd_file.put_line(fnd_file.log,
            'New l_temp value at end of iteration: ' || l_temp);

        END LOOP;

        /* If no fields were specified for the sort then return an empty string. */
        IF l_temp = c_clause_prefix THEN
          fnd_file.put_line(fnd_file.log,
            'No sort parameters specified, using default sort: ' ||
            c_default_return_value);
          l_temp := c_default_return_value;
        END IF;

        l_result := l_temp;
        --    fnd_file.put_line( fnd_file.log, 'Result: ' || order_by_clause);  --***This line is causing the program to run indefinitely
        fnd_file.put_line(fnd_file.log, 'DEBUG: End of ORDER_BY_CLAUSE.');
        RETURN l_result;
	END order_by_clause;


  --------------------------------------------------------------------
  --  Name:               update_print_event_dff
  --  Created By:         Hubert, Eric
  --  Revision:           1.0
  --  Creation Date:      25-MAY-2018
  --  Purpose :           Update a specified Kanban Card's Print Event DFF
  --    when called via the SQL statement from the report's XML Publisher
  --    data template. The XXINV: Kanban Card program needs to be able
  --    to know, if a Kanban Card has already been printed for that line.  The program can know this by
  --    examining the Print Event DFF.  A non-null value means that the line has
  --    already had a kanban card printed for it.  The updating of the
  --    Print Event DFF can by disabled via the parameter, Update Print Event DFF.
  --------------------------------------------------------------------
  --  Business Requirement: The ability to optionally suppress reprinting of a
  --    kanban card is important to the business so that there are not
  --    two physical copies of the kanban card on the shop floor/warehouse
  --    at one time.  This would lead to attempting to replenish the same 
  --    kanban card twice and then getting system errors when the card is 
  --    already in process.  
  --
  --    In addition, the business will manually enter a value in the DFF of 
  --    multiple cards to designate a "batch".  When the program runs to 
  --    print the batch, it should overwrite the batch# in the DFF to indicate
  --    that it has been printed.
  ----------------------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0  25-MAY-2018   Eric Hubert          CHG0043094 - Initial build
    -------------------------------------------------------------------------------
  FUNCTION  update_print_event_dff(p_kanban_card_id IN NUMBER) RETURN VARCHAR2 IS
    /* Allow updates to database (kanban cardline record) when function is called from
    a SQL statement in the XML Publisher Data Template for XXINV: Kanban Card. */
    PRAGMA AUTONOMOUS_TRANSACTION;

    /* Constants*/
    c_field_delimiter        CONSTANT VARCHAR2(1) := '/'; --Separates fields within a print event (Printed Date and Concurrent Request ID)
    c_datetime_format_1      CONSTANT VARCHAR2(30) := 'DD-MON-YYYY HH:MI:SS AM'; --Format of the Date/Time for intermediate calculation
    c_datetime_format_2      CONSTANT VARCHAR2(30) := 'DD-MON-YYYY HH:MI:SS AM TZD'; --Format of the Date/Time that is written to the DFF
    c_error_msg_1  CONSTANT VARCHAR2(150) := 'Print Event could not be updated for line_id (' || p_kanban_card_id || ') ';--Function value to return upon error

    /* Local Variables*/
    l_date_temp VARCHAR2(30);  --Temp string for user-friendly concurrent request date
    l_dff_value VARCHAR2(150); --Stores updated value for Print Event DFF
    l_kanban_card_record mtl_kanban_cards%ROWTYPE; --Kanban Card record
    l_server_timezone_code VARCHAR2(100);
    l_client_timezone_code VARCHAR2(100);

  BEGIN
    /* Get the Kanban Card record. */
    SELECT *
    INTO   l_kanban_card_record
    FROM   mtl_kanban_cards
    WHERE  kanban_card_id = p_kanban_card_id;

    /* Check to see if the DFF should be updated (controlled by a program parameter). */
    IF p_update_print_event_dff = 'Y' THEN
        --fnd_file.put_line(fnd_file.log,'DO update Print Event DFF.');

        /* Get the timezone code for the server. */
        SELECT timezone_code INTO l_server_timezone_code
					FROM FND_TIMEZONES_VL
					WHERE upgrade_tz_id = fnd_profile.value('SERVER_TIMEZONE_ID');

        /* Get the timezone code for the user. */
        SELECT timezone_code INTO l_client_timezone_code
        FROM fnd_timezones_vl WHERE
				upgrade_tz_id = fnd_profile.value('CLIENT_TIMEZONE_ID');

        /* Determine the date and time in terms of the user's preferred time zone. */
		l_date_temp :=
            TO_CHAR(
                    FROM_TZ(
                             TO_TIMESTAMP(TO_CHAR(SYSDATE, c_datetime_format_1), c_datetime_format_1)
                             , (l_server_timezone_code)) AT TIME ZONE l_client_timezone_code
                    , c_datetime_format_2
                   )
			;

        /* Build the updated Print Event DFF value, consisting of the
        date, concurrent request ID, and user name. */
        l_dff_value :=
            l_date_temp
            || c_field_delimiter
            || fnd_global.conc_request_id
            || c_field_delimiter
            || fnd_profile.value('USERNAME');

         /* Assign new values. */
        l_kanban_card_record.attribute1        := l_dff_value;
        l_kanban_card_record.last_updated_by   := fnd_profile.value('USER_ID');
        l_kanban_card_record.last_update_date  := SYSDATE;
        l_kanban_card_record.last_update_login := USERENV('SESSIONID');

        /* Update the Kanban Card record with the new values. */
        UPDATE mtl_kanban_cards
        SET    ROW = l_kanban_card_record
        WHERE  kanban_card_id = p_kanban_card_id;

        /* Because this function works autonomously, this commit pertains only
        to the updating of the kanban card and not any other transactions (if any)
        associated with this progrm.*/
        COMMIT;
    ELSE
        --fnd_file.put_line(fnd_file.log,'Do NOT update Print Event DFF.');
        /* Use the current DFF value.*/
        l_dff_value := l_kanban_card_record.attribute1;
    END IF;

    /* Return */
    RETURN l_dff_value;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN c_error_msg_1 || SQLERRM;
      ROLLBACK;
  END update_print_event_dff;

    -----------------------------------------------------------------------
    --  Name:               print_kanban_cards
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-May-2018
    --  Purpose :           This function will create a concurrent request for the 
    --  'XXQA: Kanban Card' (XXINV_KANBAN_CARD).  The function has 
    --  separate arguments for the Kanban Card Number, Kanban Card ID, and Pull Sequence ID.
    --  This allows for the printing of a specific scope of kanban cards, for a
    --  single specific card or for all cards in a pull sequence.  The intent
    --  is to call this function from a forms personalization on the Pull
    --  Sequence and/or Kanban Card forms.
    --  
    --  There is an argument for explicitly indicating which printer should be used,
    --  to bypass any rules within the function for determining which printer should
    --  be used.
    ----------------------------------------------------------------------------------
    --  ver   date          name            desc
    --  1.0   24-Jul-2018   Hubert, Eric    CHG0041284 - Initial build
    -----------------------------------------------------------------------------------
    FUNCTION print_kanban_cards (
     p_organization_id IN NUMBER
     , p_kanban_card_number IN VARCHAR2  --Eith kanban card number or pull sequence id need to be specified.
     , p_pull_sequence_id IN VARCHAR2
     , p_report_layout IN VARCHAR2  --Optional layout (if null, it is determined with a profile option).
     , p_printer_name IN VARCHAR2 --Optional printer name  (if null, it is determined with a profile option).
    ) RETURN NUMBER --Return Concurrent Request ID
    IS
        /* Local Variables*/
        l_organization_id NUMBER := p_organization_id;
        l_kanban_card_number_low VARCHAR2(10) := p_kanban_card_number;
        l_kanban_card_number_high VARCHAR2(10) := p_kanban_card_number;
        l_pull_sequence_id NUMBER := p_pull_sequence_id;
        l_report_layout VARCHAR2(30);
        l_printer_name VARCHAR2(30);--Optional printer name
        l_profile_option_value_1 VARCHAR2(30);--Profile option value for default kanban card printer
        l_profile_option_value_2 VARCHAR2(30);--Profile option value for default printer
        l_profile_option_value_3 VARCHAR2(30);--Profile option value for default copies
        l_profile_option_value_4 VARCHAR2(30);--Profile option value for default kanban card layout
        l_copies NUMBER;

        l_layout_result BOOLEAN;
        l_print_options_result BOOLEAN;
        l_request_id NUMBER;
    
    BEGIN
        /* Get profile valuesu. */
        l_profile_option_value_1 := fnd_profile.value('XXINV_DEFAULT_KANBAN_CARD_PRINTER');
        l_profile_option_value_2 := fnd_profile.value('Printer');
        l_profile_option_value_3 := fnd_profile.value('Concurrent:Report Copies');
        l_profile_option_value_4 := fnd_profile.value('XXINV_DEFAULT_KANBAN_CARD_LAYOUT');
        
        /* Determine the printer to be used. */
        CASE WHEN p_printer_name IS NOT NULL THEN --Use printer explicitly passed to function
            l_printer_name := p_printer_name;
        WHEN l_profile_option_value_1 IS NOT NULL THEN
            l_printer_name := l_profile_option_value_1; --Printer from profile option (XX: QA Default Label Printer)
        WHEN l_profile_option_value_2 IS NOT NULL THEN
            l_printer_name := l_profile_option_value_2; --Printer from profile option (Printer)
        ELSE
            l_printer_name := 'noprint';  --Hardcoded default printer (noprint)
        END CASE;
        
        dbms_output.put_line('l_printer_name: ' || l_printer_name);

        /* Determine the layout to be used. */
        l_report_layout := COALESCE(p_report_layout, l_profile_option_value_4);

        /* Determine number of copies*/
        l_copies := TO_NUMBER(l_profile_option_value_3); --Printer from profile option (Printer)
        dbms_output.put_line('l_copies: ' || l_copies);

        /* Check that the necessary parameters and variables have values. */
        IF (l_kanban_card_number_low IS NULL OR l_kanban_card_number_high IS NULL) AND l_pull_sequence_id IS NULL THEN
            RAISE_APPLICATION_ERROR (-20001, 'print_kanban_cards: Kanban Card Number or Pull Sequence ID not provided.');            
        ELSIF l_report_layout IS NULL THEN 
            RAISE_APPLICATION_ERROR (-20002, 'print_kanban_cards: Kanban Card Layout could not be determined.'); 
        END IF;

         /*Assign template*/
        l_layout_result := fnd_request.add_layout (
            template_appl_name=> 'XXOBJT',
            template_code => 'XXINV_KANBAN_CARD',
            template_language => 'en',
            template_territory=> 'US',
            output_format => 'PDF'
        );
        
        /*Printing options*/
        l_print_options_result := fnd_request.set_print_options (
            printer => l_printer_name,
            style=> '',
            copies => l_copies,
            save_output=> TRUE,
            print_together=> 'N'
        );

        /*Submit Request*/
        l_request_id := fnd_request.submit_request (
            application=> 'XXOBJT',
            program => 'XXINV_KANBAN_CARD',
            description=> 'XXINV: Kanban Card',
            start_time => '',
            sub_request=> FALSE,
            argument1 => l_organization_id, --Organization Identifier
            argument2 => l_kanban_card_number_low, --Kanban Card Number (from)
            argument3 => l_kanban_card_number_high, --Kanban Card Number (to)
            argument4 => l_pull_sequence_id, --Pull Sequence ID
            argument5 => NULL,  --Card Created By
            argument6 => NULL,  --Card Created Date (First)
            argument7 => NULL,  --Card Created Date (Last)
            argument8 => 'Y',   --Include Reprints. Produce output for Kanban Cards that had been previously printed.
            argument9 => NULL,  --Print Event
            argument10 => NULL,  --Source Subinventory
            argument11 => NULL, --Destination Subinventory
            argument12 => NULL, --Destination Locator
            argument13 => NULL, --Destination Locator Segment 1 (Subinventory)
            argument14 => NULL, --Destination Locator Segment 2 (Row)
            argument15 => NULL, --Destination Locator Segment 3 (Rack)
            argument16 => NULL, --Destination Locator Segment 3 (Bin)
            argument17 => NULL, --The source based on replishment source
            argument18 => NULL, --Kanban card type
            argument19 => NULL, --Card Supply Status
            argument20 => NULL, --Item (From)
            argument21 => NULL, --Item (To)
            argument22 => NULL, --Replenished by external supplier
            argument23 => NULL, --External supplier site
            argument24 => NULL, --Replenishment done by another organization
            argument25 => NULL, --WIP Line Code
            argument26 => NULL, --Kanban Card Id - currently passed from Kanban Cards Form
            argument27 => NULL, --Sequence Id of MTL_KANBAN_CARD_PRINT_TEMP
            argument28 => 'No', --Print the report header and footer
            argument29 => l_report_layout, --Report Layout
            argument30 => NULL, --DebugFlag
            argument31 => 'Y',  --When 'Yes', will update the Print Event DFF of a Kanban Card to indicate that the line was printed.
            argument32 => 'KANBAN_CARD_NUMBER', --Report field for primary sort (can be any field in data template)
            argument33 => NULL, --Sort direction for Sort Field 1
            argument34 => NULL, --Report field for secondary sort (can be any field in data template)
            argument35 => NULL, --Sort direction for Sort Field 2
            argument36 => NULL, --Report field for tertiary sort (can be any field in data template)
            argument37 => NULL  --Sort direction for Sort Field 3
        );
        
        COMMIT;
        
        /*Exceptions*/
        IF ( l_request_id <> 0)
        THEN
             dbms_output.put_line('Concurrent request succeeded: ' || l_request_id);
        ELSE
             dbms_output.put_line('Concurrent Request failed to submit: ' || l_request_id);
             dbms_output.put_line('Request Not Submitted due to "' || fnd_message.get || '".');
        END IF;       

        RETURN l_request_id;
      
        EXCEPTION
        WHEN OTHERS THEN
          /* If function was called in the context of a concurrent program,
          write the error to the log file.  Otherwise write to dbms_output. */
          IF fnd_global.conc_request_id <> -1 THEN
              write_message('Unhandled exception: ' || SQLERRM );
              dbms_output.put_line('Unhandled exception: ' || SQLERRM );
          ELSE
            write_message(SQLERRM);
            dbms_output.put_line(SQLERRM);
          END IF;

          /* Return*/
          RETURN NULL;--***Just did this as place holder for more targeted exception handling.***
    END print_kanban_cards;
END xxinv_kanban_card_pkg;
/