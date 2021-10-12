CREATE OR REPLACE VIEW apps.xxap_vendor_activity_review_v AS 
WITH
--------------------------------------------------------------------------------
--  Name:               XXAP_VENDOR_ACTIVITY_REVIEW_V
--  Created By:         Hubert, Eric
--  Revision:           1.0
--  Creation Date:      01-May-2021
--  Description:
--        Lists all active vendors and several fields that give an indication of how "active"
--        a vendor is.  This view itself does not make a determination as to whether a vendor is
--        considered active or not, it just provides the information upOn which such a decision
--        can be made.  The concurrent program XX_AP_INACTIVATE_VENDORS is a concurrent program
--        that does consume this view for the purposes of inactivating vendors that lack "recent"
--        activity.  Because this program is dependent upon this view, the numbering/labeling of
--        the business rules in the program are aligned with comments and column names in this view,
--        for traceability.
--------------------------------------------------------------------------------
--  Ver   Date            Name            Description
--  1.0   01-May-2021     Hubert, Eric    CHG0049706: initial build
--------------------------------------------------------------------------------
/* Define multiple subqueries which will be joined later in the query. */

/* Support Rule #0 by listing all active vendors, to which other subqueries will be joined. */
sq_active_vendors AS (
    --List of vendors
    SELECT 
        ap.segment1 supplier_number--Labeled as "Supplier Number" on Suppliers form
        ,ap.vendor_id
        ,ap.vendor_name--Labeled as "Supplier Name" on Suppliers form
        ,ap.creation_date vendor_creation_date
        ,ap.start_date_active vendor_start_date_active
        ,ap.end_date_active vendor_end_date_active
        ,ap.enabled_flag
        ,ap.party_id
        ,ap.attribute11 inactivation_exclusion_dff
        ,hp.object_version_number party_object_version_number
    FROM ap_suppliers ap --Created for R12 (po_vendors is a view)
    INNER JOIN hz_parties hp ON (hp.party_id = ap.party_id)
    WHERE 1=1
    ORDER BY ap.vendor_name
),
/* Supports Rule #1 by indicating if a vendor has sites just in one operating unit. */
sq_vendor_site_orgs AS (
    SELECT
        vendor_id
        ,COUNT(DISTINCT org_id) count_distinct_org_id
        ,LISTAGG(org_id, ',') WITHIN GROUP(ORDER BY org_id) org_id_list
        ,COUNT(DISTINCT vendor_site_code) count_distinct_site_code
        ,MAX(vendor_site_code) example_vendor_site_code
        ,(
            CASE WHEN COUNT(DISTINCT org_id) = 1 THEN
                MIN(org_id)
            ELSE
                NULL
            END
        ) sole_org_id
    FROM
    (
        SELECT
            pv.vendor_id
            ,pvsa.vendor_site_id
            ,pvsa.vendor_site_code
            ,pvsa.org_id
        FROM po_vendors pv
        LEFT JOIN po_vendor_sites_all pvsa ON (pv.vendor_id = pvsa.vendor_id)
    )
    GROUP BY
        vendor_id
),
/* Supports Rule #2 by looking for POs that are available to be received and considering those "open". */
sq_po_lines_open_us AS (
    SELECT 	
        rersv.org_id
        ,rersv.to_organization_id
        ,rersv.order_type
        ,rersv.po_header_id
        ,rersv.po_line_id
        ,rersv.ship_to_location_id
        ,rersv.vendor_id
        ,rersv.vendor_site_id
        ,rersv.closed_code
        ,rersv.po_number
        ,rersv.po_line_number
        ,rersv.po_release_number
        ,rersv.po_shipment_number
        ,rersv.ship_to_location
        ,rersv.item_description
        ,rersv.ordered_qty
        ,rersv.unit_price
        ,rersv.need_by_date
        ,'Y' has_open_po_flag  --All rows returned by this subquery are for POs that are considered Open, so we flag every row with 'Y'.
    FROM rcv_enter_receipts_supplier_v rersv
    WHERE
        rersv.source_type_code IN('VENDOR','ASN')
        AND NVL(rersv.closed_code, 'OPEN') NOT IN ('CLOSED','CLOSED FOR RECEIVING')
),
/* Supports Rule #2 by sumamrizing aggregating the prior subquery to one row per vendor. */
sq_open_po_vendor_summary AS (
    SELECT
        vendor_id
        ,has_open_po_flag
        ,COUNT(*) count_po_lines
        ,MAX(po_number) example_open_po
    FROM sq_po_lines_open_us
    GROUP BY
        vendor_id
        ,has_open_po_flag
),
/* Supports Rule #Rule 3 by getting information about the most recent PO created for a vendor. */
sq_last_vendor_pos AS (
    SELECT
        vendor_id
        ,last_po_number
        ,last_po_creation_date
        ,last_po_org_id
        ,last_po_shipment_date
        ,last_po_buyer
        ,last_po_is_direct_flag
    FROM
        (
            /* For each vendor, get attributes of the "last" PO based on its creation date. */
            SELECT
                pha.vendor_id
                ,pha.agent_id
                ,LAST_VALUE(pha.segment1)
                    OVER (PARTITION BY pha.vendor_id ORDER BY pha.creation_date
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_po_number
                ,LAST_VALUE(pha.creation_date)
                    OVER (PARTITION BY pha.vendor_id ORDER BY pha.creation_date
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_po_creation_date
                ,LAST_VALUE(pha.org_id)
                    OVER (PARTITION BY pha.vendor_id ORDER BY pha.creation_date
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_po_org_id
                ,LAST_VALUE(poa.buyer_name)
                    OVER (PARTITION BY pha.vendor_id ORDER BY pha.creation_date
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_po_buyer
                ,LAST_VALUE(plla.creation_date)
                    OVER (PARTITION BY pha.vendor_id ORDER BY plla.creation_date
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_po_shipment_date
                ,LAST_VALUE(pli.direct_po_flag) --If item is associated with PO line then assume that it is "direct".
                    OVER (PARTITION BY pha.vendor_id ORDER BY plla.creation_date
                    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_po_is_direct_flag
            FROM po_headers_all pha
                INNER JOIN po_lines_all pla ON (pla.po_header_id = pha.po_header_id)
                INNER JOIN po_line_locations_all plla ON (plla.po_header_id = pla.po_header_id AND plla.po_line_id = pla.po_line_id)
                LEFT JOIN  mtl_system_items_b msi ON (msi.inventory_item_id = pla.item_id AND msi.organization_id = plla.ship_to_organization_id)
                /* Get buyer name*/
                LEFT JOIN (
                    SELECT
                        pa.agent_id
                        ,per.full_name buyer_name
                        ,pa.start_date_active buyer_start_date
                        ,pa.end_date_active buyer_end_date
                        ,per.employee_number
                    FROM po_agents pa,
                         per_all_people_f per
                    WHERE 1=1
                        AND pa.agent_id = per.person_id
                        AND SYSDATE between per.effective_start_date AND per.effective_end_date
                ) poa ON (poa.agent_id = pha.agent_id)
                /* Check if PO has lines with items */
                LEFT JOIN (
                    SELECT
                        po_header_id
                        ,(CASE WHEN MAX(item_id) IS NOT NULL THEN
                            'Y'
                        ELSE
                            'N'
                        END) direct_po_flag
                    FROM po_lines_all
                    GROUP BY po_header_id
                )  pli ON (pli.po_header_id = pha.po_header_id)
            WHERE 1=1
                AND pha.type_lookup_code IN ('STANDARD','BLANKET') --Exclude quotations
        )
    GROUP BY 
        vendor_id
        ,last_po_number
        ,last_po_creation_date
        ,last_po_org_id
        ,last_po_shipment_date
        ,last_po_buyer
        ,last_po_is_direct_flag
),
/* Supports Rule #4 by getting information about paid invoices for a vendor */
sq_invoices_paid_recent AS (
    SELECT apsa.due_date
        ,pv.vendor_name
        ,pv.vendor_id
        ,aia.invoice_num
        ,aia.invoice_id
        ,aia.invoice_date
        ,aia.payment_status_flag
        ,aia.cancelled_date
        ,aia.invoice_amount
        ,aia.amount_paid
        ,apsa.amount_remaining
        ,SUM(aia.invoice_amount) sum_invoice_amount
        ,SUM(apsa.amount_remaining) sum_amount_remaning
        /* Return the most-recent invoice for the vendor, as determined by the Invoice Date*/
        ,FIRST_value(aia.invoice_num) OVER (PARTITION BY pv.vendor_id ORDER BY aia.invoice_date DESC) last_paid_invoice_number
        /* Return the most-recent Invoice Date of paid invoices for the vendor*/
        ,FIRST_value(aia.invoice_date) OVER (PARTITION BY pv.vendor_id ORDER BY aia.invoice_date DESC) last_paid_invoice_date--this could have been accomplished with an aggregate function but used analytic for consistency with the field above.
    FROM ap_payment_schedules_all apsa
    INNER JOIN ap_invoices_all aia ON (aia.invoice_id = apsa.invoice_id)
    INNER JOIN po_vendors pv ON (aia.vendor_id = pv.vendor_id)
    INNER JOIN po_vendor_sites_all pvsa ON (aia.vendor_site_id = pvsa.vendor_site_id)
    GROUP BY pv.vendor_name
        ,pv.vendor_id
        ,aia.invoice_num
        ,aia.invoice_id
        ,aia.invoice_date
        ,aia.payment_status_flag
        ,apsa.due_date
        ,aia.invoice_amount
        ,aia.amount_paid
        ,apsa.amount_remaining
        ,aia.cancelled_date
    HAVING (
            aia.payment_status_flag = 'Y' --'Y': Fully Paid, 'P': Partially Paid , 'N': Not Paid
            )
        AND aia.cancelled_date IS NULL
    ORDER BY aia.invoice_date DESC
        ,pv.vendor_name
        ,aia.invoice_num
),
/* Supports Rule #4 by getting information about the most recently-paid invoice by vendor. */
sq_paid_inv_vendor_summary AS (
    SELECT
        vendor_id
        ,COUNT(*) count_invoice_lines
        ,last_paid_invoice_number
        ,last_paid_invoice_date
    FROM sq_invoices_paid_recent
    GROUP BY
        vendor_id
        ,last_paid_invoice_number
        ,last_paid_invoice_date
),
/* Supports Rule #5 by listing unpaid invoices. */
sq_invoices_unpaid AS (
    SELECT
        apsa.due_date
        ,pv.vendor_name
        ,pv.vendor_id
        ,aia.invoice_num
        ,aia.invoice_id
        ,aia.invoice_date
        ,aia.payment_status_flag
        ,aia.cancelled_date
        ,aia.invoice_amount
        ,aia.amount_paid
        ,apsa.amount_remaining
        ,SUM(aia.invoice_amount) sum_invoice_amount
        ,SUM(apsa.amount_remaining) sum_amount_remaning
        ,'Y' has_unpaid_invoice_flag
    FROM ap_payment_schedules_all apsa
    INNER JOIN ap_invoices_all aia ON (aia.invoice_id = apsa.invoice_id)
    INNER JOIN po_vendors pv ON (aia.vendor_id = pv.vendor_id)
    INNER JOIN po_vendor_sites_all pvsa ON (aia.vendor_site_id = pvsa.vendor_site_id)
    GROUP BY pv.vendor_name
        ,pv.vendor_id
        ,aia.invoice_num
        ,aia.invoice_id
        ,aia.invoice_date
        ,aia.payment_status_flag
        ,apsa.due_date
        ,aia.invoice_amount
        ,aia.amount_paid
        ,apsa.amount_remaining
        ,aia.cancelled_date
    HAVING (
            SUM(apsa.amount_remaining) <> 0
            OR aia.payment_status_flag <> 'Y' --'Y': Fully Paid, 'P': Partially Paid , 'N': Not Paid
            )
        AND aia.cancelled_date IS NULL
    ORDER BY aia.invoice_date DESC
        ,pv.vendor_name
        ,aia.invoice_num
),
/* Supports Rule #5 by sumamrizing unpaid invoices by vendor. */
sq_unpaid_inv_vendor_summary AS (
    SELECT
        vendor_id
        ,has_unpaid_invoice_flag
        ,COUNT(*) count_invoice_lines
        ,MAX(invoice_num) example_unpaid_invoice
    FROM sq_invoices_unpaid
    GROUP BY
        vendor_id
        ,has_unpaid_invoice_flag
),
/* Supports Rule #6 by indicating if the vendor is linked to an HR person record. */
sq_hr_person_vendors  AS (
    /* Flag vendors that are a Person */
    SELECT 
        pv.segment1 supplier_number
        ,pv.vendor_id
        ,pv.vendor_name
        ,pv.party_id
        ,pv.party_number
        ,hp.party_name
        ,hp.party_type example_party_type
        ,(
        CASE WHEN hp.party_type = 'PERSON' THEN
            'Y'
        ELSE
            'N'
        END
        ) is_person_flag
    FROM po_vendors pv
    LEFT JOIN hz_parties hp ON (pv.party_id = hp.party_id)
),
/* Bring everything together by listingall active vendors and joining teh various subqueries to the vendors. */
sq_summary AS (
    SELECT
        sv.supplier_number
        ,sv.vendor_id
        ,sv.vendor_name
        ,sv.party_id
        ,sv.party_object_version_number
        ,sv.vendor_start_date_active            r0_vendor_start_date_active
        ,sv.vendor_end_date_active              r0_vendor_end_date_active
        ,sv.enabled_flag                        r0_vendor_enabled_flag
        ,svso.sole_org_id                       r1_sole_org_id
        ,hru.name                               r1_sole_org_name
        ,svso.count_distinct_org_id             r1_count_distinct_org_id
        ,svso.example_vendor_site_code          r1_example_vendor_site_code
        ,NVL(sopvs.has_open_po_flag,'N')        r2_has_open_po_flag
        ,sopvs.example_open_po                  r2_example_open_po
        ,slvp.last_po_number                    r3_last_po_number
        ,slvp.last_po_creation_date             r3_last_po_creation_date
        ,slvp.last_po_buyer                     r3_last_po_buyer
        ,slvp.last_po_is_direct_flag            r3_last_po_is_direct_flag
        ,slvp.last_po_shipment_date             r3_last_po_shipment_date
        ,spivs.last_paid_invoice_number         r4_last_paid_invoice_number
        ,spivs.last_paid_invoice_date           r4_last_paid_invoice_date
        ,NVL(suivs.has_unpaid_invoice_flag,'N') r5_has_unpaid_invoice_flag
        ,suivs.example_unpaid_invoice           r5_example_unpaid_invoice
        ,NVL(shpv.is_person_flag,'N')           r6_is_person_flag
        ,shpv.example_party_type                r6_example_party_type
        ,NVL(sv.inactivation_exclusion_dff,'N') r7_explicit_exclusion_flag
    FROM 
    /* All suppliers*/
    sq_active_vendors sv
    /* Rule 1: US-only suppliers*/
    LEFT JOIN sq_vendor_site_orgs svso ON (sv.vendor_id = svso.vendor_id)
    LEFT JOIN hr_organization_units hru ON (hru.organization_id = svso.sole_org_id)
    /* Rule 2: Open POs by supplier*/
    LEFT JOIN sq_open_po_vendor_summary sopvs ON (sv.vendor_id = sopvs.vendor_id)
    /* Rule 3: Recent POs by supplier*/
    LEFT JOIN sq_last_vendor_pos slvp ON (sv.vendor_id = slvp.vendor_id)
    /* Rule 4: Recent paid invoices by supplier*/
    LEFT JOIN sq_paid_inv_vendor_summary spivs ON (sv.vendor_id = spivs.vendor_id)
    /* Rule 5: Unpaid invoices by supplier*/
    LEFT JOIN sq_unpaid_inv_vendor_summary suivs ON (sv.vendor_id = suivs.vendor_id)
    /* Rule 6*/
    LEFT JOIN sq_hr_person_vendors shpv ON (sv.vendor_id = shpv.vendor_id)
)
/* Return the final results*/
SELECT
    /* Need CAST to allow a a global temp table to be constructed based on this view.  A procedure will populate a value in the temp table. */
    CAST(NULL AS VARCHAR2(30))      proposed_action
    ,CAST(NULL AS VARCHAR2(1))      action_executed_flag
    ,CAST(NULL AS VARCHAR2(1000))   message
    
    /* Core fields */
    ,ss.*
	
    /* Query metadata */
    ,SYS_CONTEXT('USERENV', 'DB_NAME') db_name
	,SYSDATE query_date
FROM sq_summary ss
/