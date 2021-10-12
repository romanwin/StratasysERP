CREATE OR REPLACE PACKAGE xxpo_shipments_status_pkg IS

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
  --  1.2   26/07/2010      yuval tal       add (failed )err row count out var
  --  1.3  8.5.17           yuval tal       CHG0040670 : add get_hold_period
  -----------------------------------------------------------------------
  PROCEDURE update_po_promise_date(p_update_id IN NUMBER,
		           p_update    IN VARCHAR2,
		           --p_err_count  OUT NUMBER,
		           p_error_code OUT NUMBER,
		           p_error_desc OUT VARCHAR2);

  PROCEDURE update_po(p_po_number                  IN VARCHAR2,
	          p_release_number             IN NUMBER,
	          p_revision_number            IN NUMBER,
	          p_line_number                IN NUMBER,
	          p_shipment_number            IN NUMBER,
	          p_new_promised_date          IN DATE,
	          p_launch_approval_flag       IN VARCHAR2,
	          p_buyer_name                 IN VARCHAR2,
	          p_org_id                     IN NUMBER,
	          p_po_line_id                 IN NUMBER,
	          p_po_header_id               IN NUMBER,
	          p_changed_orig_promised_date IN VARCHAR2,
	          p_error_code                 OUT NUMBER,
	          p_error_desc                 OUT VARCHAR2);

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
		           p_error_desc       OUT NUMBER);

  FUNCTION get_hold_period(p_location_id NUMBER) RETURN NUMBER;

END xxpo_shipments_status_pkg;
/
