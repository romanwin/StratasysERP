CREATE OR REPLACE PACKAGE BODY PO_CHORD_WF6 AS
/* $Header: POXWCO6B.pls 120.21.12000000.2 2008/02/21 22:04:41 jburugul ship $ */

-- Read the profile option that enables/disables the debug log
g_po_wf_debug VARCHAR2(1) := NVL(FND_PROFILE.VALUE('PO_SET_DEBUG_WORKFLOW_ON'),'N');

/**************************************************************************
 * The following procedure is used to retrieve
 * the tolerances from workflow attributes
 **************************************************************************/

PROCEDURE get_tolerances_from_wf(
  itemtype         IN VARCHAR2,
        itemkey          IN VARCHAR2,
        doc_type         IN VARCHAR2,
  x_tolerance_control IN OUT NOCOPY t_tolerance_control_type);


/**************************************************************************
 *  The following procedures determine what reapproval rules will be applied
 *  by the workflow system. Please be careful when modifying this
 *  package.
 *  These rules determine whether the document is routed through the full
 *  approval process.
 *
 *  There are 6 procedures in this package, each for a different
 *  document type.
 *
 *  1. standard_po_reapproval    : Standard Purchase Order
 *  2. planned_po_reapproval    : Planned Purchase Order
 *  3. blanket_po_reapproval    : Blanket Purchase Agreement
 *  4. contract_po_reapproval    : Contract Purchase Agreement
 *  5. blanket_release_reapproval  : Blanket Release
 *  6. scheduled_release_reapproval  : Scheduled Release
 *
 * How to customerize this package:
 * (1) Backup this file
 * (2) Do not change procedure definition.
 * (3) Only modify the IF statement logic.
 *
 * The workflow system compares the current and previous version of
 * the document and reports all modifications.
 * For example, Standard Purchase Order has 4 sections, namely
 * header, lines, shipments, and distributions.
 * The modifications are thus stored in the following data structure:
 * x_header_control, x_lines_control, x_shipments_control and
 * x_dist_control.
 * ( See POXWCO1S.pls, POXWCO2S.pls, POXWCO3S.pls POXWCO4S.pls
 *   for definition )
 *
 * The data structure x_tolerance_control holds the default tolerance
 * percentage in the workflow definition. They are stored as
 * item attributes in the workflow.
 *
 * Two types of value are stored in the data structure:
 * (1) 'Y' or 'N' type    (name same as table column name)
 * (2) Numbers in Percentage  (name with '_change')
 *
 **************************************************************************
 */

/**************************************************************************
 *                    *
 *   Reapproval Rules for Standard Purchase Order         *
 *                     *
 **************************************************************************/

PROCEDURE standard_po_reapproval(itemtype IN VARCHAR2,
           itemkey  IN VARCHAR2,
           actid    IN NUMBER,
           FUNCMODE IN VARCHAR2,
           RESULT   OUT NOCOPY VARCHAR2)
IS
  x_header_control   t_header_control_type;
  x_lines_control   t_lines_control_type;
  x_shipments_control   t_shipments_control_type;
  x_dist_control     t_dist_control_type;
  x_tolerance_control  t_tolerance_control_type;
  x_result    VARCHAR2(1);
  l_retroactive_change     VARCHAR2(1) := 'N'; --  RETROACTIVE FPI
        l_autoapprove_retro     VARCHAR2(1) := 'N'; --  RETROACTIVE FPI
        l_actionoriginated_from   varchar2(30);     --Bug5697556
  -- <Complex Work R12 Start>
  l_is_complex_work_po   BOOLEAN := FALSE;
  l_document_type        PO_DOCUMENT_TYPES_ALL.document_type_code%TYPE;
  l_document_subtype     PO_DOCUMENT_TYPES_ALL.document_subtype%TYPE;
  l_po_header_id         PO_HEADERS_ALL.po_header_id%TYPE;
  -- <Complex Work R12 End>

BEGIN

  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: standard_po_reapproval ***');
  END IF;

  IF funcmode <> 'RUN' THEN
    result := 'COMPLETE';
    return;
  END IF;

  -- <Complex Work R12 Start>

  l_document_type := PO_WF_UTIL_PKG.GetItemAttrText(
                       itemtype => itemtype
                     , itemkey  => itemkey
                     , aname    => 'DOCUMENT_TYPE'
                     );

  l_document_subtype := PO_WF_UTIL_PKG.GetItemAttrText(
                       itemtype => itemtype
                     , itemkey  => itemkey
                     , aname    => 'DOCUMENT_SUBTYPE'
                     );

  IF ((l_document_type = 'PO') AND (l_document_subtype = 'STANDARD')) THEN

    l_po_header_id := PO_WF_UTIL_PKG.GetItemAttrText(
                         itemtype => itemtype
                       , itemkey  => itemkey
                       , aname    => 'DOCUMENT_ID'
                       );

    l_is_complex_work_po := PO_COMPLEX_WORK_PVT.is_complex_work_po(p_po_header_id => l_po_header_id);

  END IF;

  IF (g_po_wf_debug = 'Y') THEN
    if l_is_complex_work_po then
             PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
           'l_is_complex_work_po - Yes');
    else
             PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
           'l_is_complex_work_po - No');
    end if;
  END IF;

  -- <Complex Work R12 End>


  /* RETROACTIVE FPI START.
   * Get the value of the attribute CO_H_RETROACTIVE_APPROVAL if
   * this approval is initiated due to the retroactive change in
   * the release. If this value is N, then we send the document
   * through Change Order Workflow.
  */
  l_retroactive_change := PO_WF_UTIL_PKG.GetItemAttrText
          (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'CO_R_RETRO_CHANGE');

  If (l_retroactive_change = 'Y') then

     l_autoapprove_retro := PO_WF_UTIL_PKG.GetItemAttrText
          (itemtype => itemtype,
           itemkey  => itemkey,
           aname    => 'CO_H_RETROACTIVE_AUTOAPPROVAL');


        /*Bug5697556 Get the wf attribute value 'INTERFACE_SOURCE_CODE'.This would be
              the value which indicates where the approval workflow is called from.If
              approval is called from "Retroactive" concurrent program only then check
              for the "automatic approval" wf attribute */

            l_actionoriginated_from := PO_WF_UTIL_PKG.GetItemAttrText
                                      (itemtype => itemtype,
                                       itemkey  => itemkey,
                                       aname    => 'INTERFACE_SOURCE_CODE');

                if (l_autoapprove_retro = 'Y') AND (l_actionoriginated_from = 'RETRO') THEN


      IF (g_po_wf_debug = 'Y') THEN
         PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '$$$$$$$ Document requires full approval =  N $$$$$$');
      END IF;

      RESULT := 'N';

      return;
    end if; /*l_autoapprove_retro = 'Y' */

  end if; /* l_retroactive_change = 'Y' */

  /* RETROACTIVE FPI END */
    po_chord_wf1.get_wf_header_control(itemtype, itemkey, x_header_control);
    po_chord_wf2.get_wf_lines_control(itemtype, itemkey, x_lines_control);
    po_chord_wf3.get_wf_shipments_control(itemtype, itemkey, x_shipments_control);
    po_chord_wf4.get_wf_dist_control(itemtype, itemkey, x_dist_control);
    po_chord_wf6.get_default_tolerance(itemtype, itemkey, x_tolerance_control, 'STANDARD_PO'); --<R12 Requester Driven Procurement>

    /***************************************************************
     * Check if the modifications to the document header requires
     * full reapproval.
     *
     *   Legends:
     *
     *   'Y' means modified
     *   'N' means not modified
     *   Numbers are in Percentage
     *
     ***************************************************************/

        -- bug 4624025: vendor site id should be considered for the reapproval,
        -- rules, and if the same has changed the document should be routed
        -- through the approval hierarchy

    IF   x_header_control.agent_id      ='Y'
                  OR    x_header_control.vendor_site_id                 ='Y'
      OR  x_header_control.vendor_contact_id    ='Y'
      OR  x_header_control.confirming_order_flag    ='Y'
      --OR  x_header_control.ship_to_location_id    ='Y'       -- Dipta Change - CHG0035380
      --OR  x_header_control.bill_to_location_id    ='Y'       -- Dipta Change - CHG0035380
      --OR  x_header_control.terms_id      ='Y'                -- Dipta Change - CHG0035380
      --OR  x_header_control.ship_via_lookup_code    ='Y'      -- Dipta Change - CHG0035380
      --OR  x_header_control.fob_lookup_code    ='Y'           -- Dipta Change - CHG0035380
      OR  x_header_control.freight_terms_lookup_code  ='Y'
      OR  x_header_control.note_to_vendor      ='Y'
      OR  x_header_control.acceptance_required_flag   ='Y'
      OR  x_header_control.acceptance_due_date    ='Y'
      OR  (x_header_control.po_total_change >
       nvl(x_tolerance_control.h_po_total_t,0))
    THEN
      IF (g_po_wf_debug = 'Y') THEN
         PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
           '########## header_require_reapproval result: Y');
      END IF;
      x_result:='Y';
    ELSE
      IF (g_po_wf_debug = 'Y') THEN
         PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
           '########## header_require_reapproval result: N');
      END IF;
      x_result:='N';
    END IF;

  IF x_result <> 'Y' THEN
         IF    x_lines_control.line_num    ='Y'
    OR  x_lines_control.item_id      ='Y'
    OR  x_lines_control.item_revision    ='Y'
    OR  x_lines_control.item_description  ='Y'
    OR  x_lines_control.category_id    ='Y'
    OR  x_lines_control.unit_meas_lookup_code  ='Y'
    --OR  x_lines_control.from_header_id    ='Y'     -- 11 AUG 2016 L.Sarangi CHG0039038
    --OR  x_lines_control.from_line_id    ='Y'       -- 11 AUG 2016 L.Sarangi CHG0039038
    OR  x_lines_control.hazard_class_id    ='Y'
    OR  x_lines_control.contract_num    ='Y'
    OR  x_lines_control.vendor_product_num   ='Y'
    OR  x_lines_control.un_number_id     ='Y'
    OR  x_lines_control.price_type_lookup_code   ='Y'
    OR  x_lines_control.note_to_vendor    ='Y'
    OR  (x_lines_control.start_date_change >
          nvl(x_tolerance_control.l_start_date_t,0)) --<R12 Requester Driven Procurement>
    OR  (x_lines_control.end_date    ='Y'
                AND (x_lines_control.end_date_change is null
      OR (x_lines_control.end_date_change >
          nvl(x_tolerance_control.l_end_date_t,0))) ) --<R12 Requester Driven Procurement>
    -- <Complex Work R12 Start>
    OR  x_lines_control.retainage_rate = 'Y'
    OR  x_lines_control.max_retainage_amount = 'Y'
    OR  x_lines_control.progress_payment_rate = 'Y'
    OR  x_lines_control.recoupment_rate = 'Y'
    OR  x_lines_control.advance_amount = 'Y'
    -- <Complex Work R12 End>
    OR  (x_lines_control.quantity_change >
     nvl(x_tolerance_control.l_quantity_t,0))
     OR  (x_lines_control.unit_price_change >
     nvl(x_tolerance_control.l_unit_price_t,0))
     OR  (x_lines_control.amount_change >
     nvl(x_tolerance_control.l_amount_t,0))   --<R12 Requester Driven Procurement>
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## lines_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## lines_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

  IF x_result <> 'Y' THEN
         IF   x_shipments_control.shipment_num    ='Y'
    --OR  x_shipments_control.ship_to_location_id    ='Y'   -- 11 AUG 2016 L.Sarangi CHG0039038
    OR  (x_shipments_control.last_accept_date    ='Y'
                AND x_shipments_control.days_late_rcpt_allowed  ='Y')   -- ECO 5080252
    OR  (x_shipments_control.promised_date    ='Y'
                AND (x_shipments_control.promised_date_change is null   -- Bug 5123672
      OR (x_shipments_control.promised_date_change >
          nvl(x_tolerance_control.s_promised_date_t,0))) )  --<R12 Requester Driven Procurement>
    OR  (x_shipments_control.need_by_date    ='Y'
                AND (x_shipments_control.need_by_date_change is null    -- Bug 5123672
     OR (x_shipments_control.need_by_date_change >
           nvl(x_tolerance_control.s_need_by_date_t,0))) )  --<R12 Requester Driven Procurement>

    -- <Complex Work R12 Start>: Use different tolerances for complex work POs
    OR  x_shipments_control.payment_type = 'Y'
    OR  x_shipments_control.description = 'Y'
    OR  x_shipments_control.work_approver_id = 'Y'
    --OR  ((NOT l_is_complex_work_po) AND                                                      -- Dipta Change - CHG0035380
    --      (x_shipments_control.quantity_change > nvl(x_tolerance_control.s_quantity_t,0)))   -- Dipta Change - CHG0035380
    OR ((l_is_complex_work_po) AND
          (x_shipments_control.quantity_change > nvl(x_tolerance_control.p_quantity_t,0)))
    --<R12 Requester Driven Procurement>
    --OR  ((NOT l_is_complex_work_po) AND                                                      -- Dipta Change - CHG0035380
    --      (x_shipments_control.amount_change > nvl(x_tolerance_control.s_amount_t,0)))       -- Dipta Change - CHG0035380
    OR ((l_is_complex_work_po) AND
          (x_shipments_control.amount_change > nvl(x_tolerance_control.p_amount_t,0)))
    OR ((l_is_complex_work_po) AND
          (x_shipments_control.price_override_change > nvl(x_tolerance_control.p_price_override_t,0)))
    -- <Complex Work R12 End>
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## shipments_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## shipments_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

/* Bug 1081717: kagarwal
** Added the Check for change in Charge Account for Distributions
** x_dist_control.code_combination_id = 'Y'
*/
/* Bug 2747157: kagarwal
** Added the Check for change in Gl Date for Distributions
** x_dist_control.gl_encumbered_date = 'Y' .
*/

  IF x_result <> 'Y' THEN
         IF   x_dist_control.distribution_num    ='Y'
          OR  x_dist_control.deliver_to_person_id  ='Y'
          OR    x_dist_control.code_combination_id = 'Y'
          OR    x_dist_control.gl_encumbered_date = 'Y'
    OR  (x_dist_control.quantity_ordered_change  >
     nvl(x_tolerance_control.d_quantity_ordered_t,0))
    OR  (x_dist_control.amount_ordered_change  >
      nvl(x_tolerance_control.d_amount_ordered_t,0)) --<R12 Requester Driven Procurement>
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## dist_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## dist_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

   --<CONTERMS FPJ START>
   IF x_result <> 'Y' THEN
       -- Check if contract terms were changed
       x_result := PO_CONTERMS_WF_PVT.contract_terms_changed(
                                      itemtype => itemtype,
                                      itemkey  => itemkey);
   END IF;
   --<CONTERMS FPJ END>
  IF x_result = 'Y' THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '$$$$$$$ Document requires full approval =  Y $$$$$$');
    END IF;
    RESULT := 'Y';
  ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '$$$$$$$ Document requires full approval =  N $$$$$$');
    END IF;
    RESULT := 'N';
  END IF;

  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** Finish: standard_po_reapproval ***');
  END IF;

  return;

EXCEPTION

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.stanard_po_reapproval', 'others');
  RAISE;

END;

/**************************************************************************
 *                    *
 *   Reapproval Rules for Planned Purchase Order         *
 *                     *
 **************************************************************************/

PROCEDURE planned_po_reapproval(itemtype IN VARCHAR2,
           itemkey  IN VARCHAR2,
           actid    IN NUMBER,
           FUNCMODE IN VARCHAR2,
           RESULT   OUT NOCOPY VARCHAR2)
IS
  x_header_control   t_header_control_type;
  x_lines_control   t_lines_control_type;
  x_shipments_control   t_shipments_control_type;
  x_dist_control     t_dist_control_type;
  x_tolerance_control  t_tolerance_control_type;
  x_result    VARCHAR2(1);
BEGIN

  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: planned_po_reapproval ***');
  END IF;

  IF funcmode <> 'RUN' THEN
    result := 'COMPLETE';
    return;
  END IF;

  po_chord_wf1.get_wf_header_control(itemtype, itemkey, x_header_control);
  po_chord_wf2.get_wf_lines_control(itemtype, itemkey, x_lines_control);
  po_chord_wf3.get_wf_shipments_control(itemtype, itemkey, x_shipments_control);
  po_chord_wf4.get_wf_dist_control(itemtype, itemkey, x_dist_control);
  po_chord_wf6.get_default_tolerance(itemtype, itemkey, x_tolerance_control, 'PLANNED_PO'); --<R12 Requester Driven Procurement>

  -- 'Y' means modified
  -- Numbers are in Percentage

        -- bug 4624025: vendor site id should be considered for the reapproval,
        -- rules, and if the same has changed the document should be routed
        -- through the approval hierarchy
        IF   x_header_control.agent_id      ='Y'
          OR    x_header_control.vendor_site_id                 ='Y'
    OR  x_header_control.vendor_contact_id    ='Y'
    OR  x_header_control.confirming_order_flag    ='Y'
    OR  x_header_control.ship_to_location_id    ='Y'
    OR  x_header_control.bill_to_location_id    ='Y'
    OR  x_header_control.terms_id      ='Y'
    OR  x_header_control.ship_via_lookup_code    ='Y'
    OR  x_header_control.fob_lookup_code    ='Y'
    OR  x_header_control.freight_terms_lookup_code  ='Y'
    OR  x_header_control.note_to_vendor      ='Y'
    OR  x_header_control.acceptance_required_flag   ='Y'
    OR  x_header_control.acceptance_due_date    ='Y'
    OR  x_header_control.start_date      ='Y'
    OR  x_header_control.end_date      ='Y'
    OR  (x_header_control.amount_limit_change >
           nvl(x_tolerance_control.h_amount_limit_t,0))
  THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## header_require_reapproval result: Y');
    END IF;
    x_result:='Y';
  ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## header_require_reapproval result: N');
    END IF;
    x_result:='N';
  END IF;

  IF x_result <> 'Y' THEN
         IF    x_lines_control.line_num    ='Y'
    OR  x_lines_control.item_id      ='Y'
    OR  x_lines_control.item_revision    ='Y'
    OR  x_lines_control.item_description  ='Y'
    OR  x_lines_control.category_id    ='Y'
    OR  x_lines_control.unit_meas_lookup_code  ='Y'
    OR  x_lines_control.from_header_id    ='Y'
    OR  x_lines_control.from_line_id    ='Y'
    OR  x_lines_control.hazard_class_id    ='Y'
    OR  x_lines_control.contract_num    ='Y'
    OR  x_lines_control.vendor_product_num   ='Y'
    OR  x_lines_control.un_number_id     ='Y'
    OR  x_lines_control.price_type_lookup_code   ='Y'
    OR  x_lines_control.note_to_vendor    ='Y'
    OR  (x_lines_control.quantity_change >
     nvl(x_tolerance_control.l_quantity_t,0))
     OR  (x_lines_control.unit_price_change >
     nvl(x_tolerance_control.l_unit_price_t,0))
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## lines_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## lines_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

  IF x_result <> 'Y' THEN
         IF   x_shipments_control.shipment_num    ='Y'
    OR  x_shipments_control.ship_to_location_id    ='Y'
    OR  (x_shipments_control.last_accept_date    ='Y'
                AND x_shipments_control.days_late_rcpt_allowed  ='Y') -- ECO 5080252
    OR  (x_shipments_control.promised_date    ='Y'
                AND (x_shipments_control.promised_date_change is null
      OR (x_shipments_control.promised_date_change >
          nvl(x_tolerance_control.s_promised_date_t,0))) )  --<R12 Requester Driven Procurement>
    OR  (x_shipments_control.need_by_date    ='Y'
                AND (x_shipments_control.need_by_date_change is null
     OR (x_shipments_control.need_by_date_change >
           nvl(x_tolerance_control.s_need_by_date_t,0))) )  --<R12 Requester Driven Procurement>
    OR  (x_shipments_control.quantity_change >
     nvl(x_tolerance_control.s_quantity_t,0))
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## shipments_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## shipments_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

/* Bug 1081717: kagarwal
** Added the Check for change in Charge Account for Distributions
** x_dist_control.code_combination_id = 'Y'
*/
/* Bug 2747157: kagarwal
** Added the Check for change in Gl Date for Distributions
** x_dist_control.gl_encumbered_date = 'Y' .
*/

  IF x_result <> 'Y' THEN
         IF   x_dist_control.distribution_num    ='Y'
          OR  x_dist_control.deliver_to_person_id  ='Y'
          OR    x_dist_control.code_combination_id = 'Y'
          OR    x_dist_control.gl_encumbered_date = 'Y'
    OR  (x_dist_control.quantity_ordered_change >
     nvl(x_tolerance_control.d_quantity_ordered_t,0))
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## dist_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## dist_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

  IF x_result = 'Y' THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '$$$$$$$ Document requires full approval =  Y $$$$$$');
    END IF;
    RESULT := 'Y';
  ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '$$$$$$$ Document requires full approval =  N $$$$$$');
    END IF;
    RESULT := 'N';
  END IF;


  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** Finish: planned_po_reapproval ***');
  END IF;
  return;

EXCEPTION

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.planned_po_reapproval', 'others');
  RAISE;

END;

/**************************************************************************
 *                    *
 *   Reapproval Rules for Blanket Purchase Agreement        *
 *                     *
 **************************************************************************/

PROCEDURE blanket_po_reapproval(itemtype IN VARCHAR2,
           itemkey  IN VARCHAR2,
           actid    IN NUMBER,
           FUNCMODE IN VARCHAR2,
           RESULT   OUT NOCOPY VARCHAR2)
IS
  x_header_control   t_header_control_type;
  x_lines_control   t_lines_control_type;
        x_shipments_control     t_shipments_control_type;   /* <TIMEPHASED FPI> */
  x_tolerance_control  t_tolerance_control_type;
  x_result    VARCHAR2(1);
        l_ga_org_assign_change  VARCHAR2(1); -- Bug 2911017

BEGIN

  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: blanket_po_reapproval ***');
  END IF;

  IF funcmode <> 'RUN' THEN
    result := 'COMPLETE';
    return;
  END IF;

  po_chord_wf1.get_wf_header_control(itemtype, itemkey, x_header_control);

  po_chord_wf2.get_wf_lines_control(itemtype, itemkey, x_lines_control);

        /* Get all relevant shipments attribute values */
  po_chord_wf3.get_wf_shipments_control(itemtype, itemkey, x_shipments_control);   /* <TIMEPHASED FPI> */

  po_chord_wf6.get_default_tolerance(itemtype, itemkey, x_tolerance_control, 'BLANKET_PO'); --<R12 Requester Driven Procurement>

  -- 'Y' means modified
  -- Numbers are in Percentage

        -- bug 4624025: vendor site id should be considered for the reapproval,
        -- rules, and if the same has changed the document should be routed
        -- through the approval hierarchy

        IF   x_header_control.agent_id      ='Y'
          OR    x_header_control.vendor_site_id                 ='Y'
    OR  x_header_control.vendor_contact_id    ='Y'
    OR  x_header_control.confirming_order_flag    ='Y'
    --OR  x_header_control.ship_to_location_id    ='Y'           -- Dipta Change - CHG0035380
    --OR  x_header_control.bill_to_location_id    ='Y'           -- Dipta Change - CHG0035380
    --OR  x_header_control.terms_id      ='Y'                    -- Dipta Change - CHG0035380
    --OR  x_header_control.ship_via_lookup_code    ='Y'          -- Dipta Change - CHG0035380
    --OR  x_header_control.fob_lookup_code    ='Y'               -- Dipta Change - CHG0035380
    OR  x_header_control.freight_terms_lookup_code  ='Y'
    OR  x_header_control.note_to_vendor      ='Y'
    OR  x_header_control.acceptance_required_flag   ='Y'
    OR  x_header_control.acceptance_due_date    ='Y'
    --OR  x_header_control.start_date      ='Y'                  -- Dipta Change - CHG0035380
    --OR  x_header_control.end_date      ='Y'                    -- Dipta Change - CHG0035380
          OR    x_header_control.amount_limit                   ='Y'   --6616522
    OR  (x_header_control.amount_limit_change >
     nvl(x_tolerance_control.h_amount_limit_t,0))
    OR  (x_header_control.blanket_total_change >
     nvl(x_tolerance_control.h_blanket_total_t,0))  -- Bug 5166228
  THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## header_require_reapproval result: Y');
    END IF;
    x_result:='Y';
  ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## header_require_reapproval result: N');
    END IF;
    x_result:='N';
  END IF;

  IF x_result <> 'Y' THEN
         IF    x_lines_control.line_num    ='Y'
    OR  x_lines_control.item_id      ='Y'
    OR  x_lines_control.item_revision    ='Y'
    OR  x_lines_control.item_description  ='Y'
    OR  x_lines_control.category_id    ='Y'
    OR  x_lines_control.unit_meas_lookup_code  ='Y'
    --OR  x_lines_control.from_header_id    ='Y'    -- 11 AUG 2016 L.Sarangi CHG0039038
    --OR  x_lines_control.from_line_id    ='Y'      -- 11 AUG 2016 L.Sarangi CHG0039038
    OR  x_lines_control.hazard_class_id    ='Y'
    OR  x_lines_control.contract_num    ='Y'
    OR  x_lines_control.vendor_product_num   ='Y'
    OR  x_lines_control.un_number_id     ='Y'
    OR  x_lines_control.price_type_lookup_code   ='Y'
    OR  x_lines_control.note_to_vendor    ='Y'
    OR  (x_lines_control.quantity_change >
     nvl(x_tolerance_control.l_quantity_t,0))
     OR  (x_lines_control.unit_price_change >
      nvl(x_tolerance_control.l_unit_price_t,0))
     OR  (x_lines_control.not_to_exceed_price_change >
     nvl(x_tolerance_control.l_price_limit_t,0))
     OR  (x_lines_control.quantity_committed_change >
     nvl(x_tolerance_control.l_quantity_committed_t,0))
     OR  (x_lines_control.committed_amount_change >
     nvl(x_tolerance_control.l_committed_amount_t,0))
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## lines_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## lines_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

        /* <TIMEPHASED FPI START> */
        /* Bug 2808011. Added price_override to the reapproval rules */
        IF x_result <> 'Y' THEN
           IF     x_shipments_control.shipment_num                ='Y'
         --   OR    x_shipments_control.ship_to_location_id         ='Y'   -- 11 AUG 2016 L.Sarangi CHG0039038
            OR    x_shipments_control.ship_to_organization_id     ='Y'
            OR    x_shipments_control.promised_date               ='Y'
            OR    x_shipments_control.need_by_date                ='Y'
            OR    x_shipments_control.last_accept_date            ='Y'
            OR    x_shipments_control.start_date                  ='Y'
            OR    x_shipments_control.end_date                    ='Y'
            OR   ( x_shipments_control.price_override             ='Y'
                  AND (x_shipments_control.price_override_change >
                   nvl(x_tolerance_control.s_price_override_t,0)))
            OR    (x_shipments_control.quantity_change >
                   nvl(x_tolerance_control.s_quantity_t,0))
           THEN
                IF (g_po_wf_debug = 'Y') THEN
                   PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
                           '########## shipments_require_reapproval result: Y');
                END IF;
                x_result:='Y';
           ELSE
                IF (g_po_wf_debug = 'Y') THEN
                   PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
                           '########## shipments_require_reapproval result: N');
                END IF;
                x_result:='N';
           END IF;
        END IF;
        /* <TIMEPHASED FPI END> */

        -- Bug 2911017 START
        -- Require reapproval if the GA org assignments have been changed.
        IF x_result <> 'Y' THEN
           l_ga_org_assign_change :=
              PO_WF_UTIL_PKG.GetItemAttrText (itemtype , itemkey,'GA_ORG_ASSIGN_CHANGE');
           IF l_ga_org_assign_change = 'Y' THEN
                IF (g_po_wf_debug = 'Y') THEN
                   PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
                           '########## GA org assignments require reapproval result: Y');
                END IF;
                x_result:='Y';
           ELSE
                IF (g_po_wf_debug = 'Y') THEN
                   PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
                           '########## GA org assignments require reapproval result: N');
                END IF;
                x_result:='N';
           END IF;
        END IF;
        -- Bug 2911017 END
    --<CONTERMS FPJ START>
    IF x_result <> 'Y' THEN
       -- Check if contract terms were changed
       x_result := PO_CONTERMS_WF_PVT.contract_terms_changed(
                                      itemtype => itemtype,
                                      itemkey  => itemkey);
    END IF;
    --<CONTERMS FPJ END>
  IF x_result = 'Y' THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '$$$$$$$ Document requires full approval =  Y $$$$$$');
    END IF;
    RESULT := 'Y';
  ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '$$$$$$$ Document requires full approval =  N $$$$$$');
    END IF;
    RESULT := 'N';
  END IF;


  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** Finish: blanket_po_reapproval ***');
  END IF;

END;

/**************************************************************************
 *                    *
 *   Reapproval Rules for Contract Purchase Agreement      *
 *                     *
 **************************************************************************/

PROCEDURE contract_po_reapproval(itemtype IN VARCHAR2,
           itemkey  IN VARCHAR2,
           actid    IN NUMBER,
           FUNCMODE IN VARCHAR2,
           RESULT   OUT NOCOPY VARCHAR2)
IS
  x_header_control   t_header_control_type;
  x_tolerance_control  t_tolerance_control_type;
BEGIN

  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: contract_po_reapproval ***');
  END IF;

  IF funcmode <> 'RUN' THEN
    result := 'COMPLETE';
    return;
  END IF;

  po_chord_wf1.get_wf_header_control(itemtype, itemkey, x_header_control);
  po_chord_wf6.get_default_tolerance(itemtype, itemkey, x_tolerance_control, 'CONTRACT_PO'); --<R12 Requester Driven Procurement>

  -- 'Y' means modified
  -- Numbers are in Percentage


        -- bug 4624025: vendor site id should be considered for the reapproval,
        -- rules, and if the same has changed the document should be routed
        -- through the approval hierarchy

        IF   x_header_control.agent_id      ='Y'
          OR    x_header_control.vendor_site_id                 ='Y'
    OR  x_header_control.vendor_contact_id    ='Y'
    OR  x_header_control.confirming_order_flag    ='Y'
    OR  x_header_control.ship_to_location_id    ='Y'
    OR  x_header_control.bill_to_location_id    ='Y'
    OR  x_header_control.terms_id      ='Y'
    OR  x_header_control.ship_via_lookup_code    ='Y'
    OR  x_header_control.fob_lookup_code    ='Y'
    OR  x_header_control.freight_terms_lookup_code  ='Y'
    OR  x_header_control.note_to_vendor      ='Y'
    OR  x_header_control.acceptance_required_flag   ='Y'
    OR  x_header_control.acceptance_due_date    ='Y'
    OR  x_header_control.start_date      ='Y'
    OR  x_header_control.end_date      ='Y'
    OR  (x_header_control.amount_limit_change >
     nvl(x_tolerance_control.h_amount_limit_t,0))
    OR  (x_header_control.blanket_total_change >
     nvl(x_tolerance_control.h_blanket_total_t,0))
  THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## header_require_reapproval result: Y');
    END IF;
    result:='Y';
  ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## header_require_reapproval result: N');
    END IF;
    result:='N';
  END IF;
    --<CONTERMS FPJ START>
    IF result <> 'Y' THEN
       -- Check if contract terms were changed
       result := PO_CONTERMS_WF_PVT.contract_terms_changed(
                                      itemtype => itemtype,
                                      itemkey  => itemkey);
    END IF;
    -- Adding the following debug stmt to indicate the final result
    -- now that the contract terms are also there
    IF (g_po_wf_debug = 'Y') THEN
            IF result = 'Y' THEN
             PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
               '$$$$$$$ Document requires full approval =  Y $$$$$$');
            ELSE
             PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
               '$$$$$$$ Document requires full approval =  N $$$$$$');
            END IF; -- if result <>'Y'
    END IF; -- if debug 'Y'

   --<CONTERMS FPJ END>

  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** Finish: contract_po_reapproval ***');
  END IF;
  return;

EXCEPTION

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.contract_po_reapproval', 'others');
  RAISE;

END;

/**************************************************************************
 *                    *
 *   Reapproval Rules for Blanket Release           *
 *                     *
 **************************************************************************/

PROCEDURE blanket_release_reapproval(itemtype IN VARCHAR2,
                itemkey  IN VARCHAR2,
                actid    IN NUMBER,
                FUNCMODE IN VARCHAR2,
                RESULT   OUT NOCOPY VARCHAR2)
IS
  x_release_control   t_release_control_type;
  x_shipments_control   t_shipments_control_type;
  x_dist_control     t_dist_control_type;
  x_tolerance_control  t_tolerance_control_type;
  x_result    VARCHAR2(1);
  l_retroactive_change     VARCHAR2(1) := 'N'; --  RETROACTIVE FPI
  l_autoapprove_retro     VARCHAR2(1) := 'N'; --  RETROACTIVE FPI
        l_actionoriginated_from   varchar2(30);     --Bug5697556
BEGIN

  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: blanket_release_reapproval ***');
  END IF;

  IF funcmode <> 'RUN' THEN
    result := 'COMPLETE';
    return;
  END IF;

  /* RETROACTIVE FPI CHANGE START.
   * Get the value of the attribute CO_H_RETROACTIVE_APPROVAL if
   * this approval is initiated due to the retroactive change in
   * the release. If this value is Y, then we send the document
   * through Change Order Workflow.
  */
  l_retroactive_change := PO_WF_UTIL_PKG.GetItemAttrText
          (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'CO_R_RETRO_CHANGE');

  If (l_retroactive_change = 'Y') then

    l_autoapprove_retro := PO_WF_UTIL_PKG.GetItemAttrText
          (itemtype => itemtype,
           itemkey  => itemkey,
           aname    => 'CO_H_RETROACTIVE_AUTOAPPROVAL');
       /*Bug5697556 Get the wf attribute value 'INTERFACE_SOURCE_CODE'.This would be
              the value which indicates where the approval workflow is called from.If
              approval is called from "Retroactive" concurrent program only then check
              for the "automatic approval" wf attribute */

            l_actionoriginated_from := PO_WF_UTIL_PKG.GetItemAttrText
                                      (itemtype => itemtype,
                                       itemkey  => itemkey,
                                       aname    => 'INTERFACE_SOURCE_CODE');

                if (l_autoapprove_retro = 'Y') AND (l_actionoriginated_from = 'RETRO') THEN



      IF (g_po_wf_debug = 'Y') THEN
         PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
           '$$$$$$$ Document requires full approval =  N $$$$$$');
      END IF;
      RESULT := 'N';

      return;
    end if; /* l__autoapprove_retro = 'Y' */

  end if; /* l_retroactive_change = 'Y' */
  /* RETROACTIVE FPI CHANGE END */

    po_chord_wf5.get_wf_release_control(itemtype, itemkey, x_release_control);
    po_chord_wf3.get_wf_shipments_control(itemtype, itemkey, x_shipments_control);
    po_chord_wf4.get_wf_dist_control(itemtype, itemkey, x_dist_control);
    po_chord_wf6.get_default_tolerance(itemtype, itemkey, x_tolerance_control, 'BLANKET_RELEASE'); --<R12 Requester Driven Procurement>

    -- 'Y' means modified
    -- Numbers are in Percentage
    IF   x_release_control.agent_id      ='Y'
      OR  x_release_control.acceptance_required_flag  ='Y'
      OR  x_release_control.acceptance_due_date    ='Y'
      OR  x_release_control.release_num      ='Y'
      OR  x_release_control.release_date      ='Y'
    THEN
      IF (g_po_wf_debug = 'Y') THEN
         PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
          '########## blanket_release_require_reapproval result: Y');
      END IF;
      x_result:='Y';
    ELSE
      IF (g_po_wf_debug = 'Y') THEN
         PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
          '########## blanket_release_require_reapproval result: N');
      END IF;
      x_result:='N';
    END IF;


  IF x_result <> 'Y' THEN
         IF   x_shipments_control.shipment_num    ='Y'
    --OR  x_shipments_control.ship_to_location_id    ='Y'   -- 11 AUG 2016 L.Sarangi CHG0039038
    OR  (x_shipments_control.last_accept_date    ='Y'
                AND x_shipments_control.days_late_rcpt_allowed  ='Y') -- ECO 5080252
    OR  (x_shipments_control.promised_date    ='Y'
                AND (x_shipments_control.promised_date_change is null
      OR (x_shipments_control.promised_date_change >
          nvl(x_tolerance_control.s_promised_date_t,0))) )  --<R12 Requester Driven Procurement>
    OR  (x_shipments_control.need_by_date    ='Y'
                AND (x_shipments_control.need_by_date_change is null
     OR (x_shipments_control.need_by_date_change >
           nvl(x_tolerance_control.s_need_by_date_t,0))) )  --<R12 Requester Driven Procurement>
    OR  (x_shipments_control.quantity_change >
     nvl(x_tolerance_control.s_quantity_t,0))
    OR  (x_shipments_control.price_override_change >
     nvl(x_tolerance_control.s_price_override_t,0))
    OR  (x_shipments_control.amount_change >
    nvl(x_tolerance_control.s_amount_t,0)) --<R12 Requester Driven Procurement>
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## shipments_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## shipments_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

/* Bug 1081717: kagarwal
** Added the Check for change in Charge Account for Distributions
** x_dist_control.code_combination_id = 'Y'
*/
/* Bug 2747157: kagarwal
** Added the Check for change in Gl Date for Distributions
** x_dist_control.gl_encumbered_date = 'Y' .
*/

  IF x_result <> 'Y' THEN
         IF   x_dist_control.distribution_num    ='Y'
          OR  x_dist_control.deliver_to_person_id  ='Y'
          OR    x_dist_control.code_combination_id = 'Y'
          OR    x_dist_control.gl_encumbered_date = 'Y'
    OR  (x_dist_control.quantity_ordered_change >
     nvl(x_tolerance_control.d_quantity_ordered_t,0))
    OR  (x_dist_control.amount_ordered_change >
     nvl(x_tolerance_control.d_amount_ordered_t,0)) --<R12 Requester Driven Procurement>
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## dist_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## dist_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

  IF x_result = 'Y' THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '$$$$$$$ Document requires full approval =  Y $$$$$$');
    END IF;
    RESULT := 'Y';
  ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '$$$$$$$ Document requires full approval =  N $$$$$$');
    END IF;
    RESULT := 'N';
  END IF;


  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** Finish: blanket_release_reapproval ***');
  END IF;
  return;

EXCEPTION

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.release_reapproval', 'others');
  RAISE;

END;

/**************************************************************************
 *                    *
 *   Reapproval Rules for Scheduled Release           *
 *                     *
 **************************************************************************/

PROCEDURE scheduled_release_reapproval(itemtype IN VARCHAR2,
           itemkey  IN VARCHAR2,
           actid    IN NUMBER,
           FUNCMODE IN VARCHAR2,
           RESULT   OUT NOCOPY VARCHAR2)
IS
  x_release_control   t_release_control_type;
  x_shipments_control   t_shipments_control_type;
  x_dist_control     t_dist_control_type;
  x_tolerance_control  t_tolerance_control_type;
  x_result    VARCHAR2(1);
BEGIN

  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: scheduled_release_reapproval ***');
  END IF;

  IF funcmode <> 'RUN' THEN
    result := 'COMPLETE';
    return;
  END IF;

  po_chord_wf5.get_wf_release_control(itemtype, itemkey, x_release_control);
  po_chord_wf3.get_wf_shipments_control(itemtype, itemkey, x_shipments_control);
  po_chord_wf4.get_wf_dist_control(itemtype, itemkey, x_dist_control);
  po_chord_wf6.get_default_tolerance(itemtype, itemkey, x_tolerance_control, 'SCHEDULED_RELEASE'); --<R12 Requester Driven Procurement>

  -- 'Y' means modified
  -- Numbers are in Percentage
        IF   x_release_control.agent_id      ='Y'
    OR  x_release_control.acceptance_required_flag  ='Y'
    OR  x_release_control.acceptance_due_date    ='Y'
    OR  x_release_control.release_num      ='Y'
    OR  x_release_control.release_date      ='Y'
  THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
        '########## scheduled_release_require_reapproval result: Y');
    END IF;
    x_result:='Y';
  ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
        '########## scheduled_release_require_reapproval result: N');
    END IF;
    x_result:='N';
  END IF;


  IF x_result <> 'Y' THEN
         IF   x_shipments_control.shipment_num    ='Y'
    OR  x_shipments_control.ship_to_location_id    ='Y'
    OR  x_shipments_control.cancel_flag      ='Y'
    OR  x_shipments_control.closed_code      ='Y'
    OR  (x_shipments_control.quantity_change >
     nvl(x_tolerance_control.s_quantity_t,0))
    OR  (x_shipments_control.price_override_change >
      nvl(x_tolerance_control.s_price_override_t,0))
    OR  (x_shipments_control.amount_change >
      nvl(x_tolerance_control.s_amount_t,0))
    OR  x_shipments_control.promised_date_change > 0
    OR  x_shipments_control.need_by_date_change > 0
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## shipments_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## shipments_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

/* Bug 1081717: kagarwal
** Added the Check for change in Charge Account for Distributions
** x_dist_control.code_combination_id = 'Y'
*/
/* Bug 2747157: kagarwal
** Added the Check for change in Gl Date for Distributions
** x_dist_control.gl_encumbered_date = 'Y' .
*/

  IF x_result <> 'Y' THEN
         IF   x_dist_control.deliver_to_person_id  ='Y'
          OR    x_dist_control.code_combination_id = 'Y'
          OR    x_dist_control.gl_encumbered_date = 'Y'
    OR  (x_dist_control.quantity_ordered_change >
     nvl(x_tolerance_control.d_quantity_ordered_t,0))
    OR  (x_dist_control.amount_ordered_change >
     nvl(x_tolerance_control.d_amount_ordered_t,0))
   THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## dist_require_reapproval result: Y');
    END IF;
    x_result:='Y';
   ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '########## dist_require_reapproval result: N');
    END IF;
    x_result:='N';
   END IF;
  END IF;

  IF x_result = 'Y' THEN
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '$$$$$$$ Document requires full approval =  Y $$$$$$');
    END IF;
    RESULT := 'Y';
  ELSE
    IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
         '$$$$$$$ Document requires full approval =  N $$$$$$');
    END IF;
    RESULT := 'N';
  END IF;


  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** Finish: scheduled_release_reapproval ***');
  END IF;
  return;

EXCEPTION

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.scheduled_release_reapproval', 'others');
  RAISE;

END;


/**************************************************************************
 *                    *
 *   Get user-defined tolerance percentages from workflow definition   *
 *                     *
 **************************************************************************/

PROCEDURE get_default_tolerance(
  itemtype         IN VARCHAR2,
        itemkey          IN VARCHAR2,
  x_tolerance_control IN OUT NOCOPY t_tolerance_control_type,
  chord_doc_type   IN VARCHAR2 default NULL)
IS
x_org_id number;
x_tol_tab PO_CO_TOLERANCES_GRP.tolerances_tbl_type;
p_api_name varchar2(50):= 'get_default_tolerance';
x_return_status varchar2(1);
x_msg_count NUMBER;
x_msg_data VARCHAR2(2000);
BEGIN

    IF (g_po_wf_debug = 'Y') THEN
      PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: get_default_tolerance ***');
    END IF;

    --<R12 Requester Driven Procurement Start>
    -- set the change order type
    -- prepare tolerances_table with the required list of tolerance names
    if (chord_doc_type = 'STANDARD_PO' OR
        chord_doc_type = 'PLANNED_PO') then

     get_tolerances_from_wf (itemtype, itemkey, 'PO',x_tolerance_control );

    elsif (chord_doc_type = 'BLANKET_PO' OR
           chord_doc_type = 'CONTRACT_PO') then

      get_tolerances_from_wf (itemtype, itemkey, 'PA',x_tolerance_control );

    elsif (chord_doc_type = 'BLANKET_RELEASE' OR
            chord_doc_type = 'SCHEDULED_RELEASE') then

      get_tolerances_from_wf (itemtype, itemkey, 'RELEASE',x_tolerance_control );
    end if;

     --<R12 Requester Driven Procurement End>

     debug_default_tolerance(itemtype, itemkey,x_tolerance_control);

     IF (g_po_wf_debug = 'Y') THEN
       PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** FINISH: get_default_tolerance ***');
     END IF;

EXCEPTION
 WHEN FND_API.g_exc_unexpected_error THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.get_default_tolerance', 'Error in get_tolerances');
  RAISE;

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.get_default_tolerance', 'others');
  RAISE;

END;

/**************************************************************************
 *      ECO : 4716963                    *
 *   Get user-defined tolerance percentages from workflow definition   *
 *                     *
 **************************************************************************/

PROCEDURE get_tolerances_from_wf(
  itemtype         IN VARCHAR2,
        itemkey          IN VARCHAR2,
        doc_type         IN VARCHAR2,
  x_tolerance_control IN OUT NOCOPY t_tolerance_control_type)
IS
BEGIN

    IF (g_po_wf_debug = 'Y') THEN
      PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
          '*** In Procedure: get_tolerances_from_wf ***');
    END IF;

    -- Common attributes
    x_tolerance_control.s_quantity_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_S_QUANTITY_T');

    x_tolerance_control.h_amount_limit_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_H_AMOUNT_LIMIT_T');

    x_tolerance_control.l_unit_price_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_L_UNIT_PRICE_T');

    x_tolerance_control.s_price_override_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_S_PRICE_OVERRIDE_T');

    -- Common attributes between orders and releases
    IF doc_type in ('PO','RELEASE') THEN

       x_tolerance_control.s_need_by_date_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_S_NEED_BY_DATE_T');

       x_tolerance_control.s_promised_date_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_S_PROMISED_DATE_T');

       x_tolerance_control.d_quantity_ordered_t:=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_D_QUANTITY_ORDERED_T');

       x_tolerance_control.d_amount_ordered_t:=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_D_AMOUNT_ORDERED_T');

       x_tolerance_control.s_amount_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_S_AMOUNT_T');
    END IF;

    -- Attributes for orders
    IF doc_type = 'PO' THEN

       x_tolerance_control.h_po_total_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_H_PO_TOTAL_T');

       x_tolerance_control.l_start_date_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_L_START_DATE_T');

       x_tolerance_control.l_end_date_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_L_END_DATE_T');

       x_tolerance_control.l_quantity_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_L_QUANTITY_T');

       x_tolerance_control.l_amount_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_L_AMOUNT_T');

        -- Complex work attributes
       x_tolerance_control.p_quantity_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_P_QUANTITY_T');

       x_tolerance_control.p_price_override_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_P_PRICE_OVERRIDE_T');

       x_tolerance_control.p_amount_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_P_AMOUNT_T');
    END IF;

    -- attributes for agreements
    IF doc_type = 'PA' THEN
       x_tolerance_control.h_blanket_total_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_H_BLANKET_TOTAL_T');

       x_tolerance_control.l_quantity_committed_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_L_QTY_COMMITTED_T');

       x_tolerance_control.l_committed_amount_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_L_COMMITTED_AMT_T');

       x_tolerance_control.l_price_limit_t :=
                PO_WF_UTIL_PKG.GetItemAttrText(itemtype,
                itemkey,
    'CO_L_NOT_TO_EXCEED_PRICE_T');
    END IF;

    debug_default_tolerance(itemtype, itemkey,x_tolerance_control);

    IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** FINISH: get_tolerances_from_wf ***');
    END IF;

EXCEPTION

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.get_tolerances_from_wf', 'others');
  RAISE;

END;

------------------------------------------------------------------------------
--Start of Comments
--Name: set_Wf_Order_Tol
--Pre-reqs:
--  None
--Modifies:
--  None
--Locks:
--  None
--Function:
--   1. Get the auto-approval tolerances for orders
--Parameters:
--IN:
--  itemtype    Workflow item type (Standard WF function parameters)
--  itemkey     Workflow item key (Standard WF function parameters)
--  order_type       Type of order
--End of Comment
-------------------------------------------------------------------------------
PROCEDURE Set_Wf_Order_Tol(
  itemtype         IN VARCHAR2,
        itemkey          IN VARCHAR2,
  order_type  IN VARCHAR2)
IS
x_org_id number;
x_tol_tab PO_CO_TOLERANCES_GRP.tolerances_tbl_type;
x_return_status varchar2(1);
x_msg_count NUMBER;
x_msg_data VARCHAR2(2000);
BEGIN
  --<R12 Requester Driven Procurement Start>
  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: Set_Wf_Order_Tol ***');
  END IF;

  -- Retrieve organization id
  x_org_id:=  PO_WF_UTIL_PKG.GetItemAttrNumber (itemtype  => itemType,
                                          itemkey       => itemkey,
                                          aname         => 'ORG_ID');
  -- Retrieve the tolerances
  PO_CO_TOLERANCES_GRP.GET_TOLERANCES (1.0,
               FND_API.G_TRUE,
               x_org_id,
                        PO_CO_TOLERANCES_GRP.G_CHG_ORDERS,
                        x_tol_tab,
               x_return_status,
                        x_msg_count,
               x_msg_data);

  IF x_return_status <> FND_API.g_ret_sts_success THEN
     RAISE FND_API.g_exc_unexpected_error;
  END IF;

  -- loop through all the tolerances retrieved from the table and set
  -- the wf attributes with table values if values are not null
  for i in 1..x_tol_tab.count
  loop
     -- Assign the values
     -- ECO 4716963: Added a condition for all tolerences to only assign not
     -- null values from the table
     -- common tolerances
     if (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_UNIT_PRICE) then

        if x_tol_tab(i).max_increment is not null then
          PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_L_UNIT_PRICE_T',
                                         x_tol_tab(i).max_increment);
        end if;

     elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_LINE_QTY) then

        if x_tol_tab(i).max_increment is not null then
          PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_L_QUANTITY_T',
                                         x_tol_tab(i).max_increment);
        end if;

     elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_SHIPMENT_QTY) then

        if x_tol_tab(i).max_increment is not null then
     PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_QUANTITY_T',
                                         x_tol_tab(i).max_increment);
        end if;

     elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_DISTRIBUTION_QTY) then

        if x_tol_tab(i).max_increment is not null then
      PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_D_QUANTITY_ORDERED_T',
                                         x_tol_tab(i).max_increment);
        end if;

     elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_NEED_BY_DATE) then

        if x_tol_tab(i).max_increment is not null then
          PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_NEED_BY_DATE_T',
                                         x_tol_tab(i).max_increment);
        end if;

     elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_PROMISED_DATE) then

        if x_tol_tab(i).max_increment is not null then
          PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_PROMISED_DATE_T',
                                         x_tol_tab(i).max_increment);
        end if;

     end if;

     -- Standard PO tolerances
     if (order_type = 'STANDARD') then
       if (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_PO_AMOUNT) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_H_PO_TOTAL_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_LINE_AMOUNT_PERCENT) then

         if x_tol_tab(i).max_increment is not null then
     PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_L_AMOUNT_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_SHIPMENT_AMOUNT_PERCENT) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_AMOUNT_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_DISTRIBUTION_AMOUNT_PERCENT) then

         if x_tol_tab(i).max_increment is not null then
     PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_D_AMOUNT_ORDERED_T',
                                         x_tol_tab(i).max_increment);
         end if;
       -- <Complex Work R12 Start>
       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_PAY_ITEM_AMOUNT_PERCENT) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_P_AMOUNT_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_PAY_ITEM_QTY) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_P_QUANTITY_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_PAY_ITEM_PRICE) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_P_PRICE_OVERRIDE_T',
                                         x_tol_tab(i).max_increment);
         end if;

       -- <Complex Work R12 End>
       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_START_DATE) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_L_START_DATE_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_END_DATE) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_L_END_DATE_T',
                                         x_tol_tab(i).max_increment);
         end if;

       end if;

     else -- Planned PO tolerances
       if (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_HEADER_AMOUNT_LIMIT) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_H_AMOUNT_LIMIT_T',
                                         x_tol_tab(i).max_increment);
         end if;

      end if;

     end if;

  end loop;

  IF (g_po_wf_debug = 'Y') THEN
    PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
    '*** FINISH: get_Default_Order_Tol ***');
  END IF;
  --<R12 Requester Driven Procurement End>
EXCEPTION
 WHEN FND_API.g_exc_unexpected_error THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.set_wf_Order_Tol', 'Error in set_wf_Order_Tol');
  RAISE;

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.Set_Wf_Order_Tol', 'others');
  RAISE;
END Set_Wf_Order_Tol;

------------------------------------------------------------------------------
--Start of Comments
--Name: set_Wf_Agreement_Tol
--Pre-reqs:
--  None
--Modifies:
--  None
--Locks:
--  None
--Function:
--   1. Get the auto-approval tolerances for agreements
--Parameters:
--IN:
--  itemtype    Workflow item type (Standard WF function parameters)
--  itemkey     Workflow item key (Standard WF function parameters)
--  agreement_type       Type of agreement
--End of Comment
-------------------------------------------------------------------------------
PROCEDURE Set_Wf_Agreement_Tol(
  itemtype         IN VARCHAR2,
        itemkey          IN VARCHAR2,
  agreement_type   IN VARCHAR2)
IS
x_org_id number;
x_tol_tab PO_CO_TOLERANCES_GRP.tolerances_tbl_type;
x_return_status varchar2(1);
x_msg_count NUMBER;
x_msg_data VARCHAR2(2000);
BEGIN
  --<R12 Requester Driven Procurement Start>
  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: Set_Wf_Agreement_Tol ***');
  END IF;

  -- Retrieve organization id
  x_org_id:=  PO_WF_UTIL_PKG.GetItemAttrNumber (itemtype  => itemType,
                                          itemkey       => itemkey,
                                          aname         => 'ORG_ID');
  -- Retrieve the tolerances
  PO_CO_TOLERANCES_GRP.GET_TOLERANCES (1.0,
               FND_API.G_TRUE,
               x_org_id,
                        PO_CO_TOLERANCES_GRP.G_CHG_AGREEMENTS,
                        x_tol_tab,
               x_return_status,
                        x_msg_count,
               x_msg_data);

   IF x_return_status <> FND_API.g_ret_sts_success THEN
      RAISE FND_API.g_exc_unexpected_error;
   END IF;

   -- loop through all the tolerances retrieved from the table and
   -- set the attributes from the wf with table values if not null
   for i in 1..x_tol_tab.count
   loop
     -- Assign the values
     -- ECO 4716963: Added a condition for all tolerences to only assign not
     -- null values from the table
     if (agreement_type = 'CONTRACT') then

       if (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_HEADER_AMOUNT_LIMIT) then
         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_H_AMOUNT_LIMIT_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_HEADER_AMOUNT_AGREED) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_H_BLANKET_TOTAL_T',
                                         x_tol_tab(i).max_increment);
         end if;
       end if;

     else -- Blanket PO
       if (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_HEADER_AMOUNT_AGREED) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_H_BLANKET_TOTAL_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_HEADER_AMOUNT_LIMIT) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_H_AMOUNT_LIMIT_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_UNIT_PRICE) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_L_UNIT_PRICE_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_PRICE_LIMIT) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_L_NOT_TO_EXCEED_PRICE_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_LINE_QTY_AGREED) then
         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_L_QTY_COMMITTED_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_LINE_AMOUNT_AGREED) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_L_COMMITTED_AMT_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_PRC_BRK_PRICE) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_PRICE_OVERRIDE_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_PRC_BRK_QTY) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_QUANTITY_T',
                                         x_tol_tab(i).max_increment);
         end if;

       end if;
     end if;
   end loop;

   IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
    '*** FINISH: get_Default_Agreement_Tol ***');
   END IF;
   --<R12 Requester Driven Procurement End>
EXCEPTION
 WHEN FND_API.g_exc_unexpected_error THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.get_Default_Agreement_Tol', 'Error in get_Default_Agreement_Tol');
  RAISE;

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.Set_Wf_Agreement_Tol', 'others');
  RAISE;
END Set_Wf_Agreement_Tol;

------------------------------------------------------------------------------
--Start of Comments
--Name: set_Wf_Release_Tol
--Pre-reqs:
--  None
--Modifies:
--  None
--Locks:
--  None
--Function:
--   1. Get the auto-approval tolerances for releases
--Parameters:
--IN:
--  itemtype    Workflow item type (Standard WF function parameters)
--  itemkey     Workflow item key (Standard WF function parameters)
--  release_type Type of release
--End of Comment
-------------------------------------------------------------------------------
PROCEDURE Set_Wf_Release_Tol(
  itemtype         IN VARCHAR2,
        itemkey          IN VARCHAR2,
  release_type   IN VARCHAR2)
IS
x_org_id number;
x_tol_tab PO_CO_TOLERANCES_GRP.tolerances_tbl_type;
x_return_status varchar2(1);
x_msg_count NUMBER;
x_msg_data VARCHAR2(2000);
BEGIN
  --<R12 Requester Driven Procurement Start>
  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: Set_Wf_Release_Tol ***');
  END IF;

  -- Retrieve organization id
  x_org_id:=  PO_WF_UTIL_PKG.GetItemAttrNumber (itemtype  => itemType,
                                          itemkey       => itemkey,
                                          aname         => 'ORG_ID');
  -- Retrieve the tolerances
  PO_CO_TOLERANCES_GRP.GET_TOLERANCES (1.0,
               FND_API.G_TRUE,
               x_org_id,
                        PO_CO_TOLERANCES_GRP.G_CHG_RELEASES,
                        x_tol_tab,
               x_return_status,
                        x_msg_count,
               x_msg_data);

   IF x_return_status <> FND_API.g_ret_sts_success THEN
      RAISE FND_API.g_exc_unexpected_error;
   END IF;

   -- loop through all the tolerances retrieved from the table and
   -- set wf attributes with values from the table if not null
   for i in 1..x_tol_tab.count
   loop
     -- Assign the values
     -- ECO 4716963: Added a condition for all tolerences to only assign not
     -- null values from the table
     -- Common Tolerances
     if (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_SHIPMENT_PRICE) then

        if x_tol_tab(i).max_increment is not null then
          PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_PRICE_OVERRIDE_T',
                                         x_tol_tab(i).max_increment);
        end if;

     elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_SHIPMENT_QTY) then

        if x_tol_tab(i).max_increment is not null then
          PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_QUANTITY_T',
                                         x_tol_tab(i).max_increment);
        end if;

     elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_DISTRIBUTION_QTY) then

        if x_tol_tab(i).max_increment is not null then
          PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_D_QUANTITY_ORDERED_T',
                                         x_tol_tab(i).max_increment);

        end if;

     elsif (x_tol_tab(i).tolerance_name =
        PO_CO_TOLERANCES_GRP.G_SHIPMENT_AMOUNT_PERCENT) then

        if x_tol_tab(i).max_increment is not null then
          PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_AMOUNT_T',
                                         x_tol_tab(i).max_increment);
        end if;

     elsif (x_tol_tab(i).tolerance_name =
        PO_CO_TOLERANCES_GRP.G_DISTRIBUTION_AMOUNT_PERCENT) then

        if x_tol_tab(i).max_increment is not null then
          PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_D_AMOUNT_ORDERED_T',
                                         x_tol_tab(i).max_increment);
        end if;
     end if;

     if (release_type = 'BLANKET') then

       if (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_NEED_BY_DATE) then

         if x_tol_tab(i).max_increment is not null then
           PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_NEED_BY_DATE_T',
                                         x_tol_tab(i).max_increment);
         end if;

       elsif (x_tol_tab(i).tolerance_name = PO_CO_TOLERANCES_GRP.G_PROMISED_DATE) then

         if x_tol_tab(i).max_increment is not null then
            PO_WF_UTIL_PKG.SetItemAttrText(itemtype,
                                         itemkey,
                             'CO_S_PROMISED_DATE_T',
                                         x_tol_tab(i).max_increment);
         end if;

       end if;
     end if;
   end loop;

   IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
    '*** FINISH: Set_Wf_Release_Tol ***');
   END IF;
   --<R12 Requester Driven Procurement End>
EXCEPTION
 WHEN FND_API.g_exc_unexpected_error THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.get_Default_Release_Tol', 'Error in get_Default_Release_Tol');
  RAISE;

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.set_wf_release_tol', 'others');
  RAISE;
END Set_Wf_Release_Tol;

PROCEDURE debug_default_tolerance(
  itemtype         IN VARCHAR2,
  itemkey          IN VARCHAR2,
  x_tolerance_control t_tolerance_control_type)
IS
BEGIN

  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** In Procedure: debug_default_tolerance ***');
  END IF;

  /* Header Percentage Attibutes */
        IF (g_po_wf_debug = 'Y') THEN
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - h_blanket_total_t        : '||
       x_tolerance_control.h_blanket_total_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - h_amount_limit_t         : '||
       x_tolerance_control.h_amount_limit_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - h_po_total_t         : '||
       x_tolerance_control.h_po_total_t );

           --<R12 Requester Driven Procurement Start>
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - l_start_date_t         : '||
       x_tolerance_control.l_start_date_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - l_end_date_t         : '||
       x_tolerance_control.l_end_date_t );
           --<R12 Requester Driven Procurement End>
        END IF;

  /* Line Percentage Attibutes */
        IF (g_po_wf_debug = 'Y') THEN
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - l_quantity_t             : '||
       x_tolerance_control.l_quantity_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - l_unit_price_t           : '||
       x_tolerance_control.l_unit_price_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - l_quantity_committed_t   : '||
       x_tolerance_control.l_quantity_committed_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - l_committed_amount_t     : '||
       x_tolerance_control.l_committed_amount_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - l_price_limit_t          : '||
       x_tolerance_control.l_price_limit_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - l_price_limit_t          : '||
       x_tolerance_control.l_price_limit_t );
           --<R12 Requester Driven Procurement Start>
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - l_amount_t          : '||
       x_tolerance_control.l_amount_t );
           --<R12 Requester Driven Procurement End>
        END IF;

  /* Shipment Percentage Attributes */
        IF (g_po_wf_debug = 'Y') THEN
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - s_quantity_t             : '||
       x_tolerance_control.s_quantity_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - s_price_override_t       : '||
       x_tolerance_control.s_price_override_t );

           --<R12 Requester Driven Procurement Start>
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - s_amount_t         : '||
       x_tolerance_control.s_amount_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - s_need_by_date_t         : '||
       x_tolerance_control.s_need_by_date_t );
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - s_promised_date_t         : '||
       x_tolerance_control.s_promised_date_t );
           --<R12 Requester Driven Procurement End>

        END IF;

  /* Distributions Attributes */
        IF (g_po_wf_debug = 'Y') THEN
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - d_quantity_ordered_t     : '||
       x_tolerance_control.d_quantity_ordered_t );
           --<R12 Requester Driven Procurement Start>
           PO_WF_DEBUG_PKG.insert_debug(itemtype, itemkey,
                   'Tolerance - d_amount_ordered_t       : '||
       x_tolerance_control.d_amount_ordered_t );
           --<R12 Requester Driven Procurement End>
        END IF;

  IF (g_po_wf_debug = 'Y') THEN
     PO_WF_DEBUG_PKG.INSERT_DEBUG(ITEMTYPE, ITEMKEY,
       '*** FINISH: debug_default_tolerance ***');
  END IF;

EXCEPTION

 WHEN OTHERS THEN
  wf_core.context('POAPPRV', 'po_chord_wf6.debug_default_tolerance', 'others');
  RAISE;

END;

END PO_CHORD_WF6;
/