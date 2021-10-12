CREATE OR REPLACE PACKAGE BODY XXCSI_NSRL_RMA_PKG AS
--------------------------------------------------------------------
--  name:            CUST 321 - Update IB and clear Error interface after RMA process
--  create by:       Vitaly K.
--  Revision:        1.0 
--  creation date:   30/05/2010 
--------------------------------------------------------------------
--  purpose :        Update IB and clear Error interface after RMA process
--------------------------------------------------------------------
--  ver  date        name            desc
--  1.0  30/05/2010  Vitaly K.       initial build
-------------------------------------------------------------------- 

  l_inst_tbl_cache    instance_tbl;

  --------------------------------------------------------------------
  --  name:            LOG
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        Procedure that get message and write it to log
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  -------------------------------------------------------------------- 
  PROCEDURE LOG(p_message IN VARCHAR2) IS
  BEGIN
    fnd_file.put_line(fnd_file.LOG, p_message);
    csi_t_gen_utility_pvt.g_debug_level := 10;
    csi_t_gen_utility_pvt.build_file_name(p_file_segment1 => 'csinsrmalog',
                                          p_file_segment2 => TO_CHAR(SYSDATE, 'mmddyy'));
    csi_t_gen_utility_pvt.ADD(p_message);
    csi_t_gen_utility_pvt.g_debug_level := 0;

  END LOG;

  --------------------------------------------------------------------
  --  name:            OUT
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        Procedure that get message and write it to out
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  --------------------------------------------------------------------
  PROCEDURE OUT(p_message IN VARCHAR2) IS
  BEGIN
    fnd_file.put_line(fnd_file.output, p_message);
    csi_t_gen_utility_pvt.g_debug_level := 10;
    csi_t_gen_utility_pvt.build_file_name(p_file_segment1 => 'csinsrmaout',
                                          p_file_segment2 => TO_CHAR(SYSDATE, 'mmddyy'));
    csi_t_gen_utility_pvt.ADD(p_message);
    csi_t_gen_utility_pvt.g_debug_level := 0;
  END OUT;

  --------------------------------------------------------------------
  --  name:            create_ib_relationship
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        Procedure that create IB relationship
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  --------------------------------------------------------------------
  Procedure create_ib_relationship (p_parent_instance_id  IN NUMBER,
                                    p_child_instance_id   IN NUMBER) is
                                    
    l_txn_rec_chi          csi_datastructures_pub.transaction_rec;
    l_relationship_tbl     csi_datastructures_pub.ii_relationship_tbl; 
    l_relationship_tbl1    csi_datastructures_pub.ii_relationship_tbl;   
    l_return_status        varchar2(2500) := null;
    l_msg_count            number := null;
    l_msg_data             varchar2(2500) := null;
    l_msg_index_out        number := null;
    l_relationship_id      number;
    l_validation_level     number := null;   
    l_relation_exist       varchar2(10) := null; 
    MISSING_PARAMETER      EXCEPTION;
    REL_ALREADY_EXIST      EXCEPTION;
                   
  begin
  
    IF p_parent_instance_id  IS NULL OR p_child_instance_id IS NULL THEN
      RAISE MISSING_PARAMETER;
    END IF;
      
    LOG(''); --empty row
    LOG('---CREATE_IB_RELATIONSHIP procedure'); 
   
    l_relation_exist := null;
    ---------Check relationship exists
    BEGIN
      select 'EXISTS'
      into   l_relation_exist
      from   csi_ii_relationships cir
      where  object_id            = p_parent_instance_id --oola.attribute6
      and    subject_id           = p_child_instance_id  --cii.instance_id
      and    (active_end_date is null or active_end_date > sysdate);
          
      LOG('RELATIONSHIP Between Parent Instance ' || p_parent_instance_id ||
                        ' And Child Instance '||p_child_instance_id||' ALREADY EXIST');
      RAISE REL_ALREADY_EXIST;
    EXCEPTION
      -- relationship do not exists
      WHEN NO_DATA_FOUND THEN
        NULL;
    END;
  
    -- Create the relationship between Parent Instance and Child
    l_return_status    := NULL;
    l_msg_count        := NULL;
    l_msg_index_out    := NULL;
    l_validation_level := NULL;
    l_msg_data         := null;
    l_relationship_tbl := l_relationship_tbl1 ;

    select csi_ii_relationships_s.nextval
    into   l_relationship_id
    from   dual;

    l_relationship_tbl(1).relationship_id        := l_relationship_id;
    l_relationship_tbl(1).relationship_type_code := 'COMPONENT-OF';
    l_relationship_tbl(1).object_id              := p_parent_instance_id;
    l_relationship_tbl(1).subject_id             := p_child_instance_id;
    l_relationship_tbl(1).subject_has_child      := 'N';
    l_relationship_tbl(1).position_reference     := NULL;
    l_relationship_tbl(1).active_start_date      := SYSDATE;
    l_relationship_tbl(1).active_end_date        := NULL;
    l_relationship_tbl(1).display_order          := NULL;
    l_relationship_tbl(1).mandatory_flag         := 'N';
    l_relationship_tbl(1).object_version_number  := 1;

    l_txn_rec_chi.transaction_date        := trunc(SYSDATE);
    l_txn_rec_chi.source_transaction_date := trunc(SYSDATE);
    l_txn_rec_chi.transaction_type_id     := 1;
    l_txn_rec_chi.object_version_number   := 1;

    CSI_II_RELATIONSHIPS_PUB.CREATE_RELATIONSHIP(p_api_version      => 1,
                                                 p_commit           => FND_API.G_FALSE,     -- i v
                                                 p_init_msg_list    => FND_API.G_TRUE,      -- i v
                                                 p_validation_level => l_validation_level,
                                                 p_relationship_tbl => l_relationship_tbl,
                                                 p_txn_rec          => l_txn_rec_chi,
                                                 x_return_status    => l_return_status,
                                                 x_msg_count        => l_msg_count,
                                                 x_msg_data         => l_msg_data);

    IF l_return_status != FND_API.G_RET_STS_SUCCESS THEN 
       -- SUCCESS
      fnd_file.put_line(fnd_file.log,'l_return_status - '||l_return_status);
      fnd_msg_pub.get(p_msg_index     => -1,
                      p_encoded       => 'F',
                      p_data          => l_msg_data,
                      p_msg_index_out => l_msg_index_out);
      LOG('ERROR Create Relation Between Parent Instance ' || p_parent_instance_id ||
                        ' And Child Instance '||p_child_instance_id ||' : ' || l_msg_data);
    ELSE
       ---API FAILURE
       LOG('Relationship Between Parent Instance ' || p_parent_instance_id ||
                    ' And Child Instance '||p_child_instance_id||' was created SUCCESSFULY');
    END IF;
 
  EXCEPTION
    WHEN MISSING_PARAMETER THEN
      NULL;
    WHEN REL_ALREADY_EXIST THEN
      NULL;
    WHEN OTHERS THEN
      LOG('Unexpected Error in XXCSI_NSRL_RMA_PKG.create_ib_relationship : '||substr(sqlerrm,1,200));
  END create_ib_relationship;
  
  --------------------------------------------------------------------
  --  name:            clean_inst_detail
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        Procedure that clean inst detail
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  --------------------------------------------------------------------
  PROCEDURE clean_inst_detail (p_line_id  IN NUMBER) IS

  BEGIN

    LOG('Deleting installation detail...');

    DELETE FROM csi_t_party_accounts
	  WHERE  txn_party_detail_id IN 
           (SELECT txn_party_detail_id
            FROM   csi_t_party_details
            WHERE  txn_line_detail_id IN 
                       (SELECT txn_line_detail_id
                        FROM   csi_t_txn_line_details
                        WHERE  transaction_line_id IN (SELECT transaction_line_id
                                                       FROM   csi_t_transaction_lines
                                                       WHERE  source_transaction_id = p_line_id)));

	  DELETE FROM csi_t_party_details
	  WHERE  txn_line_detail_id IN 
                       (SELECT txn_line_detail_id
	                      FROM   csi_t_txn_line_details
	                      WHERE  transaction_line_id IN (SELECT transaction_line_id
	                                                     FROM   csi_t_transaction_lines
	                                                     WHERE  source_transaction_id = p_line_id));


	  DELETE FROM csi_t_txn_line_details
	  WHERE  transaction_line_id IN (SELECT transaction_line_id
	                                 FROM   csi_t_transaction_lines
	                                 WHERE  source_transaction_id = p_line_id);

	  DELETE FROM csi_t_transaction_lines
	  WHERE  source_transaction_id = p_line_id;

  END clean_inst_detail ;
  
  --------------------------------------------------------------------
  --  name:            cache_instance_id
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        Procedure that cache instance id
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  --------------------------------------------------------------------
  PROCEDURE cache_instance_id(p_inst_id            IN NUMBER,
                              p_inst_remained_qty  IN NUMBER ) IS
                              
    l_new_ind BINARY_INTEGER := 0;
    l_cached  BOOLEAN := FALSE;
  BEGIN
    IF NVL(p_inst_id, fnd_api.g_miss_num) <> fnd_api.g_miss_num THEN
      IF l_inst_tbl_cache.COUNT > 0 THEN
        FOR l_ind IN l_inst_tbl_cache.FIRST..l_inst_tbl_cache.LAST LOOP
          IF p_inst_id = l_inst_tbl_cache(l_ind).instance_id THEN
              ----This instance_id already exist in PLSQL table
              l_cached := TRUE;
              l_inst_tbl_cache(l_ind).inst_remained_qty:= p_inst_remained_qty;
              EXIT;
          END IF;
        END LOOP;
      END IF;

      IF NOT(l_cached) THEN
        ----Create new record in this PLSQL table
        l_new_ind := l_inst_tbl_cache.COUNT + 1;
        l_inst_tbl_cache(l_new_ind).instance_id := p_inst_id;
        l_inst_tbl_cache(l_new_ind).inst_remained_qty :=p_inst_remained_qty;
      END IF;
    END IF;
  END cache_instance_id;
  
  --------------------------------------------------------------------
  --  name:            inst_remained_qty
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  --------------------------------------------------------------------
  FUNCTION inst_remained_qty(p_instance_id IN NUMBER) RETURN NUMBER IS
      
    l_inst_remained_qty  NUMBER :=0 ;
  BEGIN

    LOG(''); --empty row
    LOG('---INST_REMAINED_QTY function: Search record in PLSQL table for this instance_ID and get inst_remained_qty');

    IF l_inst_tbl_cache.COUNT > 0  THEN
      FOR l_ind IN l_inst_tbl_cache.FIRST .. l_inst_tbl_cache.LAST LOOP
        IF l_inst_tbl_cache(l_ind).instance_id = p_instance_id  THEN
          l_inst_remained_qty := l_inst_tbl_cache(l_ind).inst_remained_qty;
          LOG('Record for this instance_id was found in PLSQL table --- inst remained_qty='||l_inst_remained_qty);
          EXIT;
        ELSE
          LOG('PLSQL table is not empty but record for this instance_id was not found --- return value -99');
          l_inst_remained_qty := -99;
        END IF;
      END LOOP;
    ELSE
      LOG('PLSQL table is empty --- return value -99');
      l_inst_remained_qty :=-99;
    END IF;
    
    RETURN l_inst_remained_qty;

  END inst_remained_qty;
  
  --------------------------------------------------------------------
  --  name:            get_rma_rec
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  --------------------------------------------------------------------
  PROCEDURE get_rma_rec(p_inv_mtl_txn_id IN  NUMBER,
                        p_lot_number     IN  VARCHAR2,
                        x_rma_rec        OUT NOCOPY rma_rec,
					              x_record_found   OUT NOCOPY BOOLEAN) IS

    l_rma_rec      rma_rec;
  BEGIN
    x_record_found :=TRUE;
    LOG('');  --empty record
    LOG('---GET_RMA_REC procedure: Start getting rma record');
	  l_rma_rec.lot_number := p_lot_number;

    BEGIN
      SELECT inventory_item_id,
             organization_id,
             NVL(revision, NULL),
             trx_source_line_id,
             ABS(primary_quantity),
             transaction_date
      INTO   l_rma_rec.inventory_item_id,
             l_rma_rec.organization_id,
             l_rma_rec.revision,
             l_rma_rec.rma_line_id,
             l_rma_rec.received_quantity,
             l_rma_rec.transaction_date
      FROM   mtl_material_transactions
      WHERE  transaction_id = p_inv_mtl_txn_id;

      LOG('---mtl_material_transactions data: ----');
      LOG('Inventory Item Id: '||l_rma_rec.inventory_item_id);
      LOG('Organization Id:   '||l_rma_rec.organization_id);
      LOG('Revision:          '||l_rma_rec.revision);
      LOG('Rma Line Id:       '||l_rma_rec.rma_line_id);
      LOG('Received Qty:      '||l_rma_rec.received_quantity);
      LOG('Transaction Date:  '||to_char(l_rma_rec.transaction_date,'DD-MON-YYYY'));
          
      SELECT sold_to_org_id,
             ordered_quantity,
             order_quantity_uom
      INTO   l_rma_rec.party_acct_id,
             l_rma_rec.ordered_quantity,
             l_rma_rec.order_quantity_uom
      FROM   oe_order_lines_all
      WHERE  line_id = l_rma_rec.rma_line_id;

      LOG('---oe_order_lines_all data: ----');
      LOG('Party Account Id: '||l_rma_rec.party_acct_id);
      LOG('Ordered Qty:      '||l_rma_rec.ordered_quantity);
      LOG('Ordered Qty Uom:  '||l_rma_rec.order_quantity_uom);

      SELECT party_id
      INTO   l_rma_rec.party_id
      FROM   hz_cust_accounts
      WHERE  cust_account_id = l_rma_rec.party_acct_id;

      LOG('---hz_cust_accounts data: ----');
      LOG('Party Id: '||l_rma_rec.party_id);
          
      x_rma_rec := l_rma_rec;
		EXCEPTION
      WHEN NO_DATA_FOUND THEN
        LOG('---GET_RMA_REC procedure: NO_DATA_FOUND');
        x_record_found := FALSE;
      WHEN TOO_MANY_ROWS THEN
        x_record_found := FALSE;
    END;
  END get_rma_rec;

  --------------------------------------------------------------------
  --  name:            create_rma_inst
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  --------------------------------------------------------------------
  PROCEDURE create_rma_inst (p_rma_rec  IN rma_rec,
                             x_instance_id  OUT NUMBER) IS
                             
    l_instance_rec		         CSI_DATASTRUCTURES_PUB.INSTANCE_REC;
    l_party_tbl		             CSI_DATASTRUCTURES_PUB.PARTY_TBL;
    l_account_tbl		           CSI_DATASTRUCTURES_PUB.PARTY_ACCOUNT_TBL;
    l_txn_rec 	  	           CSI_DATASTRUCTURES_PUB.TRANSACTION_REC;
	  l_pricing_attrib_tbl	     CSI_DATASTRUCTURES_PUB.PRICING_ATTRIBS_TBL;
	  l_ext_attrib_values        CSI_DATASTRUCTURES_PUB.EXTEND_ATTRIB_VALUES_TBL;
    l_org_assignments_tbl      CSI_DATASTRUCTURES_PUB.ORGANIZATION_UNITS_TBL;
    l_asset_assignment_tbl     CSI_DATASTRUCTURES_PUB.INSTANCE_ASSET_TBL;

    x_return_status		         VARCHAR2(100);
	  x_msg_count		             NUMBER;
	  x_msg_data		             VARCHAR2(2000);
	  -----l_created_manually_flag    VARCHAR2(100);
	  l_master_organization_id   NUMBER;
    l_rma_rec                  rma_rec;
	  l_instance_id              NUMBER :=NULL;
	  l_instance_party_id        NUMBER;
	  l_ip_account_id            NUMBER;
    l_location_id              NUMBER;
    l_active_date              DATE;
    -----l_inst_quantity            NUMBER;
	  P_COMMIT		               VARCHAR2(5);
	  P_INIT_MSG_LST		         VARCHAR2(500);
	  P_VALIDATION_LEVEL	       NUMBER;

  BEGIN

    l_rma_rec :=p_rma_rec;
    -- create item instance
    LOG(''); --empty row
    LOG('---CREATE_RMA_INST procedure');

    ---Get new instance_id from sequence
    SELECT CSI_ITEM_INSTANCES_S.NEXTVAL
    INTO   l_instance_id
    FROM   sys.dual;

    l_active_date := l_rma_rec.transaction_date - 1;

    ---Get location_id----
    SELECT MAX(party_site_id)
    INTO   l_location_id
    FROM   hz_party_sites
    WHERE  party_id = l_rma_rec.party_id;
    LOG('Location_id is: '||l_location_id);

    ---Get Master organization_id----
    SELECT master_organization_id
    INTO   l_master_organization_id
    FROM   mtl_parameters
    WHERE  organization_id = l_rma_rec.organization_id;

    l_instance_rec.instance_id                 :=l_instance_id;
    l_instance_rec.instance_number             :=l_instance_id;
    l_instance_rec.inventory_item_id           :=l_rma_rec.inventory_item_id;
    l_instance_rec.inv_master_organization_id  :=l_master_organization_id;
    l_instance_rec.vld_organization_id         :=l_rma_rec.organization_id;
    l_instance_rec.quantity                    :=l_rma_rec.received_quantity;
    l_instance_rec.unit_of_measure             :=l_rma_rec.order_quantity_uom;
    l_instance_rec.lot_number                  :=l_rma_rec.lot_number;
    l_instance_rec.inventory_revision          :=l_rma_rec.revision;
    l_instance_rec.accounting_class_code       :='CUST_PROD';
    l_instance_rec.instance_status_id          :=510;
    l_instance_rec.active_start_date           :=l_active_date;
    l_instance_rec.location_type_code          :='HZ_PARTY_SITES';
    l_instance_rec.location_id                 :=l_location_id;
    l_instance_rec.instance_usage_code         :='OUT_OF_ENTERPRISE';
    l_instance_rec.creation_complete_flag      :='Y';
    l_instance_rec.object_version_number       :=1;
    l_instance_rec.call_contracts              := fnd_api.g_false;
  
    ---Get new instance_party_id from sequence
    SELECT CSI_I_PARTIES_S.NEXTVAL
    INTO   l_instance_party_id
    FROM   sys.dual;

    l_party_tbl(1).instance_party_id           :=l_instance_party_id;
    l_party_tbl(1).instance_id                 :=l_instance_id;
    l_party_tbl(1).party_source_table          :='HZ_PARTIES';
    l_party_tbl(1).party_id                    :=l_rma_rec.party_id;
    l_party_tbl(1).relationship_type_code      :='OWNER';
    l_party_tbl(1).contact_flag                :='N';
    l_party_tbl(1).active_start_date           :=l_active_date;
    l_party_tbl(1).object_version_number       :=1;

    ---Get new ip_account_id from sequence
    SELECT CSI_IP_ACCOUNTS_S.NEXTVAL
    INTO  l_ip_account_id
    FROM  sys.dual;

    l_account_tbl(1).ip_account_id             :=l_ip_account_id;
    l_account_tbl(1).instance_party_id         :=l_instance_party_id;
    l_account_tbl(1).party_account_id          :=l_rma_rec.party_acct_id;
    l_account_tbl(1).relationship_type_code    :='OWNER';
    l_account_tbl(1).active_start_date         :=l_active_date;
    l_account_tbl(1).object_version_number     :=1;
    l_account_tbl(1).parent_tbl_index          :=1;
    l_account_tbl(1).call_contracts            :='N';

    l_txn_rec.transaction_date                 :=l_active_date;
    l_txn_rec.source_transaction_date          :=l_active_date;
    l_txn_rec.transaction_type_id              :=1;
    l_txn_rec.object_version_number            :=1;

    CSI_ITEM_INSTANCE_PUB.CREATE_ITEM_INSTANCE(p_api_version           => 1.0,
                                               p_commit                => P_COMMIT,
                                               p_init_msg_list         => P_INIT_MSG_LST,
                                               p_validation_level      => P_VALIDATION_LEVEL,
                                               p_instance_rec          => l_instance_rec,
                                               p_ext_attrib_values_tbl => l_ext_attrib_values,
                                               p_party_tbl             => l_party_tbl,
                                               p_account_tbl           => l_account_tbl,
                                               p_pricing_attrib_tbl    => l_pricing_attrib_tbl,
                                               p_org_assignments_tbl   => l_org_assignments_tbl,
                                               p_asset_assignment_tbl  => l_asset_assignment_tbl,
                                               p_txn_rec               => l_txn_rec,
                                               x_return_status         => x_return_status,  ---out
                                               x_msg_count             => x_msg_count,      ---out
                                               x_msg_data              => x_msg_data);      ---out

	  IF x_return_status != APPS.FND_API.G_RET_STS_SUCCESS THEN
      ------API FAILURE---------------
      LOG('Error: Create instance is FAILED.');
      LOG(APPS.FND_MSG_PUB.Get(
      p_msg_index    => APPS.FND_MSG_PUB.G_LAST,
      p_encoded      => APPS.FND_API.G_FALSE));
      RETURN;
	  ELSE
      ------INSTANCE WAS CREATED SUCCESSFULY-------------
      LOG('New instance_id='|| l_instance_id||' was created SUCCESSFULY');
      COMMIT;
      x_instance_id :=l_instance_id;
		END IF;
  END create_rma_inst;
  
  --------------------------------------------------------------------
  --  name:            create_txn_det
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  --------------------------------------------------------------------
  PROCEDURE create_txn_det ( p_ref_inst_rec IN  ref_inst_tbl, ---these instances (qty) will be updated
                             p_line_id      IN  NUMBER,
                             x_success      OUT NOCOPY BOOLEAN) IS

    l_line_rec       csi_t_datastructures_grp.txn_line_rec;
    l_line_dtl_tbl   csi_t_datastructures_grp.txn_line_detail_tbl;
    l_pty_dtl_tbl    csi_t_datastructures_grp.txn_party_detail_tbl;
    l_pty_acct_tbl   csi_t_datastructures_grp.txn_pty_acct_detail_tbl;
    l_ii_rltns_tbl   csi_t_datastructures_grp.txn_ii_rltns_tbl;
    l_oa_tbl         csi_t_datastructures_grp.txn_org_assgn_tbl;
    l_ea_tbl         csi_t_datastructures_grp.txn_ext_attrib_vals_tbl;
    l_sys_tbl        csi_t_datastructures_grp.txn_systems_tbl;

    l_sub_type_id          NUMBER;
    l_change_owner         VARCHAR2(1);
    l_internal_party_id    NUMBER;
    l_return_status  VARCHAR2(1);
    l_msg_count      NUMBER;
    l_msg_data       VARCHAR2(2000);
    l_error_message  VARCHAR2(2000);

  BEGIN

    LOG(''); --empty row
    LOG('---CREATE_TXN_DET procedure (parameter Line_id='||p_line_id||'): THE FOLLOWING INSTANCES WILL BE UPDATED');
    x_success :=TRUE;

    SELECT sub_type_id ,
           src_change_owner
    INTO   l_sub_type_id,
           l_change_owner
    FROM   csi_txn_sub_types
    WHERE  transaction_type_id = 53
    AND    default_flag        = 'Y';

    l_line_rec.transaction_line_id            := fnd_api.g_miss_num;
    l_line_rec.source_transaction_type_id     := 53;
    l_line_rec.source_transaction_id          := p_line_id;
    l_line_rec.source_transaction_table       := 'OE_ORDER_LINES_ALL';
    l_line_rec.inv_material_txn_flag          := 'Y';
    l_line_rec.object_version_number          := 1.0;

    FOR l_ind IN p_ref_inst_rec.FIRST..p_ref_inst_rec.LAST LOOP
      LOG('Instance '||l_ind||' '||p_ref_inst_rec(l_ind).instance_id||' quantity '||p_ref_inst_rec(l_ind).quantity);
      -- transaction line details table
      l_line_dtl_tbl(l_ind).transaction_line_id     := fnd_api.g_miss_num;
      l_line_dtl_tbl(l_ind).txn_line_detail_id      := fnd_api.g_miss_num;
      l_line_dtl_tbl(l_ind).sub_type_id             := l_sub_type_id;
      l_line_dtl_tbl(l_ind).instance_exists_flag    := 'Y';
      l_line_dtl_tbl(l_ind).instance_id             := p_ref_inst_rec(l_ind).instance_id;
      l_line_dtl_tbl(l_ind).source_transaction_flag := 'Y';
      l_line_dtl_tbl(l_ind).quantity                := p_ref_inst_rec(l_ind).quantity;
      l_line_dtl_tbl(l_ind).lot_number              := p_ref_inst_rec(l_ind).lot_number;
      l_line_dtl_tbl(l_ind).inventory_item_id       := p_ref_inst_rec(l_ind).inventory_item_id;
      l_line_dtl_tbl(l_ind).inv_organization_id     := p_ref_inst_rec(l_ind).organization_id;
      l_line_dtl_tbl(l_ind).unit_of_measure         := p_ref_inst_rec(l_ind).uom;
      l_line_dtl_tbl(l_ind).mfg_serial_number_flag  := 'N';
      l_line_dtl_tbl(l_ind).active_start_date       := SYSDATE; ----ISSUE
      l_line_dtl_tbl(l_ind).preserve_detail_flag    := 'Y';
      l_line_dtl_tbl(l_ind).object_version_number   := 1.0;

      IF l_change_owner = 'Y' THEN
        --------
        BEGIN
          SELECT internal_party_id
          INTO l_internal_party_id
          FROM csi_install_parameters;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
             LOG('Install Parameter is not set');
          WHEN OTHERS THEN
             LOG('Error in finding internal party');
        END;
        --------
        l_pty_dtl_tbl(l_ind).txn_party_detail_id    := fnd_api.g_miss_num;
        l_pty_dtl_tbl(l_ind).txn_line_detail_id     := fnd_api.g_miss_num;
        l_pty_dtl_tbl(l_ind).party_source_table     := 'HZ_PARTIES';
        l_pty_dtl_tbl(l_ind).party_source_id        := l_internal_party_id;
        l_pty_dtl_tbl(l_ind).relationship_type_code := 'OWNER';
        l_pty_dtl_tbl(l_ind).contact_flag           := 'N';
        l_pty_dtl_tbl(l_ind).active_start_date      := SYSDATE;
        l_pty_dtl_tbl(l_ind).preserve_detail_flag   := 'Y';
        l_pty_dtl_tbl(l_ind).txn_line_details_index := l_ind;

        BEGIN
          SELECT instance_party_id
          INTO   l_pty_dtl_tbl(l_ind).instance_party_id
          FROM   csi_i_parties
          WHERE  instance_id            = p_ref_inst_rec(l_ind).instance_id
          AND    relationship_type_code = 'OWNER';
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            l_pty_dtl_tbl(l_ind).instance_party_id := fnd_api.g_miss_num;
        END;
      END IF;
    END LOOP;
    -- API call
    CSI_T_TXN_DETAILS_GRP.CREATE_TRANSACTION_DTLS(
                    p_api_version              => 1.0,
                    p_commit                   => fnd_api.g_false,
                    p_init_msg_list            => fnd_api.g_true,
                    p_validation_level         => fnd_api.g_valid_level_full,
                    px_txn_line_rec            => l_line_rec,
                    px_txn_line_detail_tbl     => l_line_dtl_tbl,
                    px_txn_party_detail_tbl    => l_pty_dtl_tbl,
                    px_txn_pty_acct_detail_tbl => l_pty_acct_tbl,
                    px_txn_ii_rltns_tbl        => l_ii_rltns_tbl,
                    px_txn_org_assgn_tbl       => l_oa_tbl,
                    px_txn_ext_attrib_vals_tbl => l_ea_tbl,
                    px_txn_systems_tbl         => l_sys_tbl,
                    x_return_status            => l_return_status,
                    x_msg_count                => l_msg_count,
                    x_msg_data                 => l_msg_data);

    LOG('Instance(s) reference is updated to installation detail');

    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      ----API ERROR
      LOG ('error in create transaction dtls');
      l_error_message := csi_t_gen_utility_pvt.dump_error_stack;
      LOG (l_error_message);
      x_success :=FALSE;
    ELSE
      LOG('Transactional Details were created SUCCESSFULY by API');
    END IF;
    COMMIT;

  END create_txn_det;

  --------------------------------------------------------------------
  --  name:            get_instances
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  --------------------------------------------------------------------
  PROCEDURE get_instances(p_rma_rec                    IN  rma_rec,
                          p_create_instance            IN  VARCHAR2,
                          p_parent_instance_id         IN  NUMBER, ---printer instance
                          p_error_interface_header_id  IN  NUMBER,
                          x_ref_inst_rec               OUT NOCOPY ref_inst_tbl,
                          x_got_insts                  OUT NOCOPY BOOLEAN ) IS
   
    l_rma_rec           rma_rec;
    l_ref_inst_rec      ref_inst_tbl;

    l_inst               NUMBER;
    l_instance_id        NUMBER;
    l_instance_qty       NUMBER;
    l_remained_qty       NUMBER;
    l_inst_remained_qty  NUMBER;
    l_max_txn_date       DATE;
    skip_error           EXCEPTION;
    /* ---original Oracle cursor
      CURSOR inst_cur(p_item_id               IN NUMBER,
                   p_owner_pty_id          IN NUMBER,
                   p_owner_acct_id         IN NUMBER,
                   p_lot_number            IN VARCHAR2,
                   p_rma_transaction_date  IN DATE) IS
      SELECT cii.instance_id,
             cii.quantity
      FROM   CSI_ITEM_INSTANCES cii
      WHERE  cii.inventory_item_id      = p_item_id
      AND    cii.accounting_class_code  = 'CUST_PROD'
      AND   (cii.instance_usage_code    = 'OUT_OF_ENTERPRISE'
      OR     cii.instance_usage_code    = 'IN_RELATIONSHIP')
      AND    cii.owner_party_id         = p_owner_pty_id
      AND    cii.owner_party_account_id = p_owner_acct_id
      AND    NVL(cii.lot_number, '-99') = NVL(p_lot_number, '-99')
      AND    SYSDATE BETWEEN NVL(cii.active_start_date, SYSDATE-1) AND NVL(cii.active_end_date, SYSDATE+1) 
      AND    cii.active_start_date < p_rma_transaction_date
    ORDER BY cii.active_start_date;*/
    
    CURSOR inst_cur(p_item_id                IN NUMBER,
                    p_owner_pty_id           IN NUMBER,
                    p_owner_acct_id          IN NUMBER,
                    p_parent_inst_id         IN NUMBER,
                    p_error_interf_header_id IN NUMBER) IS
      SELECT  INSTANCE_ID,
              INSTANCE_RANK,            
              INVENTORY_ITEM_ID,
              ITEM,
              ORGANIZATION_ID,
              QUANTITY,
              UOM,
              'Unassigned Instance'  DESCRIPTION 
      FROM TABLE(XXCS_ITEM_INSTANCE_PKG.get_unassigned_instance(p_owner_pty_id,
                                                                p_owner_acct_id,
                                                                p_item_id,
                                                                p_error_interf_header_id))
      UNION ALL
      SELECT  INSTANCE_ID,
              (INSTANCE_RANK+1000)   INSTANCE_RANK,            
              INVENTORY_ITEM_ID,
              ITEM,
              ORGANIZATION_ID,
              QUANTITY,
              UOM,
              'Child Instance From Hierarchy'  DESCRIPTION  
      FROM TABLE(XXCS_ITEM_INSTANCE_PKG.get_child_inst_from_hierarchy(p_parent_inst_id,
                                                                      p_item_id,
                                                                      p_error_interf_header_id))
      ORDER BY 2; ---instance rank  (unassigned_instance first...)                 
  BEGIN
    LOG(''); --empty row
    LOG('---GET_INSTANCES procedure');
    ----l_create_instance := p_create_instance;
    l_rma_rec   := p_rma_rec;
    x_got_insts := TRUE;
    l_inst      := 0;

    l_instance_id  := NULL;
    l_instance_qty := 0;
    l_remained_qty := l_rma_rec.ordered_quantity;  ---SO line ordered qty

    IF l_remained_qty = 0 THEN
      LOG('---GET INSTANCES procedure--ERROR--STOP PROCESS: RMA order line has 0 ordered quantity');
      RAISE skip_error;
    END IF;

    FOR inst_rec IN inst_cur(p_item_id                => l_rma_rec.inventory_item_id,
                             p_owner_pty_id           => l_rma_rec.party_id,
                             p_owner_acct_id          => l_rma_rec.party_acct_id,
                             p_parent_inst_id         => p_parent_instance_id,
                             p_error_interf_header_id => p_error_interface_header_id ) LOOP
                             
      LOG('---'||inst_rec.description||' instance_id='||inst_rec.instance_id||
                 ' (instance qty='||inst_rec.quantity||
                 ') was found for inv_item_id='||l_rma_rec.inventory_item_id||
                 ' ('''||inst_rec.item||
                 '''), owner party_id='||l_rma_rec.party_id||
                 ', owner party account_id='||l_rma_rec.party_acct_id );
      SELECT MAX(transaction_date)
      INTO   l_max_txn_date
      FROM   csi_inst_transactions_v
      WHERE  instance_id = inst_rec.instance_id;

	    LOG('Max transaction_date='||to_char(l_max_txn_date,'DD-MON-YYYY')||' from csi_inst_transactions_v table');

      IF l_max_txn_date < l_rma_rec.transaction_date THEN
        l_instance_qty:= inst_rec.quantity;
        l_instance_id :=inst_rec.instance_id;
        LOG('Remained_qty'||l_remained_qty||' (default...Sales Order line ordered_quantity');

		    IF l_remained_qty > 0 THEN ---SO line ordered qty
          LOG('Remained_qty>0');
		      l_inst_remained_qty := INST_REMAINED_QTY(l_instance_id); ---from cache plsql TABLE
		      IF l_inst_remained_qty > 0 OR l_inst_remained_qty = -99 THEN
            IF l_inst_remained_qty > 0 THEN
              LOG('Instance is cached and has remained quantity '|| l_inst_remained_qty );
              l_instance_qty := l_inst_remained_qty;
            END IF;
            IF l_inst_remained_qty = -99 THEN
              LOG('Instance '||l_instance_id||' with quantity '||l_instance_qty||' has not been used');
              l_inst_remained_qty := l_instance_qty;
            END IF;
            LOG('RMA Remained Qty '||l_remained_qty);
            IF l_instance_qty >= l_remained_qty THEN  ---Inst qty > SO line ordered qty
              ---You can update install base (No Qty problem..)
              LOG('Instance remained qty >= needed quantity');
              l_inst := l_inst + 1;
              l_ref_inst_rec(l_inst).instance_id      :=l_instance_id;
              l_ref_inst_rec(l_inst).inventory_item_id:=l_rma_rec.inventory_item_id;
              l_ref_inst_rec(l_inst).organization_id  :=l_rma_rec.organization_id;
              l_ref_inst_rec(l_inst).quantity         :=l_remained_qty;  ---SO line ordered qty 
              l_ref_inst_rec(l_inst).lot_number       :=l_rma_rec.lot_number;
              l_ref_inst_rec(l_inst).uom              :=l_rma_rec.order_quantity_uom;
              l_inst_remained_qty                     := l_inst_remained_qty - l_remained_qty ;
              l_remained_qty := 0;
              LOG('Update cached quantity with '||l_inst_remained_qty);
              CACHE_INSTANCE_ID(l_instance_id, l_inst_remained_qty);
            ELSE
              ---You cannot update install base (Qty problem..) without instance creation...
              LOG('Instance remained qty < needed quantity');
              l_inst := l_inst + 1;
              l_ref_inst_rec(l_inst).instance_id :=l_instance_id;
              l_ref_inst_rec(l_inst).inventory_item_id :=l_rma_rec.inventory_item_id;
              l_ref_inst_rec(l_inst).organization_id :=l_rma_rec.organization_id;
              l_ref_inst_rec(l_inst).quantity :=l_instance_qty;  ---Remain qty from PLSQL table
              l_ref_inst_rec(l_inst).lot_number :=l_rma_rec.lot_number;
              l_ref_inst_rec(l_inst).uom :=l_rma_rec.order_quantity_uom;
              l_remained_qty := l_remained_qty - l_instance_qty;  --missing qty for SO line (SO ordered qty - instance_qty)
              l_inst_remained_qty :=0;
              CACHE_INSTANCE_ID(l_instance_id, l_inst_remained_qty);
            END IF;
			    END IF;
		    ELSE
          LOG('Error: SO line ordered qty='||l_remained_qty);
          EXIT;
		    END IF;
      END IF;
    END LOOP;

    IF l_remained_qty > 0 THEN -- Missing qty for SO line
      IF p_create_instance = 'Y' THEN
        l_inst :=l_inst + 1;
        LOG('---RMA remained_quantity='|| l_remained_qty||' -- No instance or Use up all existing instances, CREATE REMAINED ');
        l_rma_rec.ordered_quantity := l_remained_qty; -- Missing qty for SO line
        -----Create new instance with qty=Missing qty for SO line
        CREATE_RMA_INST(p_rma_rec     =>l_rma_rec,
                        x_instance_id =>l_instance_id);
        IF l_instance_id IS NULL THEN
          ----INSTANCE CREATION ERROR
          RAISE skip_error;
        ELSE
          LOG('New Instance '||l_instance_id||' was created with quantity '||l_remained_qty);
          l_ref_inst_rec(l_inst).instance_id       :=l_instance_id;
          l_ref_inst_rec(l_inst).inventory_item_id :=l_rma_rec.inventory_item_id;
          l_ref_inst_rec(l_inst).organization_id   :=l_rma_rec.organization_id;
          l_ref_inst_rec(l_inst).quantity          :=l_remained_qty;
          l_ref_inst_rec(l_inst).lot_number        :=l_rma_rec.lot_number;
          l_ref_inst_rec(l_inst).uom               :=l_rma_rec.order_quantity_uom;
          l_inst_remained_qty :=0;
          CACHE_INSTANCE_ID(l_instance_id, l_inst_remained_qty);          
        END IF;
      ELSE
        LOG('Parameter p_create_instance=''N''');
        RAISE skip_error;
      END IF;
    END IF;

    x_ref_inst_rec :=l_ref_inst_rec;  --PLSQL table with instances to be used (include New Created Instance...)

  EXCEPTION
    WHEN skip_error THEN
      x_got_insts := FALSE;
  END get_instances ;

  --------------------------------------------------------------------
  --  name:            nsr_rma_fix   - MAIN PROCEDURE
  --  create by:       Vitaly K.
  --  Revision:        1.0 
  --  creation date:   30/05/2010 
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  30/05/2010  Vitaly K.       initial build
  --------------------------------------------------------------------
  PROCEDURE nsr_rma_fix(errbuf            OUT NOCOPY VARCHAR2,
                        retcode           OUT NOCOPY NUMBER,
                        p_batch_number    IN  NUMBER,
                        p_create_instance IN  VARCHAR2)   IS
    l_errbuf               VARCHAR2(2000);
    l_error_message        VARCHAR2(2000);
    l_retcode              NUMBER;
    l_processed_flag       VARCHAR2(1);
    l_batch_number         NUMBER;
    l_create_instance      VARCHAR2(1);
    l_record_found         BOOLEAN :=TRUE;
    l_got_insts            BOOLEAN :=TRUE;
    l_success              BOOLEAN :=TRUE;
    --
    skip_error             EXCEPTION;
    --
    l_inventory_item_id    NUMBER;
    l_item                 VARCHAR2(1000);
    l_organization_id      NUMBER;
    l_serial_code          NUMBER;
    l_lot_code             NUMBER;
    l_line_id              NUMBER;
    l_transaction_line_id  NUMBER;
    --
    l_rma_rec              rma_rec;
    l_ref_inst_rec         ref_inst_tbl;
    --
	  l_lot_number           VARCHAR2(30);

    ---------MAIN CURSOR-----(get "batch" of oldest errors)----------
    CURSOR rma_error_cur (p_batch_num NUMBER) IS
      SELECT ERRORS_TAB.org_id,
             ERRORS_TAB.operating_unit,
             ERRORS_TAB.party_id         owner_party_id,
             ERRORS_TAB.cust_account_id  owner_party_account_id,
             ERRORS_TAB.party_name,
             ERRORS_TAB.party_number,
             ERRORS_TAB.header_id,          --Sales Order header_id
             ERRORS_TAB.order_number,
             ERRORS_TAB.inventory_item_id,  --Sales Order line item_id
             ERRORS_TAB.item,
             ERRORS_TAB.item_description,
             ERRORS_TAB.incident_id,
             ERRORS_TAB.incident_number,
             ERRORS_TAB.printer_instance_id, ---PRINTER
             ERRORS_TAB.transaction_error_id,
             ERRORS_TAB.errors_rank,
             ERRORS_TAB.inv_material_transaction_id,
             ERRORS_TAB.error_text,
             ERRORS_TAB.creation_date
      FROM  (SELECT  oh.org_id,
                     ou.name                 operating_unit,
                     hp.party_id,
                     ca.cust_account_id,
                     hp.party_name,
                     hp.party_number,
                     oh.header_id,
                     oh.order_number,
                     ol.inventory_item_id,
                     msi.segment1            item,
                     msi.description         item_description,
                     sr.incident_id,
                     sr.incident_number,
                     sr.instance_id          printer_instance_id, ---PRINTER
                     sr.owner_party_id,       ---current_instance_owner,
                     sr.owner_party_account_id, 
                     cte.transaction_error_id,
                     DENSE_RANK() OVER (ORDER BY cte.transaction_error_id  NULLS LAST)  errors_rank,   --oldest will be first
                     cte.inv_material_transaction_id,
                     cte.error_text,
                     cte.creation_date
             FROM    CSI_TXN_ERRORS        cte,
                     OE_ORDER_HEADERS_ALL  oh,
                     OE_ORDER_LINES_ALL    ol,
                     MTL_SYSTEM_ITEMS_B    msi,
                     HR_OPERATING_UNITS    ou,
                     HZ_CUST_ACCOUNTS      ca,
                     HZ_PARTIES            hp,
                    (SELECT a.incident_id,
                            to_char(a.incident_number)   incident_number,
                            7    order_source_id,
                            a.customer_product_id        instance_id,
                            cii.owner_party_id,
                            cii.owner_party_account_id
                     FROM   CS_INCIDENTS_ALL_B   a,
                            CSI_ITEM_INSTANCES   cii
                     WHERE  a.customer_product_id=cii.instance_id)     sr
             WHERE cte.processed_flag IN ('E', 'R')
             AND cte.transaction_type_id = 53   -----cte.error_text LIKE '%Installation Detail%'
             AND cte.inv_material_transaction_id IS NOT NULL
             AND cte.serial_number IS NULL
             AND cte.source_header_ref_id=oh.header_id
             AND cte.source_line_ref_id=ol.line_id
             AND oh.header_id=ol.header_id
             AND ol.inventory_item_id=msi.inventory_item_id
             AND msi.organization_id=91 ---Master
             AND oh.org_id=ou.organization_id
             AND oh.sold_to_org_id=ca.cust_account_id
             AND ca.party_id=hp.party_id
             AND oh.orig_sys_document_ref=sr.incident_number(+)
             AND oh.order_source_id      =sr.order_source_id(+)
                                   ) ERRORS_TAB
      WHERE ERRORS_TAB.errors_rank <= p_batch_num  -- take p_batch_num oldest to newest error lines   
      ORDER BY  ERRORS_TAB.errors_rank;

  BEGIN
    l_batch_number :=p_batch_number;

    IF p_batch_number IS NULL THEN
     l_batch_number := 100;
    END IF;

    l_create_instance := p_create_instance;

    IF l_create_instance IS NULL THEN
     l_create_instance :='N' ;
    END IF;

    LOG('------------PARAMETERS-------------------------------------');
    LOG('============parameter Batch Number   : '||p_batch_number);
    LOG('============parameter Create Instance: '||p_create_instance);
    LOG('-----------------------------------------------------------');
    LOG('');  ---empty row
   
    FOR rma_error_rec IN rma_error_cur (l_batch_number) LOOP

      l_processed_flag := 'N';
      ---Show current error details
      LOG('');  ---empty row
      LOG('====================================================================================================================');  
      LOG('====================================================================================================================');
      LOG('==== WE ARE STARTING WITH ERROR: '||rma_error_rec.error_text); 
      LOG('INVENTORY MATERIAL TRANSACTION ID: '||rma_error_rec.inv_material_transaction_id);
      LOG('Transaction Error Id: '||rma_error_rec.transaction_error_id);
      LOG('Operating Unit: '||rma_error_rec.operating_unit||' ('||rma_error_rec.org_id||')');
      LOG('Sales Order Customer: '||rma_error_rec.party_name||', party_number='||rma_error_rec.party_number||', party_id='||rma_error_rec.owner_party_id);
      LOG('Sales Order: '||rma_error_rec.order_number||', header_id='||rma_error_rec.header_id);
      LOG('Item: '||rma_error_rec.item||'  '||rma_error_rec.item_description||', inv_item_id='||rma_error_rec.inventory_item_id);
      LOG('SR: '||rma_error_rec.incident_number||', incident_id='||rma_error_rec.incident_id);
      LOG('Printer instance_id: '||rma_error_rec.printer_instance_id);
      LOG('Printer owner party_id: '||rma_error_rec.owner_party_id);
      LOG('Printer owner party_acct_id: '||rma_error_rec.owner_party_account_id);
      LOG('Error text: '||rma_error_rec.error_text);
      LOG('Error creation date: '||to_char(rma_error_rec.creation_date,'DD-MON-YYYY'));  
      LOG('');  ---empty row

	    BEGIN
        -----Check if item is still non-serialized control 
        -----Non Serialized items ONLY will be processed in this concurrent
        BEGIN 
          SELECT mmt.inventory_item_id,
                 msi.segment1,
                 mmt.organization_id,
                 msi.serial_number_control_code,
                 msi.lot_control_code,
                 mmt.trx_source_line_id
          INTO   l_inventory_item_id,
                 l_item,
                 l_organization_id,
                 l_serial_code,
                 l_lot_code,
                 l_line_id
          FROM   MTL_SYSTEM_ITEMS          msi,
                 MTL_MATERIAL_TRANSACTIONS mmt
          WHERE  mmt.transaction_id        = rma_error_rec.inv_material_transaction_id
          AND    mmt.inventory_item_id     = msi.inventory_item_id
          AND    mmt.organization_id       = msi.organization_id;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            LOG('----No Material Transaction found in MTL_MATERIAL_TRANSACTIONS table for this inv_material_transaction_id');
            RAISE skip_error;
          WHEN TOO_MANY_ROWS THEN
            LOG('----Too many rows found in MTL_MATERIAL_TRANSACTIONS table for this inv_material_transaction_id');
            RAISE skip_error;
        END;

	      IF l_serial_code = 1  THEN
          ----- This is Non-Serialized item  (Non Serialized items ONLY will be processed in this concurrent)
          LOG('-----This is Non-Serialized item '''||l_item||''', Sales Order Line_id: '||l_line_id);
          	       
          -- check for existance of txn details
          BEGIN
            SELECT transaction_line_id
            INTO   l_transaction_line_id
            FROM   csi_t_transaction_lines
            WHERE  source_transaction_table = 'OE_ORDER_LINES_ALL'
            AND    source_transaction_id    = l_line_id  ----Sales Order line_id  (MTL_MATERIAL_TRANSACTIONS.trx_source_line_id)
            AND    source_transaction_type_id = 53;

            LOG('---CLEAN INTERFACE TABLES: Installation Details (for Error Interface) already exists for this Sales Order Line_id='||l_line_id);
            CLEAN_INST_DETAIL(p_line_id => l_line_id); 

          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              LOG('----Installation Details (for Error Interface) Not Exists for this Sales Order Line_id='||l_line_id);
            WHEN OTHERS THEN
              LOG('---CLEAN INTERFACE TABLES: Installation Details (for Error Interface) already exists for this Sales Order Line_id='||l_line_id);
              CLEAN_INST_DETAIL(p_line_id => l_line_id);
          END;

          IF l_lot_code = 2 THEN
            --------
            LOG('---Item is lot control item');
            BEGIN
                SELECT lot_number
                  INTO l_lot_number
                 FROM mtl_transaction_lot_numbers
                WHERE transaction_id = rma_error_rec.inv_material_transaction_id;
                LOG('---Lot number='||l_lot_number||' was found in MTL_TRANSACTION_LOT_NUMBERS for this inv_material_transaction_id='||rma_error_rec.inv_material_transaction_id);
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  LOG('---Item is lot control now, cannot find lot number in MTL_TRANSACTION_LOT_NUMBERS for this inv_material_transaction_id='||rma_error_rec.inv_material_transaction_id);
                  RAISE skip_error;
             WHEN TOO_MANY_ROWS THEN
                  LOG('---More than one lot number in this txn_id, skip');
                  RAISE skip_error;
            END;
            ---------
          ELSE
            l_lot_number :=NULL;
          END IF;

          ----Get REQUESTED item and qty from SO line ...and received qty from mat trans.
          GET_RMA_REC(p_inv_mtl_txn_id => rma_error_rec.inv_material_transaction_id,
                      p_lot_number     => l_lot_number,
                      x_rma_rec        => l_rma_rec,          ---out
                      x_record_found   => l_record_found);    ---out

          IF NOT(l_record_found) THEN
            LOG('---GET_RMA_REC not found');
            RAISE skip_error;
          END IF;

			    GET_INSTANCES(p_rma_rec                   => l_rma_rec,
			                  p_create_instance           => l_create_instance,
							          p_parent_instance_id        => rma_error_rec.printer_instance_id, ---printer instance
                        p_error_interface_header_id => rma_error_rec.header_id,
                        x_ref_inst_rec              => l_ref_inst_rec,  ---out  --PLSQL table with instances to be used (include New Created Instance...)
							          x_got_insts                 => l_got_insts);    ---out

			    IF NOT(l_got_insts) THEN
            ----previous proc GET_INSTANCES Error
            LOG('---GET_INSTANCES not found');
            RAISE skip_error;
			    END IF;

          ----Prepare fixed data for Open Interface (..may be ..."Resubmit Interface Process" (param=ALL)...)
          CREATE_TXN_DET(p_ref_inst_rec =>l_ref_inst_rec,  --PLSQL table with instances to be used (include New Created Instance...)
                        p_line_id      =>l_line_id,
                        x_success      =>l_success);

          IF NOT(l_success) THEN
            LOG('---CREATE_TXN_DET FAILURE');
            RAISE skip_error;
          END IF;

			    l_processed_flag := 'Y';
	      ELSE
          LOG('---STOP PROCESS FOR THIS ERROR RECORD: This is SERIALIZED ITEM '''||l_item||''', Sales Order Line_id: '||l_line_id);
		    END IF;

        IF l_processed_flag = 'Y' THEN
          UPDATE csi_txn_errors
          SET    processed_flag = 'R'
          WHERE  transaction_error_id = rma_error_rec.transaction_error_id;
          LOG('Update CSI_TXN_ERRORS SET processed_flag = ''R'' where transaction_error_id='||rma_error_rec.transaction_error_id);
        END IF;

        COMMIT;

	    EXCEPTION
        WHEN skip_error THEN
	        LOG('Some errors happened cannot process this ID '||rma_error_rec.inv_material_transaction_id);
	    END;

    END LOOP;

    -----"Resubmit Interface Process" (param=ALL)  , conc short name "CSIRSUBI" , appl - Install base
    LOG('');  ---empty row
    LOG('---CSI_RESUBMIT_PUB.RESUBMIT_INTERFACE   (instance transaction details will be processed)');
    CSI_RESUBMIT_PUB.RESUBMIT_INTERFACE(errbuf    => l_errbuf,
                                        retcode   => l_retcode,
                                        p_option  => 'SELECTED');

  EXCEPTION
    WHEN OTHERS THEN
      l_error_message:=substr('Unexpected error in XXCSI_NSRL_RMA_PKG.nsr_rma_fix : '||SQLERRM,1,200);
      LOG(l_error_message);
      errbuf :=l_error_message;
      retcode:=2; 
  END nsr_rma_fix;
  ------------------------------------------------------

END XXCSI_NSRL_RMA_PKG;
/

