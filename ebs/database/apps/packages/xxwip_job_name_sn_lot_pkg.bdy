create or replace package body xxwip_job_name_sn_lot_pkg IS
  --------------------------------------------------------------------
  --  name:             xxwip_job_name_sn_lot_pkg
  --  create by:        yuval tal
  --  $Revision:        1.0
  --  creation date:    20.11.2012
  --  Description:      CR520 : get_lot_details : add logic for REF jobs
  --------------------------------------------------------------------
  --  ver   date        name            desc
  --  1.0  20.11.2012   yuval tal       CR520 : get_lot_details : add logic for REF jobs
  --  1.1  02.01.2013   yuval tal       CR633 : change logic get_lot_details
  --  1.2  07/10/2014   Dalit A. Raviv  CHG0033497 - Handle expiration date calculation
  --                                                 and changed YYYY to RRRR
  --  1.3  17.06.2014   Gary Altman     CHG0032498: Function get_if_wip_material_trx: Add logic do not perform validation on 'ATO' jobs
  --  1.4  29.11.2015   Yuval Tal       CHG0037096 Fix progarm codes to avoid data duplication due to lot uniqueness remove ,
  --                                     modify get_lot_details
  --  1.5  15.06.2017   Lingaraj(TCS)   CHG0040682 - Depot  Repair  - completion
  --                                    To allow completion for Depot Repair Job even if there is no transaction value.
  --                                    Code modified by  Yuval & Uri Landesberg                                              
  --  1.6  29-Mar-2018  dan M.          CHG0042327 Generate Job number code should only check Make item serial number
  
  --------------------------------------------------------------------

  FUNCTION autonomous_generate_serial(p_org_id     IN NUMBER,
			  p_inv_itm_id IN NUMBER,
			  p_quantity   IN NUMBER DEFAULT 1,
			  p_err_msg    IN OUT VARCHAR2)
    RETURN VARCHAR2 IS
    PRAGMA AUTONOMOUS_TRANSACTION;

    l_return_status VARCHAR2(10);

  BEGIN

    inv_serial_number_pub.generate_serials(x_retcode     => l_return_status,
			       x_errbuf      => p_err_msg,
			       p_org_id      => p_org_id,
			       p_item_id     => p_inv_itm_id,
			       p_qty         => p_quantity,
			       p_serial_code => NULL,
			       p_wip_id      => NULL,
			       p_rev         => NULL,
			       p_lot         => NULL);
    RETURN l_return_status;

  END autonomous_generate_serial;

  -- Private type declarations
  
  -- Changes : 
  --  1.6  29-Mar-2018  dan M.          CHG0042327 Generate Job number code should only check Make item serial number
  
  FUNCTION get_sn(p_org_id     NUMBER,
	      p_inv_itm_id IN NUMBER) RETURN VARCHAR2 IS

    l_wip_id        NUMBER := NULL;
    l_group_mark_id NUMBER := NULL;
    l_line_mark_id  NUMBER := NULL;
    l_rev           NUMBER := NULL;
    l_lot           VARCHAR2(30) := NULL;
    --l_skip_serial   VARCHAR2(5) := wip_constants.yes;
    l_start_ser VARCHAR2(30) := NULL;
    l_end_ser   VARCHAR2(30) := NULL;
    --l_sn_num        VARCHAR2(30) := NULL;
    --l_num           NUMBER;
    l_status  VARCHAR2(10);
    l_err_msg VARCHAR2(1000);
    l_tmp     NUMBER;
   

  BEGIN

    --
    -- Runs SN Generation
    --

    l_status := inv_serial_number_pub.generate_serials(p_org_id        => p_org_id,
				       p_item_id       => p_inv_itm_id,
				       p_qty           => 1,
				       p_wip_id        => l_wip_id,
				       p_group_mark_id => l_group_mark_id,
				       p_line_mark_id  => l_line_mark_id,
				       p_rev           => l_rev,
				       p_lot           => l_lot,
				       p_skip_serial   => wip_constants.yes,
				       x_start_ser     => l_start_ser,
				       x_end_ser       => l_end_ser,
				       x_proc_msg      => l_err_msg);

    IF l_status != 0 THEN
      fnd_message.set_name('XXOBJT', 'XXWIP_GEN_JOB_NUM_PROB_SN');
      fnd_message.set_token('SQLERR',
		    'Cuoncurrent problem : ' || l_err_msg);
      RETURN 'ERROR';
    END IF;

    IF l_start_ser IS NULL THEN
      fnd_message.set_name('XXOBJT', 'XXWIP_GEN_JOB_NUM_PROB_SN');
      fnd_message.set_token('SQLERR',
		    'cant find SN : ' || l_status || '-' ||
		    l_err_msg);
      RETURN 'ERROR';
    END IF;

   l_tmp := xxwip_generate_sn_pkg.CheckSR(p_item_id => p_inv_itm_id, p_sr => l_start_ser); -- CHG0042327 : Check only for MAKE Items.

    IF nvl(l_tmp, 0) = 1 THEN

      fnd_message.set_name('XXOBJT', 'XXWIP_GEN_JOB_NUM_PROB_SN');
      fnd_message.set_token('SQLERR',
		    'Serial number already exists for different item , please contact Oracle operation support');
      RETURN 'ERROR';
    END IF;

    RETURN l_start_ser;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_message.set_name('XXOBJT', 'XXWIP_GEN_JOB_NUM_PROB_SN');
      fnd_message.set_token('SQLERR',
		    l_status || '-' || l_err_msg || '-' || SQLERRM);
      RETURN 'ERROR';

  END get_sn;

  FUNCTION check_item_control(p_org_id      IN NUMBER,
		      p_itm_seg1    IN mtl_system_items_b.segment1%TYPE,
		      p_inv_itm_id  OUT mtl_system_items_b.inventory_item_id%TYPE,
		      p_shlf_life_d OUT mtl_system_items_b.shelf_life_days%TYPE)
    RETURN VARCHAR2 IS
    l_inv_itm_id                 mtl_system_items_b.inventory_item_id%TYPE;
    l_shelf_life_code            mtl_system_items_b.shelf_life_code%TYPE;
    l_lot_control_code           mtl_system_items_b.lot_control_code%TYPE;
    l_serial_number_control_code mtl_system_items_b.serial_number_control_code%TYPE;
    l_shlf_life_d                mtl_system_items_b.shelf_life_days%TYPE;
    l_return_code                VARCHAR2(1); -- 'L' for lot control , 'S' for Serial control , 'N'  for none
  BEGIN

    --
    -- Selects the inventory item id
    --
    SELECT itm.inventory_item_id,
           itm.shelf_life_code,
           itm.lot_control_code,
           itm.serial_number_control_code,
           itm.shelf_life_days
    INTO   l_inv_itm_id,
           l_shelf_life_code,
           l_lot_control_code,
           l_serial_number_control_code,
           l_shlf_life_d
    FROM   mtl_system_items_b itm
    WHERE  itm.organization_id = p_org_id
    AND    itm.segment1 = p_itm_seg1;

    --return the item id to the custom_pll
    p_inv_itm_id  := l_inv_itm_id;
    p_shlf_life_d := l_shlf_life_d;
    IF l_shelf_life_code = 2 AND l_lot_control_code = 2 THEN
      l_return_code := 'L';

    ELSIF l_serial_number_control_code IN (2, 5) THEN
      l_return_code := 'S';
    ELSE
      l_return_code := 'N';
    END IF;

    RETURN l_return_code;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_message.set_name('XXOBJT', 'XXWIP_GEN_JOB_NUM_PROB_ITM');
      fnd_message.set_token('SQLERR', SQLERRM);
      fnd_message.raise_error;
  END;

  PROCEDURE get_lot_num_rec(p_org_id       NUMBER,
		    p_inv_itm_id   IN NUMBER,
		    p_lot_returned mtl_lot_numbers.lot_number%TYPE,
		    p_shlf_life_d  mtl_system_items_b.shelf_life_days%TYPE,
		    p_lot_rec      OUT mtl_lot_numbers%ROWTYPE) IS
    l_lot_rec mtl_lot_numbers%ROWTYPE;
  BEGIN

    l_lot_rec.inventory_item_id := p_inv_itm_id;
    l_lot_rec.organization_id   := p_org_id;
    l_lot_rec.lot_number        := p_lot_returned;
    l_lot_rec.last_update_date  := SYSDATE;
    l_lot_rec.last_updated_by   := fnd_global.user_id;
    l_lot_rec.creation_date     := SYSDATE;
    l_lot_rec.created_by        := fnd_global.user_id;
    l_lot_rec.last_update_login := 0;
    -- cr 485 change logic for expiration_date
    l_lot_rec.expiration_date    := trunc(add_months(SYSDATE,
				     round(p_shlf_life_d / 30)),
			      'MM') + 14; /*to_date('15' || '-' ||
                                                                                                        to_char(SYSDATE + p_shlf_life_d,
                                                                                                                'MON-YYYY'),
                                                                                                        'DD-MON-YYYY');*/
    l_lot_rec.status_id          := 1;
    l_lot_rec.origination_type   := 0;
    l_lot_rec.origination_date   := SYSDATE;
    l_lot_rec.availability_type  := 1;
    l_lot_rec.inventory_atp_code := 1;
    l_lot_rec.reservable_type    := 1;

    p_lot_rec := l_lot_rec;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_message.set_name('XXOBJT', 'XXWIP_GEN_JOB_NUM_PROB_LOT');
      fnd_message.set_token('SQLERR', SQLERRM);
      fnd_message.raise_error;
  END;

  --------------------------------------------------------------------
  --  name:               get_lot_details
  --  create by:          yuval tal
  --  $Revision:          1.0
  --  creation date:      2.1.13
  --  Description:        CR633 : Change Logic for Lot Expiration Date for RES jobs
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   2.1.13        yuval tal       initial build
  --  1.1   07/10/2014    Dalit A. Raviv  CHG0033497 - Handle expiration date calculation
  --                                      and changed YYYY to RRRR

  --  1.2    29.11.2015     yuval tal       CHG0037096 Fix progarm codes to avoid data duplication due to lot uniqueness remove
  --------------------------------------------------------------------
  PROCEDURE get_lot_details(p_job_name         IN wip_entities.wip_entity_name%TYPE,
		    p_item_segment     IN mtl_system_items_b.segment1%TYPE,
		    p_organization_id  IN NUMBER,
		    p_transaction_date IN VARCHAR2,
		    x_lot_number       IN OUT mtl_lot_numbers.lot_number%TYPE,
		    x_expiration_date  IN OUT VARCHAR2,
		    x_return_status    IN OUT VARCHAR2) IS

    PRAGMA AUTONOMOUS_TRANSACTION;

    l_inventory_item_id mtl_system_items_b.inventory_item_id%TYPE;
    l_shelf_life_days   mtl_system_items_b.shelf_life_days%TYPE;
    l_lot_prefix        mtl_system_items_b.auto_lot_alpha_prefix%TYPE;
    l_transaction_date  DATE := NULL;
    l_expiration_date   DATE := NULL;
    l_origination_date  DATE;
    l_return_status     VARCHAR2(1);
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(500);
    l_err_msg           VARCHAR2(500);
    l_wip_entity_id     NUMBER;
    t_attributes_tbl    inv_lot_api_pub.char_tbl;
    t_c_attributes_tbl  inv_lot_api_pub.char_tbl;
    t_n_attributes_tbl  inv_lot_api_pub.number_tbl;
    t_d_attributes_tbl  inv_lot_api_pub.date_tbl;

  BEGIN

    x_lot_number      := NULL;
    x_expiration_date := NULL;
    x_return_status   := 'S';

    IF p_job_name LIKE 'MTL%' THEN

      BEGIN

        SELECT msi.inventory_item_id,
	   mln.lot_number,
	   nvl(msi.shelf_life_days, 0),
	   auto_lot_alpha_prefix,
	   mln.origination_date
        INTO   l_inventory_item_id,
	   x_lot_number,
	   l_shelf_life_days,
	   l_lot_prefix,
	   l_origination_date
        FROM   mtl_system_items_b msi,
	   mtl_lot_numbers    mln
        WHERE  msi.inventory_item_id = mln.inventory_item_id
        AND    mln.organization_id = p_organization_id
        AND    mln.lot_number = p_job_name
        AND    msi.segment1 = p_item_segment
        AND    msi.organization_id =
	   xxinv_utils_pkg.get_master_organization_id;

      EXCEPTION
        WHEN no_data_found THEN

          fnd_message.set_name('XXOBJT', 'XXWIP_GEN_JOB_NO_LOT_FOUND');
          fnd_message.set_token('JOB_NAME', p_job_name);
          x_return_status := 'E';
          RETURN;
      END;

      -- 07/10/2014 Dalit A. Raviv
      -- Dalit A. Raviv 07/10/2014 changed YYYY to RRRR
      -- and Handle expiration date calculation
      --l_transaction_date := to_date(p_transaction_date, 'DD-MON-YYYY HH24:MI:SS') + l_shelf_life_days;
      l_transaction_date := trunc(add_months(to_date(p_transaction_date,
				     'DD-MON-RRRR HH24:MI:SS'),
			         round(l_shelf_life_days / 30)),
		          'MM') + 14;
      --
      ---- cr520

      --  ELSIF p_job_name LIKE 'REF%' THEN -- cr633
    ELSE
      BEGIN

        SELECT wip_entity_id
        INTO   l_wip_entity_id
        FROM   wip_entities
        WHERE  wip_entity_name = p_job_name
        AND    organization_id = p_organization_id;

        SELECT inventory_item_id,
	   lot_number,
	   origination_date
        INTO   l_inventory_item_id,
	   x_lot_number,
	   l_origination_date
        FROM   (SELECT mln2.inventory_item_id,
	           mln2.lot_number,
	           mln2.origination_date
	    FROM   mtl_lot_numbers             mln1,
	           wip_entities                we,
	           mtl_transaction_lot_numbers mtln,
	           mtl_lot_numbers             mln2,
	           mtl_object_genealogy        mog
	    WHERE  mln1.lot_number = mtln.lot_number
	    AND    mln1.inventory_item_id = mtln.inventory_item_id --  CHG0037096
	    AND    we.wip_entity_id = l_wip_entity_id
	    AND    mtln.organization_id = mln1.organization_id
	    AND    mln1.organization_id = p_organization_id
	    AND    we.wip_entity_id = mtln.transaction_source_id
	    AND    we.organization_id = mln1.organization_id
	    AND    we.primary_item_id = mln2.inventory_item_id
	    AND    mln2.organization_id = mln1.organization_id
	    AND    mln2.gen_object_id = mog.parent_object_id
	    AND    mln1.gen_object_id = mog.object_id
	    AND    mog.object_type = 1
	    AND    mog.parent_object_type = 1
	    ORDER  BY mln2.lot_number DESC)
        WHERE  rownum < 2;

        SELECT expiration_date
        INTO   l_transaction_date
        FROM   mtl_lot_numbers    mln,
	   mtl_system_items_b msi
        WHERE  mln.lot_number = x_lot_number
        AND    mln.organization_id = p_organization_id
        AND    mln.inventory_item_id = msi.inventory_item_id
        AND    msi.organization_id = mln.organization_id
        AND    msi.segment1 = p_item_segment;

      EXCEPTION
        WHEN OTHERS THEN
          l_err_msg          := SQLERRM;
          l_transaction_date := NULL;
      END;

      IF l_transaction_date IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXWIP_GEN_JOB_NO_TRX_FOUND');
        --fnd_message.set_token('JOB_NAME', p_job_name);
        x_return_status := 'E';
        RETURN;
      END IF;

      ---- end cr520
    END IF;

    -- Dalit A. Raviv 07/10/2014 changed YYYY to RRRR
    l_expiration_date := to_date('15-' ||
		         to_char(l_transaction_date, 'MON-RRRR'),
		         'DD-MON-RRRR');

    x_expiration_date := to_char(l_expiration_date,
		         'DD-MON-RRRR HH24:MI:SS');

    inv_lot_api_pub.update_inv_lot(x_return_status     => l_return_status,
		           x_msg_count         => l_msg_count,
		           x_msg_data          => l_msg_data,
		           p_inventory_item_id => l_inventory_item_id,
		           p_organization_id   => p_organization_id,
		           p_lot_number        => x_lot_number,
		           p_expiration_date   => l_expiration_date,
		           p_origination_date  => l_origination_date,
		           p_attributes_tbl    => t_attributes_tbl,
		           p_c_attributes_tbl  => t_c_attributes_tbl,
		           p_n_attributes_tbl  => t_n_attributes_tbl,
		           p_d_attributes_tbl  => t_d_attributes_tbl,
		           p_source            => 3);

    IF (l_return_status != 'S') THEN
      FOR i IN 1 .. l_msg_count LOOP
        l_msg_data := fnd_msg_pub.get(i, 'F');
        l_err_msg  := l_err_msg || l_msg_data || chr(10);
      END LOOP;
      ROLLBACK;

      fnd_message.set_name('XXOBJT', 'XXWIP_GEN_JOB_NEW_EXP_DATE');
      fnd_message.set_token('ERR', l_err_msg);
      x_return_status := 'E';
      RETURN;

    ELSE

      COMMIT;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      NULL;
      --    l_err_msg := SQLERRM;
  END get_lot_details;

  PROCEDURE get_completion_quantity(p_wip_entity_id   IN wip_entities.wip_entity_id%TYPE,
			p_job_name        IN wip_entities.wip_entity_name%TYPE,
			p_item_segment    IN mtl_system_items_b.segment1%TYPE,
			p_organization_id IN NUMBER,
			p_job_auantity    IN NUMBER,
			p_avail_quantiry  IN NUMBER,
			x_quantity        IN OUT VARCHAR2,
			x_return_status   IN OUT VARCHAR2) IS

    l_shrinkage_rate mtl_system_items_b.shrinkage_rate%TYPE := 0;
    l_issued_qty     NUMBER := 0;
    l_job_uom        VARCHAR2(3);

  BEGIN

    x_quantity      := NULL;
    x_return_status := 'S';

    IF p_job_name NOT LIKE 'MTL%' THEN
      x_quantity := -1;
      RETURN;
    END IF;

    SELECT primary_uom_code,
           nvl(msi.shrinkage_rate, 0)
    INTO   l_job_uom,
           l_shrinkage_rate
    FROM   mtl_system_items_b msi
    WHERE  msi.segment1 = p_item_segment
    AND    msi.organization_id = xxinv_utils_pkg.get_master_organization_id;

    SELECT SUM(wro.quantity_issued)
    INTO   l_issued_qty
    FROM   wip_requirement_operations wro,
           mtl_system_items_b         item
    WHERE  wro.inventory_item_id = item.inventory_item_id
    AND    wro.organization_id = item.organization_id
    AND    wip_entity_id = p_wip_entity_id
    AND    item.primary_uom_code = l_job_uom;

    /*      x_quantity := l_issued_qty *
                        (p_avail_quantiry / p_job_auantity);
    */

    IF nvl(l_issued_qty, 0) = 0 THEN
      x_quantity := -1;
    ELSE
      x_quantity := l_issued_qty;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      fnd_message.set_name('XXOBJT', 'XXWIP_GEN_JOB_NOT_ISSUE');
      fnd_message.set_token('JOB_NAME', p_job_name);
      x_return_status := 'E';
  END get_completion_quantity;

  --------------------------------------------------------------------
  --  customization code: CUSTxxx
  --  name:               get_if_wip_material_trx
  --  create by:          Dalit A. Raviv
  --  $Revision: 3948 $
  --  creation date:      26/01/2010
  --------------------------------------------------------------------
  --  process:            check if there is any wip material transaction
  --                      done for this job - wip_entity_id.
  --  return:             Y - user did report trx
  --                      N - user did not report any trx
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/01/2010    Dalit A. Raviv  initial build
  --  1.1   17/06/2014    Gary Altman     Add logic do not perform validation on 'ATO' jobs 
  --  1.2   15.06.2017    Lingaraj(TCS)   CHG0040682 - Depot  Repair  - completion
  --                                      To allow completion for Depot Repair Job even if there is no transaction value.
  --                                      Code modified by  Yuval & Uri Landesberg
  --------------------------------------------------------------------
  FUNCTION get_if_wip_material_trx(p_wip_entity_id IN NUMBER) RETURN VARCHAR2 IS

    CURSOR get_wip_material_trx_c IS
      SELECT a.cost_element,
	 a.value_in
      FROM   cst_wip_cost_elem_variances_v a,
	 wip_entities                  wipen,
	 wip_discrete_jobs             wipds,
	 wip_discrete_classes_all_v    wipclas,
	 mtl_system_items_b            msi
      WHERE  a.wip_entity_id = wipen.wip_entity_id
      AND    a.organization_id = wipen.organization_id
      AND    wipds.wip_entity_id = wipen.wip_entity_id
      AND    wipen.organization_id = wipds.organization_id
      AND    wipclas.class_code = wipds.class_code
      AND    wipclas.organization_id = wipds.organization_id
      AND    msi.inventory_item_id = wipds.primary_item_id
      AND    msi.organization_id = wipds.organization_id
      AND    wipds.wip_entity_id = p_wip_entity_id --386001
      AND    a.value_in <> 0; -- to ask Yaniv

    l_value_in NUMBER := 0;
    l_ato_flag VARCHAR2(10); -- ver. 1.1    
    l_source_line_id NUMBER; -- ver 1.2   Added on 15 Jun  2017 for CHG0040682
  BEGIN   
    ---------------------------------ver 1.2 start ------------------------    
    -- CHG0040682 - Added on 15 June 2017
    -- To allow completion for Depot Repair Job even if there is no transaction value.
    BEGIN
      SELECT source_line_id
      INTO   l_source_line_id
      FROM   wip_discrete_jobs
      WHERE  wip_entity_id = p_wip_entity_id;
    
      IF l_source_line_id = 512 THEN
        RETURN 'Y'; 
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;            
    END;           
    ---------------------------------ver 1.2 end ------------------------
    -----------------------------------ver. 1.1 Start -------------------------------------------------------------------
    BEGIN
      SELECT wipds.class_code
      INTO   l_ato_flag
      FROM   wip_discrete_jobs wipds
      WHERE  wip_entity_id = p_wip_entity_id;      
    EXCEPTION
      WHEN OTHERS THEN
        l_ato_flag := NULL;
    END;
    ------------------------------------ ver. 1.1 End ------------------------------------------------------------------
    FOR get_wip_material_trx_r IN get_wip_material_trx_c LOOP
      l_value_in := get_wip_material_trx_r.value_in;
    END LOOP;
    /*loop
      open get_wip_material_trx_c;
      fetch get_wip_material_trx_c.value_in into l_value_in;
      EXIT  WHEN get_wip_material_trx_c%NOTFOUND;
    end loop;
    close get_wip_material_trx_c;*/

    IF nvl(l_ato_flag, NULL) = 'ATO' THEN
      -- ver. 1.1
      RETURN 'Y';
    ELSE
      IF nvl(l_value_in, 0) = 0 THEN
        RETURN 'N';
      ELSE
        RETURN 'Y';
      END IF;
    END IF;

  END get_if_wip_material_trx;

END xxwip_job_name_sn_lot_pkg;
/
