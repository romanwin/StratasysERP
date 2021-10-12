CREATE OR REPLACE PACKAGE BODY xxwsh_general_pkg IS

  --------------------------------------------------------------------
  --  name:            XXWSH_GENERAL_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/12/2013 15:39:30
  --------------------------------------------------------------------
  --  purpose :        CUST760 - Ship Console -CR1203 -Shipping notification mail
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/12/2013  Dalit A. Raviv    initial build
  --  1.1  08/22/2019  Diptasurjya       CHG0045128 - Remove auto contact email addition in get_shipping_mail_list
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_contact_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/12/2013 15:39:30
  --------------------------------------------------------------------
  --  purpose :        CUST760 - Ship Console - CR1203 - Shipping notification mail
  --                   Email the following recipients if they exist:
  --                   1)  Sales Order “Ship To Contact” (xxoe_contacts_v.email by contact_id)
  --                   2)  sales order “bill to contact” (xxoe_contacts_v.email by contact_id)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/12/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_contact_mail(p_contact_id IN NUMBER) RETURN VARCHAR2 IS

    l_mail VARCHAR2(2000) := NULL;
  BEGIN
    SELECT c.email_address
      INTO l_mail
      FROM apps.xxoe_contacts_v c
     WHERE c.contact_id = p_contact_id;

    RETURN l_mail;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_contact_mail;

  --------------------------------------------------------------------
  --  name:            get_contact_mail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   23/12/2013 15:39:30
  --------------------------------------------------------------------
  --  purpose :        CUST760 - Ship Console - CR1203 - Shipping notification mail
  --                   Email the following recipients if they exist:
  --                   3) Sales Order “Sales Person” OE_ORDER_HEADERS_ALL.SALESREP_ID
  --                   by the salesrep_id get the person from JTF_RS_SALESREPS
  --                   by the person get the email from per_all_people_f
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/12/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_salesrep_mail(p_salesrep_id IN NUMBER) RETURN VARCHAR2 IS

    l_salesrep_mail VARCHAR2(2000) := NULL;
  BEGIN
    SELECT p.email_address
      INTO l_salesrep_mail
      FROM jtf_rs_salesreps s,
           (SELECT person_id, email_address
              FROM per_all_people_f p1
             WHERE trunc(SYSDATE) BETWEEN p1.effective_start_date AND
                   p1.effective_end_date) p
     WHERE s.salesrep_id = p_salesrep_id --100000070
       AND p.person_id(+) = s.person_id;

    RETURN l_salesrep_mail;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_salesrep_mail;

  --------------------------------------------------------------------
  --  name:            get_shipping_mail_list
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/12/2013 15:39:30
  --------------------------------------------------------------------
  --  purpose :        CUST760 - Ship Console -CR1203 -Shipping notification mail
  --                   Email the following recipients if they exist:
  --                   1) Sales Order “Ship To Contact” (XXOE_CONTACTS_V.EMAIL BY CONTACT_ID)
  --                   2) Sales Order “Bill To Contact” (XXOE_CONTACTS_V)
  --                   3) Sales Order “Sales Person” OE_ORDER_HEADERS_ALL.SALESREP_ID JTF_RS_SALESREPS
  --                   4) Sales Order Header DFF “Ship Notif Email” (OE_ORDER_HEADERS_ALL.ATTRIBUTE20 )
  --                   5) Sales Order creator  user_id -> person -> mail
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/12/2013  Dalit A. Raviv    initial build
  --  1.1  08/22/2019  Diptasurjya       CHG0045128 - Remove auto contact email addition
  --------------------------------------------------------------------
  FUNCTION get_shipping_mail_list(p_delivery_id IN NUMBER) RETURN VARCHAR2 IS

    l_bill_mail_suffix  varchar2(10) := '(BILL)';  -- CHG0045128 added
    l_ship_mail_suffix  varchar2(10) := '(SHIP)';  -- CHG0045128 added
    l_cust_mail_suffix  varchar2(10) := '(CUST)';  -- CHG0045128 added

    CURSOR contact_c(p_delivery_id IN NUMBER) IS
    -- Ship_to
      SELECT oha.ship_to_contact_id contact_id, wnd.delivery_id
        FROM oe_order_lines_all       ola,
             oe_order_headers_all     oha,
             wsh_new_deliveries       wnd,
             wsh_delivery_assignments wda,
             wsh_delivery_details     wdd
       WHERE ola.header_id = oha.header_id
         AND wnd.delivery_id = wda.delivery_id
         AND wda.delivery_detail_id = wdd.delivery_detail_id
         AND wdd.source_line_id = ola.line_id
         AND wnd.delivery_id = p_delivery_id
      UNION
      -- bill_to
      SELECT oha.invoice_to_contact_id contact_id, wnd.delivery_id
        FROM oe_order_lines_all       ola,
             oe_order_headers_all     oha,
             wsh_new_deliveries       wnd,
             wsh_delivery_assignments wda,
             wsh_delivery_details     wdd
       WHERE ola.header_id = oha.header_id
         AND wnd.delivery_id = wda.delivery_id
         AND wda.delivery_detail_id = wdd.delivery_detail_id
         AND wdd.source_line_id = ola.line_id
         AND wnd.delivery_id = p_delivery_id;

    -- Order Info (create by, ship notif and sales person)
    CURSOR order_info_c(p_delivery_id IN NUMBER) IS
      SELECT DISTINCT oha.created_by, -- Sales Order creator
                      replace(replace(replace(oha.attribute20,l_bill_mail_suffix,''),l_ship_mail_suffix,''),l_cust_mail_suffix,'') attribute20,  -- CHG0045128 replace bill and ship identifiers
                      --oha.attribute20, -- Ship Notif Email -- CHG0045128 commented
                      oha.salesrep_id, -- Salesrep
                      wnd.delivery_id
        FROM oe_order_lines_all       ola,
             oe_order_headers_all     oha,
             wsh_new_deliveries       wnd,
             wsh_delivery_assignments wda,
             wsh_delivery_details     wdd
       WHERE ola.header_id = oha.header_id
         AND wnd.delivery_id = wda.delivery_id
         AND wda.delivery_detail_id = wdd.delivery_detail_id
         AND wdd.source_line_id = ola.line_id
         AND wnd.delivery_id = p_delivery_id; --314294

    l_contacts_mail   VARCHAR2(400) := NULL;
    l_salesrep_mail   VARCHAR2(400) := NULL;
    l_ship_notif_mail VARCHAR2(400) := NULL;
    l_creator_mail    VARCHAR2(400) := NULL;
    l_delimiter       VARCHAR2(10) := '|';

    l_mail_str  VARCHAR2(2500) := NULL;
    l_mail_str1 VARCHAR2(2500) := NULL;

  BEGIN
    -- 1,2) get Ship To Contact and bill to contact for the delivery
    -- CHG0045128 add below profile check
    if fnd_profile.VALUE('XXOM_SEND_PL_TO_CONTACT_ALWAYS') = 'Y' then
      FOR contact_r IN contact_c(p_delivery_id) LOOP
        IF l_contacts_mail IS NULL THEN
          l_contacts_mail := get_contact_mail(contact_r.contact_id);
        ELSE
          IF get_contact_mail(contact_r.contact_id) IS NOT NULL THEN
            l_contacts_mail := l_contacts_mail || l_delimiter ||
                               get_contact_mail(contact_r.contact_id);
          END IF;
        END IF;
      END LOOP;
    end if;

    -- 3) Sales Order “Sales Person” OE_ORDER_HEADERS_ALL.SALESREP_ID JTF_RS_SALESREPS
    -- 4) Sales Order Header DFF “Ship Notif Email” (OE_ORDER_HEADERS_ALL.ATTRIBUTE20 )
    -- 5) Sales Order creator  user_id -> person -> mail
    FOR order_info_r IN order_info_c(p_delivery_id) LOOP

      -- 3) Get Sales Person
      IF l_salesrep_mail IS NULL THEN
        l_salesrep_mail := get_salesrep_mail(order_info_r.salesrep_id);
      ELSE
        IF get_salesrep_mail(order_info_r.salesrep_id) IS NOT NULL THEN
          l_salesrep_mail := l_salesrep_mail || l_delimiter ||
                             get_salesrep_mail(order_info_r.salesrep_id);
        END IF;
      END IF;

      -- 4) Get Ship Notif
      IF l_ship_notif_mail IS NULL AND order_info_r.attribute20 IS NOT NULL THEN
        l_ship_notif_mail := order_info_r.attribute20;
      ELSIF l_ship_notif_mail IS NOT NULL AND
            order_info_r.attribute20 IS NOT NULL THEN
        l_ship_notif_mail := l_ship_notif_mail || l_delimiter ||
                             order_info_r.attribute20;
      END IF;

      -- 5) Sales Order create by
      IF l_creator_mail IS NULL THEN
        l_creator_mail := xxhr_util_pkg.get_person_email(xxhr_util_pkg.get_user_person_id(order_info_r.created_by));
      ELSE
        l_creator_mail := l_creator_mail || l_delimiter ||
                          xxhr_util_pkg.get_person_email(xxhr_util_pkg.get_user_person_id(order_info_r.created_by));
      END IF;

    END LOOP;

    -- Set return mail_string
    -- CHG0045128 add below profile check
    if fnd_profile.VALUE('XXOM_SEND_PL_TO_CONTACT_ALWAYS') = 'Y' then
      IF l_mail_str IS NOT NULL AND l_contacts_mail IS NOT NULL THEN
        l_mail_str := l_mail_str || l_delimiter || l_contacts_mail;
      ELSIF l_mail_str IS NULL AND l_contacts_mail IS NOT NULL THEN
        l_mail_str := l_contacts_mail;
      END IF;
    end if;

    IF l_mail_str IS NOT NULL AND l_salesrep_mail IS NOT NULL THEN
      l_mail_str := l_mail_str || l_delimiter || l_salesrep_mail;
    ELSIF l_mail_str IS NULL AND l_salesrep_mail IS NOT NULL THEN
      l_mail_str := l_salesrep_mail;
    END IF;

    IF l_mail_str IS NOT NULL AND l_ship_notif_mail IS NOT NULL THEN
      l_mail_str := l_mail_str || l_delimiter || l_ship_notif_mail;
    ELSIF l_mail_str IS NULL AND l_ship_notif_mail IS NOT NULL THEN
      l_mail_str := l_ship_notif_mail;
    END IF;

    IF l_mail_str IS NOT NULL AND l_creator_mail IS NOT NULL THEN
      l_mail_str := l_mail_str || l_delimiter || l_creator_mail;
    ELSIF l_mail_str IS NULL AND l_creator_mail IS NOT NULL THEN
      l_mail_str := l_creator_mail;
    END IF;

    -- This is a manipulation to make sure there are no duplicate emails
    -- l_delimiter = '[^ ]+' if the delimiter will change need to come here and change too
    SELECT listagg(b.split, '|') within GROUP(ORDER BY 1)
      INTO l_mail_str1
      FROM (SELECT DISTINCT a.split
              FROM (SELECT regexp_substr(l_mail_str, '[^|]+', 1, rownum) split
                      FROM dual
                    CONNECT BY LEVEL <=
                               length(regexp_replace(l_mail_str, '[^|]+')) + 1) a
             WHERE split IS NOT NULL) b;

    RETURN l_mail_str1;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'xxx';
  END get_shipping_mail_list;

  --------------------------------------------------------------------
  --  customization code: CUST 776 CR1215 Customer support SF-OA interfaces
  --  name:               get_tracking_number
  --  create by:          YUVAL TAL
  --  $Revision:          1.0
  --  creation date:      16.1.14
  --  Description:        CR1215 Customer support SF-OA interfaces
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16.1.14       yuval tal       initial build   CR1215 Customer support SF-OA interfaces
  --------------------------------------------------------------------

  FUNCTION get_tracking_number(p_order_line_id NUMBER) RETURN VARCHAR2 IS

    l_trk_number VARCHAR2(500);
  BEGIN
    SELECT listagg(tracking_number, ', ') within GROUP(ORDER BY 1)
      INTO l_trk_number
      FROM (SELECT DISTINCT nvl(wnd.attribute1, wnd.waybill) tracking_number

              FROM oe_order_lines_all       ola,
                   wsh_new_deliveries       wnd,
                   wsh_delivery_assignments wda,
                   wsh_delivery_details     wdd
             WHERE wnd.delivery_id = wda.delivery_id
               AND wda.delivery_detail_id = wdd.delivery_detail_id
               AND wdd.source_line_id = ola.line_id
               AND wnd.status_code = 'CL'
               AND ola.line_id = p_order_line_id);

    RETURN l_trk_number;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

END xxwsh_general_pkg;
/
