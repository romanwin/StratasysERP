CREATE OR REPLACE PACKAGE xxwip_job_name_sn_lot_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxwip_job_name_sn_lot_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxwip_job_name_sn_lot_pkg
  -- Created: Nili
  -- Author  : 5/4/2009
  --------------------------------------------------------------------------
  -- Perpose: Change job name with SN or lot No. + completion
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.0  31/08/09     Nili            Initial Build
  --  1.1  26/01/2010   Dalit A. Raviv  add function  
  --  1.2  30.1.2011    yuval tal       change logic get_sn
  --  1.3  6.8.2012     yuval tal       change logic in get_lot_num_rec
  --  1.4  20.11.2012   yuval tal       CR520 : get_lot_details : add logic for REF jobs
  ---------------------------------------------------------------------------
  FUNCTION autonomous_generate_serial(p_org_id     IN NUMBER,
			  p_inv_itm_id IN NUMBER,
			  p_quantity   IN NUMBER DEFAULT 1,
			  p_err_msg    IN OUT VARCHAR2)
    RETURN VARCHAR2;

  -- Public type declarations
  FUNCTION check_item_control(p_org_id      IN NUMBER,
		      p_itm_seg1    IN mtl_system_items_b.segment1%TYPE,
		      p_inv_itm_id  OUT mtl_system_items_b.inventory_item_id%TYPE,
		      p_shlf_life_d OUT mtl_system_items_b.shelf_life_days%TYPE)
    RETURN VARCHAR2;

  FUNCTION get_sn(p_org_id     NUMBER,
	      p_inv_itm_id IN NUMBER) RETURN VARCHAR2;

  PROCEDURE get_lot_num_rec(p_org_id       NUMBER,
		    p_inv_itm_id   IN NUMBER,
		    p_lot_returned mtl_lot_numbers.lot_number%TYPE,
		    p_shlf_life_d  mtl_system_items_b.shelf_life_days%TYPE,
		    p_lot_rec      OUT mtl_lot_numbers%ROWTYPE);

  PROCEDURE get_lot_details(p_job_name         IN wip_entities.wip_entity_name%TYPE,
		    p_item_segment     IN mtl_system_items_b.segment1%TYPE,
		    p_organization_id  IN NUMBER,
		    p_transaction_date IN VARCHAR2,
		    x_lot_number       IN OUT mtl_lot_numbers.lot_number%TYPE,
		    x_expiration_date  IN OUT VARCHAR2,
		    x_return_status    IN OUT VARCHAR2);

  PROCEDURE get_completion_quantity(p_wip_entity_id   IN wip_entities.wip_entity_id%TYPE,
			p_job_name        IN wip_entities.wip_entity_name%TYPE,
			p_item_segment    IN mtl_system_items_b.segment1%TYPE,
			p_organization_id IN NUMBER,
			p_job_auantity    IN NUMBER,
			p_avail_quantiry  IN NUMBER,
			x_quantity        IN OUT VARCHAR2,
			x_return_status   IN OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CUSTxxx
  --  name:               get_if_wip_material_trx
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      26/01/2010
  --------------------------------------------------------------------
  --  process:            check if there is any wip material transaction
  --                      done for this job - wip_entity_id.
  --  return:             Y - user did report trx  
  --                      N - user did not report any trx              
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/01/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------                                     
  FUNCTION get_if_wip_material_trx(p_wip_entity_id IN NUMBER) RETURN VARCHAR2;

END xxwip_job_name_sn_lot_pkg;
/
