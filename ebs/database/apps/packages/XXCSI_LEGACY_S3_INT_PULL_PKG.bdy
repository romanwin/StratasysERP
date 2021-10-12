CREATE OR REPLACE PACKAGE BODY xxcsi_legacy_s3_int_pull_pkg IS
--
--
--===================================================================================
 --  name:            xxcsi_legacy_s3_int_pull_pkg
 --  create by:       TCS
 --  Revision:        1.0
 --  creation date:   18/08/2016
 ----------------------------------------------------------------------------
 --  purpose :        Package for creation of instance and relationship( configuration)
 --                   copied from legacy to S3
  ----------------------------------------------------------------------------
 --  ver  date        name                  desc
 --  1.0  18/08/2016  vishal(TCS)           Initial build
 --===================================================================================
--
--
PROCEDURE log_msg (
   p_msg        IN  VARCHAR2,
   p_debug      IN  VARCHAR2
   )
-- +===================================================================+
-- | Procedure  Name  : log_message                                    |
-- |                                                                   |
-- | Description      : This procedure is used to write messages to    |
-- |                    log.                                           |
-- |                                                                   |
-- | Parameters       : p_msg
--	|				  p_debug                                         |
-- |                                                                   |
-- |                                                                   |
-- +===================================================================+
IS
BEGIN
 IF UPPER(p_debug)='Y' THEN
  apps.Fnd_File.Put_Line (apps.Fnd_File.Log, p_msg);
  END IF;
END;
--
--
PROCEDURE out_msg (
   p_msg        IN  VARCHAR2
   )
 -- +===================================================================+
 -- | Procedure  Name  : out_message                                    |
 -- |                                                                   |
 -- | Description      : This procedure is used to write messages to    |
 -- |                    output.                                        |
 -- |                                                                   |
 -- | Parameters       : p._msg                                          |
 -- |                                                                   |
 -- |                                                                   |
 -- +===================================================================+
IS
BEGIN
  apps.Fnd_File.Put_Line(apps.Fnd_File.Output,p_msg);
  --log_mSG ('OUTPUT: '||p_msg,'Y');
END;
--
--===================================================================================
 --  name:            procedure: instance_report
 --  create by:       TCS
 --  Revision:        1.0
 --  creation date:   26/08/2016
 ----------------------------------------------------------------------------
 --  purpose :        procedure to create Instance Report
  ----------------------------------------------------------------------------
 --  ver  date        name                  desc
 --  1.0  18/08/2016  vishal(TCS)           Initial build
 --===================================================================================
 --
 --
PROCEDURE instance_report
IS

  CURSOR c_inst_pr_day
  IS
      SELECT XII.S3_ID            INSTANCE_ID ,
            MSI_1.SEGMENT1        ITEM,
            CII_1.SERIAL_NUMBER   SERIAL_NUM,
            XII.ATTRIBUTE3        MASTER_INSTANCE_ID,
            CII_2.SERIAL_NUMBER   MAST_SERIAL_NUM,
            MSI_2.SEGMENT1        MASTR_ITEM,
            XII.LEGACY_ID         LEGACY_ID,
            XII.ATTRIBUTE4        PARENT_LEGACY_ID,
            XII.ATTRIBUTE2        RELATIONSHIP_ID,
            XII.CREATE_DATE
     FROM XXCREF_CS_IB_ITEM_INSTANCE XII,
          MTL_SYSTEM_ITEMS_B         MSI_1,
          MTL_SYSTEM_ITEMS_B         MSI_2,
          CSI_ITEM_INSTANCES         CII_1,
          CSI_ITEM_INSTANCES         CII_2
    WHERE  XII.S3_ID                  = CII_1.INSTANCE_ID
    AND CII_1.INVENTORY_ITEM_ID       = MSI_1.INVENTORY_ITEM_ID
    AND CII_1.LAST_VLD_ORGANIZATION_ID= MSI_1.ORGANIZATION_ID
    AND XII.ATTRIBUTE3                = CII_2.INSTANCE_ID
    AND MSI_2.INVENTORY_ITEM_ID       = CII_2.INVENTORY_ITEM_ID
   AND CII_2.LAST_VLD_ORGANIZATION_ID = MSI_2.ORGANIZATION_ID
   AND TRUNC(CREATE_DATE)             = TRUNC(SYSDATE);
   --
   l_inst_rec c_inst_pr_day%ROWTYPE;
   --
BEGIN
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'<html><head>');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'<style type="text/css">');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'* { margin: 0; padding: 0;}');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'.all { width: 100%; border: 1px solid#000000;}');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'.title {width: 99%; }');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'table {width: 100%; border: 1px solid#FF00FF; border-collapse: collapse; table-layout:fixed; }');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'table tr th { border: 1px solid #FF00FF;overflow: hidden; word-break: break-all; text-overflow: ellipsis; white-space: nowrap;}');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'table tr td { border: 1px solid #FF00FF;overflow: hidden; /*word-wrap: break-word; Content will wrap in a boundary*/word-break: break-all;');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'text-overflow: ellipsis; white-space:nowrap;}');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'.content {width: 100%; height: 80%;overflow: scroll; }');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'.content div { width: 100%; }</style>');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'</head><body><div class="all">');
   apps.fnd_file.put_line(apps.fnd_file.output,'<div class="title"><table><tr>');
   apps.fnd_file.put_line(apps.fnd_file.output,'<thstyle="width:30%">INSTANCE ID</th>');
   apps.fnd_file.put_line(apps.fnd_file.output,'<thstyle="width:20%">ITEM</th>');
   apps.fnd_file.put_line(apps.fnd_file.output,'<thstyle="width:20%">SERIAL_NUM</th>');
   apps.fnd_file.put_line(apps.fnd_file.output,'<thstyle="width:10%">MASTER_INSTANCE_ID</th>');
   apps.fnd_file.put_line(apps.fnd_file.output,'<thstyle="width:10%">MAST_SERIAL_NUM</th>');
   apps.fnd_file.put_line(apps.fnd_file.output,'<thstyle="width:10%">MASTR_ITEM</th> ');
   apps.fnd_file.put_line(apps.fnd_file.output, '</tr></table></div>');
   apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'<div class="content"><div><table>');
  OPEN c_inst_pr_day;
  LOOP
	FETCH c_inst_pr_day  INTO l_inst_rec;
  EXIT
  WHEN c_inst_pr_day%notfound;
    apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT, '<tr>');
    apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'<td style="width:20%">' || l_inst_rec.INSTANCE_id|| '</td>');
    apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'<td style="width:20%">' || l_inst_rec.ITEM|| '</td>');
    apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'<td style="width:20%">' || l_inst_rec.SERIAL_NUM|| '</td>');
    apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'<td style="width:10%">' || l_inst_rec.MASTER_INSTANCE_ID|| '</td>');
    apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'<td style="width:10%">' || l_inst_rec.MAST_SERIAL_NUM|| '</td>');
	apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'<td style="width:20%">' || l_inst_rec.MASTR_ITEM|| '</td>');
    apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT,'<td style="width:10%">&nbsp;</td>');
    apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT, '</tr>');
  end loop;
  CLOSE c_inst_pr_day;
  apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT, '</table></div></div>');
  apps.Fnd_File.Put_line(apps.FND_FILE.OUTPUT, '</body></HTML>');
END;
--
--
--
--
--===================================================================================
 --  name:            procedure: pull_instance
 --  create by:       TCS
 --  Revision:        1.0
 --  creation date:   18/08/2016
 ----------------------------------------------------------------------------
 --  purpose :        procedure to Create instance and relationship for Interim Solution
  ----------------------------------------------------------------------------
 --  ver  date        name                  desc
 --  1.0  18/08/2016  vishal(TCS)           Initial build
 --===================================================================================
 --
 --
PROCEDURE pull_instance( p_errbuf      OUT VARCHAR2,
							p_retcode    OUT NUMBER,
							p_batch_size IN NUMBER,
              P_DEBUG IN VARCHAR2
						 )

   IS
    -- Local Variable Declaration .
    l_num_user_id           NUMBER 				:= fnd_global.user_id;
    l_num_responsibility_id NUMBER 				:= fnd_global.resp_id;
    l_num_applicaton_id     NUMBER 				:= fnd_global.resp_appl_id;
    l_conc_request_id       NUMBER 				:= fnd_global.conc_request_id;
    l_var_start_time        VARCHAR2(30);
    l_var_error_code        VARCHAR2(30);
    l_var_error_msg         VARCHAR2(2000);
    l_var_database          VARCHAR2(30);
    l_return_status         VARCHAR2(255) 		:= 'N';
    l_msg_count             NUMBER(22);
    l_msg_data              VARCHAR2(255);
    l_error_msg             VARCHAR2(4000);
    l_party_id              NUMBER(22);
    l_val_flag_itm          VARCHAR2(5) 		:='N';
    l_val_flag_rel          VARCHAR2(5) 		:='N';
	--Record type for instance variables
    l_csi_inst_rec 		      csi_datastructures_pub.instance_rec;
    l_csi_ext_attrib_rec    csi_datastructures_pub.extend_attrib_values_rec;
    l_csi_party_rec         csi_datastructures_pub.party_rec;
    l_csi_party_accnt_rec   csi_datastructures_pub.party_account_rec;
    l_csi_trx_rec           csi_datastructures_pub.transaction_rec;
    l_party_tbl             csi_datastructures_pub.party_tbl;
    --
	
	
	--Record type for instance variables Master Instance -- Added on 15/12/2016
	l_csi_inst_rec_mstr        		  csi_datastructures_pub.instance_rec;
	l_csi_inst_rec_mstr_null   		  csi_datastructures_pub.instance_rec;
    l_ext_attrib_values_mstr          csi_datastructures_pub.extend_attrib_values_tbl;
    l_ext_attrib_values_mstr_null     csi_datastructures_pub.extend_attrib_values_tbl;
    l_party_tbl_mstr                  csi_datastructures_pub.party_tbl;
    l_party_tbl_mstr_null             csi_datastructures_pub.party_tbl;
	l_account_tbl_mstr                csi_datastructures_pub.party_account_tbl;
    l_account_tbl_mstr_null           csi_datastructures_pub.party_account_tbl;
	l_pric_attrib_tbl_mstr            csi_datastructures_pub.pricing_attribs_tbl;
    l_pric_attrib_tbl_mstr_null       csi_datastructures_pub.pricing_attribs_tbl;
	l_org_assig_tbl_mstr        	  csi_datastructures_pub.organization_units_tbl;
    l_org_assig_tbl_mstr_null         csi_datastructures_pub.organization_units_tbl;
	l_asset_assig_tbl_mstr            csi_datastructures_pub.instance_asset_tbl;
    l_asset_assig_tbl_mstr_null       csi_datastructures_pub.instance_asset_tbl;
	l_txn_rec_mstr                    csi_datastructures_pub.transaction_rec;
    l_txn_rec_mstr_null               csi_datastructures_pub.transaction_rec;
	l_instance_id_lst_mstr            csi_datastructures_pub.id_tbl;
    l_instance_id_lst_mstr_null       csi_datastructures_pub.id_tbl;
	
	
    -- Table type Variable for relationship
    l_inst_rel_tbl          csi_datastructures_pub.ii_relationship_tbl;
    l_trx_rel_rec           csi_datastructures_pub.transaction_rec;
    --
    p_commit                VARCHAR2 (5);
    -- Master Item
    --
    l_mstr_instace_rec      csi_item_instances%ROWTYPE;
    l_child_item_id         mtl_system_items_b.inventory_item_id%TYPE;
    l_re_relation_flag      VARCHAR2(1) :='N';
    -- For Transaction details
    l_rel_trx_date          csi_inst_transactions_v.transaction_date%TYPE;
    l_rel_trx_typ_id        csi_inst_transactions_v.transaction_type_id%TYPE;
    --
    x_instance_id           csi_item_instances.instance_id%TYPE;
    l_rel_instance_id_out   csi_ii_relationships.relationship_id%TYPE;
    l_rel_instance_id       csi_item_instances.instance_id%TYPE;
    l_ch_instance_id        csi_item_instances.instance_id%TYPE;
    l_instace_rec           csi_item_instances%rowtype;            /* Record type to get the master instance detail*/
    l_count1                NUMBER;
    l_prog_error_msg        VARCHAR2(4000) 		:= NULL;
    x_return_status         varchar2(255) 		:='N';
    x2_return_status        VARCHAR2(1) 		  :='S';
    x2_err_msg              VARCHAR(4000) 		:= NULL;
    x_msg_count             NUMBER;
    x_msg_data              VARCHAR2(255);
    l_object_version_number NUMBER;
    --
    l_act_xref_cnt          VARCHAR2(1)       :='S';
    l_act_evnt_cnt          VARCHAR2(1)       :='S';
	-- Added on 15/12/2016 for DFF of Master Instancs -- Start
	l_segment1_mstr			mtl_system_items_b.segment1%TYPE;
	l_inv_item_id_mstr		mtl_system_items_b.inventory_item_id%TYPE;
	l_attribute1_m			csi_item_instances.attribute1%TYPE;
	l_attribute2_m			csi_item_instances.attribute2%TYPE;
	l_attribute3_m			csi_item_instances.attribute3%TYPE;
	l_attribute4_m			csi_item_instances.attribute4%TYPE;
	l_attribute5_m			csi_item_instances.attribute5%TYPE;
	l_attribute6_m			csi_item_instances.attribute6%TYPE;
	l_attribute7_m			csi_item_instances.attribute7%TYPE;
	l_attribute8_m			csi_item_instances.attribute8%TYPE;
	l_attribute9_m			csi_item_instances.attribute9%TYPE;
	l_attribute10_m			csi_item_instances.attribute10%TYPE;
	l_attribute11_m			csi_item_instances.attribute11%TYPE;
	l_attribute12_m			csi_item_instances.attribute12%TYPE;
	l_attribute13_m			csi_item_instances.attribute13%TYPE;
	l_attribute14_m			csi_item_instances.attribute14%TYPE;
	l_attribute15_m			csi_item_instances.attribute15%TYPE;
	l_attribute16_m			csi_item_instances.attribute16%TYPE;
	l_attribute17_m			csi_item_instances.attribute17%TYPE;
	l_attribute18_m			csi_item_instances.attribute18%TYPE;
	l_attribute19_m			csi_item_instances.attribute19%TYPE;
	l_attribute20_m			csi_item_instances.attribute20%TYPE;
	l_attribute21_m			csi_item_instances.attribute21%TYPE;
	l_attribute22_m			csi_item_instances.attribute22%TYPE;
	l_attribute23_m			csi_item_instances.attribute23%TYPE;
	l_attribute24_m			csi_item_instances.attribute24%TYPE;
	l_attribute25_m			csi_item_instances.attribute25%TYPE;
	l_attribute26_m			csi_item_instances.attribute26%TYPE;
	l_attribute27_m			csi_item_instances.attribute27%TYPE;
	l_attribute28_m			csi_item_instances.attribute28%TYPE;
	l_attribute29_m			csi_item_instances.attribute29%TYPE;
	l_attribute30_m			csi_item_instances.attribute30%TYPE;
	x_return_status_mstr    VARCHAR2(255);
	l_prog_error_msg_mstr		VARCHAR2(4000);
	-- Added on 15/12/2016 for DFF of Master Instancs -- End
	--
    TYPE l_csi_ins_pull_rec IS TABLE OF apps.xxcsi_inst_S3_int_v@SOURCE_S3%ROWTYPE
    INDEX BY BINARY_INTEGER;
    --
    l_csi_ins_pull_tab l_csi_ins_pull_rec;
	--
  BEGIN
    APPS.fnd_global.apps_initialize( user_id      => l_num_user_id,
                                    resp_id       => l_num_responsibility_id,
                                    resp_appl_id  => l_num_applicaton_id
                                    );
    --
    log_msg(' ',P_DEBUG);
    log_msg('=====================================================',P_DEBUG);
    log_msg('Just After Begin- Starting instance pull','Y');
    --
    BEGIN
      SELECT * BULK COLLECT
      INTO l_csi_ins_pull_tab
      FROM apps.xxcsi_inst_S3_int_v@SOURCE_S3 XIL
      WHERE 1 = 1
	  AND XIL.child_id is not null
      AND rownum <= p_batch_size
      ORDER BY last_update_date ASC;
	 -- one which has to be created( chnage in view)
	 --
    EXCEPTION
    WHEN OTHERS THEN
    l_prog_error_msg := 'Unexpected error has occured while retrieving the Data :'||SQLERRM;
	  log_msg(l_prog_error_msg,'Y');
    END;
  --
	--===================================
	--  Start of Main for loop
	--===================================
  --
  --
  --==============================================================
  -- Creating Output file header of the Instances Created
  --===============================================================
    ---
    FOR i IN 1 .. l_csi_ins_pull_tab.COUNT LOOP
	    --========================
		-- Initializing Variables
		-- =======================
		l_prog_error_msg 	    := NULL;
		--
		l_csi_inst_rec 		    := NULL;
		l_csi_ext_attrib_rec  := NULL;
		l_CSI_PARTY_rec       := NULL;
		l_CSI_party_accnt_rec := NULL;
		l_csi_trx_rec         := NULL;
		l_ch_instance_id      := NULL;
		l_val_flag_itm        :='Y';
		l_val_flag_rel        :='Y';
		l_child_item_id       := NULL;
		l_re_relation_flag    :='N';
		x_return_status       := NULL;
		x2_return_status      := NULL;
		l_prog_error_msg      := NULL;
		l_msg_data            := null;
		--
		l_rel_trx_date        := NULL;
		l_rel_trx_typ_id      := NULL;
		l_rel_instance_id_out := NULL;
		l_act_xref_cnt        := NULL;
		l_act_evnt_cnt        := NULL;
		x_instance_id         := NULL;
		l_segment1_mstr	 	  := NULL;
		l_inv_item_id_mstr	  := NULL;
		l_attribute1_m		  := NULL;
		l_attribute2_m		  := NULL;
		l_attribute3_m		  := NULL;
		l_attribute4_m		  := NULL;
	    l_attribute5_m		  := NULL;
	    l_attribute6_m		  := NULL;
		l_attribute7_m		  := NULL;
		l_attribute8_m		  := NULL;
		l_attribute9_m		  := NULL;
		l_attribute10_m		  := NULL;
		l_attribute11_m		  := NULL;
		l_attribute12_m		  := NULL;
		l_attribute13_m		  := NULL;
		l_attribute14_m		  := NULL;
		l_attribute15_m		  := NULL;
		l_attribute16_m		  := NULL;
		l_attribute17_m		  := NULL;
		l_attribute18_m		  := NULL;
		l_attribute19_m		  := NULL;
		l_attribute20_m		  := NULL;
		l_attribute21_m		  := NULL;
		l_attribute22_m		  := NULL;
		l_attribute23_m		  := NULL;
		l_attribute24_m		  := NULL;
		l_attribute25_m		  := NULL;
		l_attribute26_m		  := NULL;
		l_attribute27_m		  := NULL;
		l_attribute28_m		  := NULL;
		l_attribute29_m		  := NULL;
		l_attribute30_m		  := NULL;
		x_return_status_mstr  := NULL;
		l_prog_error_msg_mstr := NULL;
    --
	
	    l_csi_inst_rec_mstr := l_csi_inst_rec_mstr_null;
	    l_ext_attrib_values_mstr := l_ext_attrib_values_mstr_null;
	    l_party_tbl_mstr := l_party_tbl_mstr_null;
	    l_account_tbl_mstr := l_account_tbl_mstr_null;
	    l_pric_attrib_tbl_mstr := l_pric_attrib_tbl_mstr_null;
	    l_org_assig_tbl_mstr := l_org_assig_tbl_mstr_null;
	    l_asset_assig_tbl_mstr := l_asset_assig_tbl_mstr_null;
	    l_txn_rec_mstr := l_txn_rec_mstr_null;
	    l_instance_id_lst_mstr := l_instance_id_lst_mstr_null;

    --====================================================
    -- Fetching records for Master Item
    -- Validating if Master Item Present in Legacy
    --====================================================
		BEGIN
			SELECT CII.*
			INTO  l_mstr_instace_rec
			FROM  csi_item_instances            CII,
            mtl_system_items_b            MSI,
            xxssys_events                 XSE
			WHERE CII.serial_number           = l_csi_ins_pull_tab(i).mstr_serial_num
			AND   MSI.inventory_item_id       = CII.inventory_item_id
			AND   MSI.organization_id         = CII.last_vld_organization_id
			and   msi.segment1                = l_csi_ins_pull_tab(i).mstr_segment1
      AND   XSE.entity_id               = CII.instance_id
      AND   XSE.entity_name             = 'CSI_INST'
      AND   XSE.status                  ='NEW'
			AND   CII.attribute17 IS NULL;
			
			
		---- Selection of Item number from LEGACY of Master Instance --Added on 15/12/2016
		BEGIN
		SELECT DISTINCT segment1
		  INTO l_segment1_mstr
		  FROM mtl_system_items_b
		 WHERE inventory_item_id = l_mstr_instace_rec.inventory_item_id;
		 
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
			
			l_prog_error_msg := l_prog_error_msg || '| ' ||
                              ' Item Number not found for master instances ';
			log_msg('Serial number' || l_csi_ins_pull_tab(I)
                  .serial_number || ':entity_id :' || l_csi_ins_pull_tab(i)
                  .entity_id || ':segment1' || l_csi_ins_pull_tab(i)
                  .segment1, p_debug);
			log_msg(l_prog_error_msg, p_debug);
			WHEN OTHERS THEN
			l_instace_rec  := NULL;
			l_val_flag_itm := 'N';
            --
			l_prog_error_msg := l_prog_error_msg || '| ' ||
                              ' Master Item Instance not found(inside Exception)';
            --
			log_msg('Serial number' || l_csi_ins_pull_tab(I)
                  .serial_number || ':entity_id :' || l_csi_ins_pull_tab(i)
                  .entity_id || ':segment1' || l_csi_ins_pull_tab(i)
                  .segment1, p_debug);
			log_msg(l_prog_error_msg, p_debug);
		
		END; 
		
		
		---- Selection of Inventory Item ID from S3 of Master Instance --Added on 15/12/2016
		BEGIN
		SELECT DISTINCT inventory_item_id
		  INTO l_inv_item_id_mstr
		  FROM apps.mtl_system_items_b@SOURCE_S3
		 WHERE segment1 = l_segment1_mstr;
		 
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
			l_instace_rec  := NULL;
			l_val_flag_itm := 'N';
			l_prog_error_msg := l_prog_error_msg || '| ' ||
                              ' Inventory Item ID not found for master instances ';
			log_msg('Serial number' || l_csi_ins_pull_tab(I)
                  .serial_number || ':entity_id :' || l_csi_ins_pull_tab(i)
                  .entity_id || ':segment1' || l_csi_ins_pull_tab(i)
                  .segment1, p_debug);
			log_msg(l_prog_error_msg, p_debug);
			WHEN OTHERS THEN
			l_instace_rec  := NULL;
			l_val_flag_itm := 'N';
            --
			l_prog_error_msg := l_prog_error_msg || '| ' ||
                              ' Master Item Instance not found(inside Exception)';
            --
			log_msg('Serial number' || l_csi_ins_pull_tab(I)
                  .serial_number || ':entity_id :' || l_csi_ins_pull_tab(i)
                  .entity_id || ':segment1' || l_csi_ins_pull_tab(i)
                  .segment1, p_debug);
			log_msg(l_prog_error_msg, p_debug);
		END;
		
		
		---- Selection of all attributes for Master Instances from Legacy	--Added on 15/12/2016
		
		BEGIN
		SELECT attribute1, attribute2, attribute3, attribute4, attribute5, attribute6,
			   attribute7, attribute8, attribute9, attribute10, attribute11, attribute12,
			   attribute13, attribute14, attribute15, attribute16, attribute17, attribute18,
			   attribute19, attribute20, attribute21, attribute22, attribute23, attribute24,
			   attribute25, attribute26, attribute27, attribute28, attribute29, attribute30
		  INTO l_attribute1_m, l_attribute2_m, l_attribute3_m, l_attribute4_m, l_attribute5_m, l_attribute6_m,
			   l_attribute7_m, l_attribute8_m, l_attribute9_m, l_attribute10_m, l_attribute11_m, l_attribute12_m,
			   l_attribute13_m, l_attribute14_m, l_attribute15_m, l_attribute16_m, l_attribute17_m, l_attribute18_m,
			   l_attribute19_m, l_attribute20_m, l_attribute21_m, l_attribute22_m, l_attribute23_m, l_attribute24_m,
			   l_attribute25_m, l_attribute26_m, l_attribute27_m, l_attribute28_m, l_attribute29_m, l_attribute30_m
		  FROM apps.csi_item_instances@SOURCE_S3
		 WHERE serial_number = l_mstr_instace_rec.serial_number
		   AND inventory_item_id = l_inv_item_id_mstr;
		   
		EXCEPTION
			WHEN NO_DATA_FOUND THEN
			l_prog_error_msg := l_prog_error_msg || '| ' ||
                              ' Inventory Item ID not found for master instances ';
			log_msg('Serial number' || l_csi_ins_pull_tab(I)
                  .serial_number || ':entity_id :' || l_csi_ins_pull_tab(i)
                  .entity_id || ':segment1' || l_csi_ins_pull_tab(i)
                  .segment1, p_debug);
			log_msg(l_prog_error_msg, p_debug);
			WHEN OTHERS THEN
			l_instace_rec  := NULL;
			l_val_flag_itm := 'N';
            --
			l_prog_error_msg := l_prog_error_msg || '| ' ||
                              ' Master Item Instance not found(inside Exception)';
            --
			log_msg('Serial number' || l_csi_ins_pull_tab(I)
                  .serial_number || ':entity_id :' || l_csi_ins_pull_tab(i)
                  .entity_id || ':segment1' || l_csi_ins_pull_tab(i)
                  .segment1, p_debug);
			log_msg(l_prog_error_msg, p_debug);
		
		END;
			
			
			
			--
		EXCEPTION
		WHEN NO_DATA_FOUND THEN
			l_instace_rec := NULL;
			l_val_flag_itm :='N';
			l_prog_error_msg :=l_prog_error_msg||'| '||' Master Item Instance not found ' ;
			log_msg('Serial number'||l_csi_ins_pull_tab(I).serial_number||' :entity_id :'||
			l_csi_ins_pull_tab(i).entity_id||':segment1'||l_csi_ins_pull_tab(i).segment1,p_debug);
			log_msg(l_prog_error_msg,p_debug);
		WHEN OTHERS THEN
			l_instace_rec := NULL;
			l_val_flag_itm :='N';
			--
			l_prog_error_msg :=l_prog_error_msg||'| '||' Master Item Instance not found(inside Exception)' ;
			--
			log_msg('Serial number'||l_csi_ins_pull_tab(I).serial_number||':entity_id :'||
			l_csi_ins_pull_tab(i).entity_id||':segment1'||l_csi_ins_pull_tab(i).segment1,p_debug);
		    log_msg(l_prog_error_msg,p_debug);
		END;
		--
		--======================================================
		LOG_MSG('Getting Transaction Status for Configuration Creation for master Instance:'||l_mstr_instace_rec.instance_id||':Serial Num:-'||l_csi_ins_pull_tab(i).mstr_serial_num,P_DEBUG);
    LOG_MSG('*********Old Child Instance ID:'||l_csi_ins_pull_tab(i).instance_id||' :Segment1:- '||l_csi_ins_pull_tab(i).segment1||': Serial Number '||l_csi_ins_pull_tab(I).serial_number,P_DEBUG);
		--======================================================
		--
		IF l_mstr_instace_rec.instance_id IS NOT NULL THEN
			--
			BEGIN
				SELECT MIN(TRANSACTION_DATE)
					  ,MIN(TRANSACTION_TYPE_ID)
				INTO l_rel_trx_date
						,l_rel_trx_typ_id
				FROM  csi_inst_transactions_v 	CIT
				WHERE instance_id	=	l_mstr_instace_rec.instance_id;
				--
			EXCEPTION WHEN OTHERS THEN
			l_prog_error_msg :=l_prog_error_msg||'| '||'EXCEPTION while getting Transaction Details :'||sqlerrm ;
			log_msg(l_prog_error_msg,p_debug);
			l_val_flag_itm :='N';
			END;
			--
		END IF; --l_mstr_instace_rec.instance_id IS NOT
		--
		log_msg('Just After Begin- Starting MASTER ITEM ID :'||l_mstr_instace_rec.INVENTORY_ITEM_ID,P_DEBUG);
		--
		-- ==============================================
		  -- Validate if the instances are already created
		--================================================
		--
		BEGIN
			SELECT instance_id
			INTO l_ch_instance_id
			FROM mtl_system_items_b               MSI,
           csi_item_instances               CSI,
           xxcref_cs_ib_item_instance       XCI
			WHERE MSI.segment1 			      	      = l_csi_ins_pull_tab(i).segment1
			AND   CSI.inventory_item_id	  		    = MSI.inventory_item_id
			AND   CSI.LAST_VLD_ORGANIZATION_ID 		= l_mstr_instace_rec.LAST_VLD_ORGANIZATION_ID
			AND   NVL(CSI.serial_number,1)        = NVL(l_csi_ins_pull_tab(i).serial_number,1)
      and   xci.s3_id                       = csi.instance_id
      AND   XCI.legacy_id                   = l_csi_ins_pull_tab(i).instance_id
      and   xci.attribute3                  = l_mstr_instace_rec.instance_id
      and   xci.attribute4                  = l_csi_ins_pull_tab(i).parent_id;
		  EXCEPTION WHEN NO_DATA_FOUND THEN
			l_val_flag_itm :='Y';
			log_msg('No Duplicate Instance found for same Serial number and segment1 in an inv org',p_debug);
			l_re_relation_flag :='Y';-- to Create Relationship for missed out instances if any
		  WHEN OTHERS THEN
			l_prog_error_msg :=l_prog_error_msg||'| '||'EXCEPTION while getting item detail :'||sqlerrm ;
			log_msg(l_prog_error_msg,p_debug);
			l_val_flag_itm :='N';
		END;
	  --
	  --=====================================================
	  --Validate if child item is present or not
    --=====================================================
	  --
      IF l_ch_instance_id IS NOT NULL THEN
        l_prog_error_msg := l_prog_error_msg||'|'||'Instance Already Created For Serial Number :'||l_csi_ins_pull_tab(i).serial_number;
        l_val_flag_itm 	 :='N';
        log_msg('Child Instance Id Already Created :'||l_ch_instance_id,P_DEBUG);
      END IF;
      --
      log_msg('Validate if Item Relationship is created for serial_number- :'||l_csi_ins_pull_tab(i).serial_number,p_debug);
    --
	  --
	  BEGIN
		SELECT  DISTINCT CSI.instance_id
        INTO l_rel_instance_id
        FROM mtl_system_items_b        MSI,
             csi_item_instances        CSI,
             csi_ii_relationships      CIR
        WHERE MSI.segment1 			                = l_csi_ins_pull_tab(i).segment1
        AND   CSI.inventory_item_id	            = MSI.inventory_item_id
        AND   NVL(CSI.serial_number,1)          = NVL(l_csi_ins_pull_tab(i).serial_number,1)
        AND   CSI.last_vld_organization_id      = l_mstr_instace_rec.LAST_VLD_ORGANIZATION_ID
        AND   CIR.subject_id                    = CSI.instance_id
        AND   CSI.instance_id                   = l_ch_instance_id;
        --
	  EXCEPTION WHEN NO_DATA_FOUND THEN
      l_val_flag_rel 		:='Y';
      log_msg('Relationship not found ,Validation Passed :',p_debug);
	  WHEN OTHERS THEN
      l_prog_error_msg :=l_prog_error_msg||'| '||'EXCEPTION while getting item relation detail:'||sqlerrm ;
      log_msg(l_prog_error_msg,'Y');
      l_val_flag_rel :='N';
	  END;
	  --
	  --==============================================================================================
      log_msg('Getting Inv Item ids for child instance id SEGMENT:'||l_csi_ins_pull_tab(i).segment1
      ||': ORGANIZATION_ID :-'||l_mstr_instace_rec.inv_organization_id,p_debug);
    --==============================================================================================
     BEGIN
       SELECT inventory_item_id INTO
              l_child_item_id
       FROM  mtl_system_items_b MSI
       WHERE MSI.segment1         = l_csi_ins_pull_tab(i).segment1
       AND   MSI.organization_id  = l_mstr_instace_rec.last_vld_organization_id;
     EXCEPTION WHEN OTHERS THEN
       l_prog_error_msg :=l_prog_error_msg||'| '||'EXCEPTION while getting child item id:'||sqlerrm ;
       log_msg(l_prog_error_msg,'Y');
       l_val_flag_itm :='N';
     END;
      log_msg('l_val_flag_itm:'||l_val_flag_itm||':l_val_flag_rel'||l_val_flag_rel,p_debug);
      --
      -- ======================================================
      -- If the Item  and Relationship validations has Passed then Proceed
      -- ======================================================
      --
		  IF (L_VAL_FLAG_ITM ='Y' AND L_VAL_FLAG_REL='Y') THEN
		-- =========================================
		-- Populate DFF data for master instance.
		-- =========================================
			l_csi_inst_rec_mstr.instance_id := l_mstr_instace_rec.instance_id;
			l_csi_inst_rec_mstr.instance_number := l_mstr_instace_rec.instance_number;
			l_csi_inst_rec_mstr.attribute1 := l_attribute1_m;
			l_csi_inst_rec_mstr.attribute2 := l_attribute2_m;
			l_csi_inst_rec_mstr.attribute3 := l_attribute3_m;
			l_csi_inst_rec_mstr.attribute4 := l_attribute4_m;
			l_csi_inst_rec_mstr.attribute5 := l_attribute5_m;
			l_csi_inst_rec_mstr.attribute6 := l_attribute6_m;
			l_csi_inst_rec_mstr.attribute7 := l_attribute7_m;
			l_csi_inst_rec_mstr.attribute8 := l_attribute8_m;
			l_csi_inst_rec_mstr.attribute9 := l_attribute9_m;
			l_csi_inst_rec_mstr.attribute10 := l_attribute10_m;
			l_csi_inst_rec_mstr.attribute11 := l_attribute11_m;
			l_csi_inst_rec_mstr.attribute12 := l_attribute12_m;
			l_csi_inst_rec_mstr.attribute13 := l_attribute13_m;
			l_csi_inst_rec_mstr.attribute14 := l_attribute14_m;
			l_csi_inst_rec_mstr.attribute15 := l_attribute15_m;
			l_csi_inst_rec_mstr.attribute16 := l_attribute16_m;
			l_csi_inst_rec_mstr.attribute17 := l_attribute17_m;
			l_csi_inst_rec_mstr.attribute18 := l_attribute18_m;
			l_csi_inst_rec_mstr.attribute19 := l_attribute19_m;
			l_csi_inst_rec_mstr.attribute20 := l_attribute20_m;
			l_csi_inst_rec_mstr.attribute21 := l_attribute21_m;
			l_csi_inst_rec_mstr.attribute22 := l_attribute22_m;
			l_csi_inst_rec_mstr.attribute23 := l_attribute23_m;
			l_csi_inst_rec_mstr.attribute24 := l_attribute24_m;
			l_csi_inst_rec_mstr.attribute25 := l_attribute25_m;
			l_csi_inst_rec_mstr.attribute26 := l_attribute26_m;
			l_csi_inst_rec_mstr.attribute27 := l_attribute27_m;
			l_csi_inst_rec_mstr.attribute28 := l_attribute28_m;
			l_csi_inst_rec_mstr.attribute29 := l_attribute29_m;
			l_csi_inst_rec_mstr.attribute30 := l_attribute30_m;
			l_csi_inst_rec_mstr.object_version_number := l_mstr_instace_rec.object_version_number;
			
			
			l_txn_rec_mstr.transaction_id              := NULL;
            l_txn_rec_mstr.transaction_date            := trunc(SYSDATE);
            l_txn_rec_mstr.source_transaction_date     := trunc(SYSDATE);
            l_txn_rec_mstr.transaction_type_id         := 1;
            l_txn_rec_mstr.txn_sub_type_id             := NULL;
            l_txn_rec_mstr.source_group_ref_id         := NULL;
            l_txn_rec_mstr.source_group_ref            := '';
            l_txn_rec_mstr.source_header_ref_id        := NULL;
            l_txn_rec_mstr.source_header_ref           := '';
            l_txn_rec_mstr.source_line_ref_id          := NULL;
            l_txn_rec_mstr.source_line_ref             := '';
            l_txn_rec_mstr.source_dist_ref_id1         := NULL;
            l_txn_rec_mstr.source_dist_ref_id2         := NULL;
            l_txn_rec_mstr.inv_material_transaction_id := NULL;
            l_txn_rec_mstr.transaction_quantity        := NULL;
            l_txn_rec_mstr.transaction_uom_code        := '';
            l_txn_rec_mstr.transacted_by               := NULL;
            l_txn_rec_mstr.transaction_status_code     := '';
            l_txn_rec_mstr.transaction_action_code     := '';
            l_txn_rec_mstr.message_id                  := NULL;
            l_txn_rec_mstr.object_version_number       := '';
            l_txn_rec_mstr.split_reason_code           := '';
        --
			  -- =========================================
			  -- Populating data in instance record Type
			  --==========================================
        --
			  l_csi_inst_rec.instance_id 				        := NULL;
			  l_csi_inst_rec.instance_number   			    := NULL;
			  l_csi_inst_rec.external_reference 		    := NULL;
			  l_csi_inst_rec.serial_number 				      := l_csi_ins_pull_tab(i).serial_number;
			  l_csi_inst_rec.INV_LOCATOR_ID 			      := L_MSTR_INSTACE_REC.INV_LOCATOR_ID;
			  l_csi_inst_rec.inventory_item_id 			    := l_child_item_id;
			  l_csi_inst_rec.inv_master_organization_id := l_mstr_instace_rec.inv_master_organization_id;
			  l_csi_inst_rec.vld_organization_id 		    := l_mstr_instace_rec.last_vld_organization_id;
			  l_csi_inst_rec.inv_organization_id 		    := l_mstr_instace_rec.inv_organization_id;
			  l_csi_inst_rec.instance_status_id  		    := l_mstr_instace_rec.instance_status_id;
			  l_csi_inst_rec.customer_view_flag         := l_mstr_instace_rec.customer_view_flag;
			  l_csi_inst_rec.merchant_view_flag         := l_mstr_instace_rec.merchant_view_flag;
			  l_csi_inst_rec.location_type_code         := l_mstr_instace_rec.location_type_code;--'INVENTORY';
			  l_csi_inst_rec.location_id                := l_mstr_instace_rec.location_id;
			  l_csi_inst_rec.inv_subinventory_name      := l_mstr_instace_rec.inv_subinventory_name;
			  l_csi_inst_rec.object_version_number 		  := 1.0;
			  l_csi_inst_rec.quantity 					        := l_csi_ins_pull_tab(i).quantity;
			  l_csi_inst_rec.unit_of_measure 			      := l_csi_ins_pull_tab(i).unit_of_measure;
			  l_csi_inst_rec.mfg_serial_number_flag 	  := l_csi_ins_pull_tab(i).mfg_serial_number_flag;
			  l_csi_inst_rec.version_label 				      := 'AS_CREATED';
			  l_csi_inst_rec.active_start_date 			    := l_csi_ins_pull_tab(i).active_start_date;
			  l_csi_inst_rec.install_date 				      := l_csi_ins_pull_tab(i).install_date;
			  -- ATTRIBUTE--
			  l_csi_inst_rec.attribute1 := l_csi_ins_pull_tab(i).ATTRIBUTE_1;
			  l_csi_inst_rec.attribute2 := l_csi_ins_pull_tab(i).ATTRIBUTE_2;
			  l_csi_inst_rec.attribute3 := l_csi_ins_pull_tab(i).ATTRIBUTE_3;
			  l_csi_inst_rec.attribute4 := l_csi_ins_pull_tab(i).ATTRIBUTE_4;
			  l_csi_inst_rec.attribute5 := l_csi_ins_pull_tab(i).ATTRIBUTE_5;
			  l_csi_inst_rec.attribute6 := l_csi_ins_pull_tab(i).ATTRIBUTE_6;
			  l_csi_inst_rec.attribute7 := l_csi_ins_pull_tab(i).ATTRIBUTE_7;
			  l_csi_inst_rec.attribute8 := l_csi_ins_pull_tab(i).ATTRIBUTE_8;			  
			  l_csi_inst_rec.ATTRIBUTE9  := l_csi_ins_pull_tab(i).lEGACY_INSTANCE_ID;
			  l_csi_inst_rec.attribute10 := l_csi_ins_pull_tab(i).ATTRIBUTE_10;
			  l_csi_inst_rec.attribute11 := l_csi_ins_pull_tab(i).ATTRIBUTE_11;
			  l_csi_inst_rec.ATTRIBUTE12                := l_csi_ins_pull_tab(i).sf_id;
			  l_csi_inst_rec.attribute13 := l_csi_ins_pull_tab(i).ATTRIBUTE_13;
			  l_csi_inst_rec.attribute14 := l_csi_ins_pull_tab(i).ATTRIBUTE_14;
			  l_csi_inst_rec.attribute15 := l_csi_ins_pull_tab(i).ATTRIBUTE_15;
			  l_csi_inst_rec.attribute16 := l_csi_ins_pull_tab(i).ATTRIBUTE_16;			  
			  l_csi_inst_rec.ATTRIBUTE17 :='Y';
			  l_csi_inst_rec.attribute18 := l_csi_ins_pull_tab(i).ATTRIBUTE_18;
			  l_csi_inst_rec.attribute19 := l_csi_ins_pull_tab(i).ATTRIBUTE_19;
			  l_csi_inst_rec.attribute20 := l_csi_ins_pull_tab(i).ATTRIBUTE_20;
			  l_csi_inst_rec.attribute21 := l_csi_ins_pull_tab(i).ATTRIBUTE_21;
			  l_csi_inst_rec.attribute22 := l_csi_ins_pull_tab(i).ATTRIBUTE_22;
			  l_csi_inst_rec.attribute23 := l_csi_ins_pull_tab(i).ATTRIBUTE_23;
			  l_csi_inst_rec.attribute24 := l_csi_ins_pull_tab(i).ATTRIBUTE_24;
			  l_csi_inst_rec.attribute25 := l_csi_ins_pull_tab(i).ATTRIBUTE_25;
			  l_csi_inst_rec.attribute26 := l_csi_ins_pull_tab(i).ATTRIBUTE_26;
			  l_csi_inst_rec.attribute27 := l_csi_ins_pull_tab(i).ATTRIBUTE_27;
			  l_csi_inst_rec.attribute28 := l_csi_ins_pull_tab(i).ATTRIBUTE_28;
			  l_csi_inst_rec.attribute29 := l_csi_ins_pull_tab(i).ATTRIBUTE_29;
			  l_csi_inst_rec.attribute30 := l_csi_ins_pull_tab(i).ATTRIBUTE_30;			  
			  l_csi_party_rec.party_source_table  := l_csi_ins_pull_tab(i).OWNER_party_source_table;
			  l_csi_party_rec.instance_id 					    := null;
			  l_csi_party_rec.relationship_type_code 		:= 'OWNER';--l_csi_ins_pull_tab(i).relationship_type_code;
			  l_csi_party_rec.party_id 					        := l_mstr_instace_rec.OWNER_PARTY_ID;
			  l_csi_party_rec.contact_flag 				      := 'N';
			  l_party_tbl(1) 							              :=l_csi_party_rec;
			  l_csi_ext_attrib_rec.attribute_value_id   := NULL;
			  --
			  l_csi_trx_rec.transaction_date            := l_rel_trx_date;
			  l_csi_trx_rec.source_transaction_date     := l_rel_trx_date;
			  l_csi_trx_rec.transaction_type_id         := l_rel_trx_typ_id;
			  --
			  --================================================================
			  -- Creation of Instance started
			  --=================================================================
			  --
			  log_msg('OWNER_PARTY_ID:'||l_mstr_instace_rec.owner_party_id
			  ||': Relationship_type_code:-'||l_csi_ins_pull_tab(i).relationship_type_code
              ||': Owner_party_source_table:'||l_csi_ins_pull_tab(i).owner_party_source_table,p_debug);
			  --
			  log_msg('Creation of Instance started for event_id :'||l_csi_ins_pull_tab(i).entity_id,p_debug);
			  --
			  -- Updation of Master Instance with DFF	--Added on 15/12/2016
				xxcsi_legacy_s3_int_pkg.update_mstr_instance (p_xxcsi_inst_rec_mstr  => l_csi_inst_rec_mstr,
													  p_xxcsi_ext_att_val_tbl_mstr => l_ext_attrib_values_mstr,
													  p_xxcsi_party_tbl_mstr => l_party_tbl_mstr,
													  p_xxcsi_account_tbl_mstr => l_account_tbl_mstr, 
													  p_xxcsi_pric_attr_tbl_mstr => l_pric_attrib_tbl_mstr,
													  p_xxcsi_org_assig_tbl_mstr => l_org_assig_tbl_mstr,
													  p_xxcsi_asset_assig_tbl_mstr => l_asset_assig_tbl_mstr,
													  p_xxcsi_txn_rec_mstr => l_txn_rec_mstr,
													  p_debug => p_debug,
													  p_status_mstr => x_return_status_mstr,
													  p_err_msg_mstr => l_prog_error_msg_mstr
													  );
        
				l_prog_error_msg := l_prog_error_msg || '|' || l_prog_error_msg_mstr;
			  
			  
			  
			  
			  
			  XXCSI_LEGACY_S3_INT_PKG.create_instance(p_xxcsi_inst_rec 		      => l_csi_inst_rec,
							   p_xxcst_ext_attrib_val_rec => l_csi_ext_attrib_rec,
							   p_xxcsi_party_rec          => l_CSI_PARTY_rec,
							   p_xxcsi_party_account_rec  => l_CSI_party_accnt_rec,
							   p_xxcsi_trx_rec            => l_csi_trx_rec,
							   p_instance_id              => x_instance_id,
							   p_debug                    => p_debug,
							   p_status  			            => x_return_status,
							   P_ERR_MSG                  => l_prog_error_msg
							 );
			--
			l_prog_error_msg:=l_prog_error_msg||'|'||l_prog_error_msg;
			--
			--
			-- Update the xxsys_event table with status
			--
        IF x_instance_id IS NOT NULL THEN
          LOG_MSG(' Instance_id created is :'||X_INSTANCE_ID,P_DEBUG);
          --Reseting the Table Type record
          l_inst_rel_tbl.DELETE(1);
          -- START CREATING RELATIONSHIP
          --
          log_msg('START CREATING RELATIONSHIP for event_id :'||l_csi_ins_pull_tab(i).entity_id,P_DEBUG);
          --
          --
          --l_inst_rel_tbl(1).relationship_id                   := v_relationship_id;
          l_inst_rel_tbl(1).relationship_type_code            := 'COMPONENT-OF';
          l_inst_rel_tbl(1).object_id                         := l_mstr_instace_rec.instance_id;
          l_inst_rel_tbl(1).subject_id                        := x_instance_id;
          --
          l_inst_rel_tbl(1).subject_has_child                 := 'Y';
          l_inst_rel_tbl(1).position_reference                := NULL;
          l_inst_rel_tbl(1).active_start_date                 := sysdate;
          l_inst_rel_tbl(1).active_end_date                   := NULL;
          l_inst_rel_tbl(1).display_order                     := NULL;
          l_inst_rel_tbl(1).mandatory_flag                    := 'N';
          l_inst_rel_tbl(1).CONTEXT                           := NULL;
          l_inst_rel_tbl(1).attribute1                        := NULL;
          l_inst_rel_tbl(1).attribute2                        := NULL;
          l_inst_rel_tbl(1).attribute3                        := NULL;
          l_inst_rel_tbl(1).attribute4                        := NULL;
          l_inst_rel_tbl(1).attribute5                        := NULL;
          l_inst_rel_tbl(1).attribute6                        := NULL;
          l_inst_rel_tbl(1).attribute7                        := NULL;
          l_inst_rel_tbl(1).attribute8                        := NULL;
          l_inst_rel_tbl(1).attribute9                        := NULL;
          l_inst_rel_tbl(1).attribute10                       := NULL;
          l_inst_rel_tbl(1).attribute11                       := NULL;
          l_inst_rel_tbl(1).attribute12                       := NULL;
          l_inst_rel_tbl(1).attribute13                       := NULL;
          l_inst_rel_tbl(1).attribute14                       := NULL;
          l_inst_rel_tbl(1).attribute15                       := NULL;
          l_inst_rel_tbl(1).object_version_number             := 1;
          l_trx_rel_rec.transaction_date                      := l_rel_trx_date;
          l_trx_rel_rec.source_transaction_date               := l_rel_trx_date;
          l_trx_rel_rec.transaction_type_id                   := l_rel_trx_typ_id;
          l_trx_rel_rec.object_version_number                 := 1;
          --
          -- calling Relationship API
          --
          log_msg('calling Relationship API',p_debug);
          --
          --
          xxcsi_legacy_s3_int_pkg.create_inst_relation (P_XXCSI_INST_REL_REC            => l_inst_rel_tbl,
                                                        P_XXCSI_TXN_REC                 => l_trx_rel_rec,
                                                        P_DEBUG                         => p_debug,
                                                        P_STATUS                        => x2_return_status,
                                                        P_ERR_MSG                       => l_prog_error_msg,
                                                        P_RELATIONSHIP_ID               => l_rel_instance_id_out
                                                  );
          --
          --
          l_prog_error_msg:=l_prog_error_msg||'|'||l_prog_error_msg;
          --
          --l_rel_instance_id_out :=l_inst_rel_tbl(1).relationship_id ;
          log_msg(' Relationship Id created is '||l_rel_instance_id_out,p_debug);
          --
          log_msg(l_prog_error_msg,p_debug);
          log_msg('****Status for Instance :-'||x_return_status||' : Status for relationship:'||x2_return_status||' *****',P_DEBUG);
          --
          --=================================================================================
          -- Validate if the Status of both the Processes( instance create/Rel creation is 'S'
          --=================================================================================
          IF (x_return_status='S' AND x2_return_status='S' ) THEN
            -- Calling Package to update the status to success
            --
            --
            --================================================================
            -- Inserting Data into xxref table XXCREF_CS_IB_ITEM_INSTANCE
            --================================================================
            --
            xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table ( p_entity_name => 'INSTALL-BASE',
														p_legacy_id  	=> l_csi_ins_pull_tab(i).instance_id,
														p_s3_id      	=> X_INSTANCE_ID,
														p_org_id     	=> l_mstr_instace_rec.inv_organization_id,
														p_attribute1 	=> l_csi_ins_pull_tab(i).sf_id,
														p_attribute2 	=> l_rel_instance_id_out,
														p_attribute3 	=> L_MSTR_INSTACE_REC.INSTANCE_ID,
														p_attribute4 	=> l_csi_ins_pull_tab(i).parent_id,
														p_attribute5 	=> NULL,
														p_err_code   	=> x2_return_status,
														p_err_message	=> l_prog_error_msg
                          );
            --
            COMMIT;
            l_prog_error_msg :='|'||l_prog_error_msg;
            --
            LOG_MSG('After inserting Values in Xref Table:'||l_prog_error_msg,p_debug);
          --
          ELSIF x_return_status='E' THEN
            LOG_MSG('Inserting data into Error table',p_debug);
            xxssys_event_pkg.process_event_error(p_event_id      =>l_csi_ins_pull_tab(i).event_id,
                                                    p_error_system  =>'CSI_INST' ,
                                                    p_err_message   => x2_return_status
                                                  );
          END IF;--x2_return_status ='S'
          --
        END IF;-- X_INSTANCE_ID
			--
		  END IF;--l_success_flag ='Y'
      --
  --=================================================================================================
  -- Updating the Error Status in xxssys_events table to 'E' if any of the instance or the Relationship
  -- is not created for the Master Item Instance
  --=================================================================================================
  --
      IF  i=l_csi_ins_pull_tab.COUNT THEN
       LOG_MSG('Inside the XXSSYS_EVENTS UPDATE :',P_DEBUG);
      --
        BEGIN
          SELECT COUNT(*) INTO l_act_evnt_cnt
          FROM apps.xxcsi_inst_s3_int_v@SOURCE_S3 XII
          WHERE XII.event_id  =l_mstr_instace_rec.instance_id;
          LOG_MSG('** l_ACCT_EVNT_CNT :'||L_ACT_EVNT_CNT,P_DEBUG);
          --
          BEGIN
            SELECT COUNT(*)
            INTO l_act_xref_cnt
            FROM xxcref_cs_ib_item_instance xci
            WHERE xci.attribute4  = l_csi_ins_pull_tab(i).parent_id
            AND   XCI.attribute2 IS NOT NULL;
            --
            LOG_MSG('** l_act_xref_cnt :'||l_act_xref_cnt,P_DEBUG);
          EXCEPTION WHEN NO_DATA_FOUND then
            l_act_xref_cnt := 0;
          END;
          --
          --=========================================================
          -- Checking if the actual count Matches with the xref table
          -- if MATCHES then update the status ='S' else 'E'
          --=========================================================
          IF l_act_evnt_cnt = l_act_xref_cnt
          THEN
            log_msg('Updating Status in xxssys_events table',p_debug);
            xxssys_event_pkg.update_success(l_csi_ins_pull_tab(i).event_id);
          ELSE
            xxssys_event_pkg.process_event_error(p_event_id      =>l_csi_ins_pull_tab(i).event_id,
                                                        p_error_system  =>'CSI_INST' ,
                                                        p_err_message   => x2_return_status
                                                      );
          END IF;
          --
        EXCEPTION WHEN OTHERS THEN
        log_msg('Inside the Exception Block of Update Event table',p_debug);
        END;
      END IF; --i=l_csi_ins_pull_tab.COUNT
		  --
      log_msg(' ',P_DEBUG);
     log_msg('=====================================================',P_DEBUG);
     END LOOP;
    -- =========================================================================
    -- Calling Instance Report LOCAL PROCEDURE
    ---
    BEGIN
     log_msg('Calling Instance Report LOCAL PROCEDURE',P_DEBUG);
     INSTANCE_REPORT;
    END;
    --==========================================================================
  EXCEPTION
  WHEN OTHERS THEN
      l_prog_error_msg:= l_prog_error_msg||'|'||'Unexpected Error--' || SQLERRM;
      l_var_error_code := SQLCODE;
      log_msg(l_prog_error_msg,'Y');
  END pull_instance;
  --
  -- ========================================================================================================
  -- Procedure Name     : pull_relationship
  -- Purpose:  This procedure Will be used to create relationship for the Instances created missed during instance
  --           creation ( Interim Solution)
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  08/18/2016  Vishal( TCS)    Initial Creation for Interimn Solution of the Instalal Base.
  -- ==============================================================================================
  --
  PROCEDURE PULL_RELATIONSHIP(P_ERRBUF      OUT VARCHAR2,
                               P_RETCODE    OUT NUMBER,
                               P_BATCH_SIZE IN NUMBER,
                               p_debug 		IN VARCHAR2)
    IS
    l_num_user_id           NUMBER := fnd_global.user_id;
    l_num_responsibility_id NUMBER := fnd_global.resp_id;
    l_num_applicaton_id     NUMBER := fnd_global.resp_appl_id;
    l_conc_request_id       NUMBER := fnd_global.conc_request_id;
    --
    l_return_status         VARCHAR2(255) := 'N';
    l_msg_count             NUMBER(22);
    l_msg_data              VARCHAR2(255);
    L_ERROR_MSG             VARCHAR2(4000);
    l_val_flag_itm          VARCHAR2(5) :='N';
    L_VAL_FLAG_REL          VARCHAR2(5) :='N';
	  --Record type for instance variables
    --Table type Variable for relationship
    L_REL_TBL              CSI_DATASTRUCTURES_PUB.II_RELATIONSHIP_TBL;
    l_tx_rel_rec           csi_datastructures_pub.transaction_rec;
    --
    p_commit                VARCHAR2 (5);
    --Master Item rec
    l_mstr_instace_rel_rec  CSI_ITEM_INSTANCES%ROWTYPE;
    l_child_item_id         MTL_SYSTEM_ITEMS_B.INVENTORY_ITEM_ID%TYPE;
    L_RE_RELATION_FLAG      VARCHAR2(1) :='N';
    -- For Transaction details
    l_rel_trx_date          CSI_INST_TRANSACTIONS_V.transaction_date%TYPE;
    L_REL_TRX_TYP_ID        CSI_INST_TRANSACTIONS_V.TRANSACTION_TYPE_ID%TYPE;
    --
    L_REL_INST_ID_OUT       NUMBER;--csi_ii_relationships.relationship_id%type;
    L_REL_INST_ID           CSI_ITEM_INSTANCES.INSTANCE_ID%TYPE;
    l_ch_instance_id        CSI_ITEM_INSTANCES.instance_id%TYPE;
    l_rel_instance_id       CSI_ITEM_INSTANCES.INSTANCE_ID%TYPE;
    l_count1                NUMBER;
    l_prog_error_msg        VARCHAR2(4000) := NULL;
    x_return_status         VARCHAR2(255) := 'N';
	  x2_return_status        VARCHAR2(1) :='S';
    X2_ERR_MSG              VARCHAR(4000) := NULL;
    X_MSG_COUNT             NUMBER;
    X_MSG_DATA              VARCHAR2(255);
    L_OBJECT_VERSION_NUMBER NUMBER;
   -- P_DEBUG                 VARCHAR2(1) :='Y';
    TYPE l_csi_rel_pull_rec IS TABLE OF apps.XXCSI_INST_S3_INT_V@SOURCE_S3%ROWTYPE
	  INDEX BY BINARY_INTEGER;
    --
    l_csi_rel_pull_tab l_csi_rel_pull_rec;
    --
    BEGIN
    LOG_MSG('=========================================',P_DEBUG);
    LOG_MSG(' ',P_DEBUG);
    LOG_MSG('Start Creation of Relationship',P_DEBUG);
    --
    BEGIN
      SELECT * BULK COLLECT
      into l_csi_rel_pull_tab
      FROM apps.XXCSI_INST_S3_INT_V@SOURCE_S3 xil
      WHERE 1 = 1
	    AND xil.child_id IS NOT NULL
      AND ROWNUM <= p_batch_size
      ORDER BY last_update_date ASC;
	 -- one which has to be created( chnage in view)
	 --
    EXCEPTION
    WHEN OTHERS THEN
    l_prog_error_msg := 'Unexpected error has occured while retrieving the Data :'||SQLERRM;
		log_msg(l_prog_error_msg,'Y');
    END;
  --
	--  Start of Main for loop
	--
    FOR i IN 1 .. l_csi_rel_pull_tab.COUNT LOOP
	  l_prog_error_msg := NULL;
    LOG_MSG(' ',P_DEBUG);
    LOG_MSG('=======================================',P_DEBUG);
    --
    -- Initialising Variables
    --
			--l_tx_rel_rec         := null;
      l_ch_instance_id      := NULL;
      l_val_flag_itm        :='Y';
      l_val_flag_rel        :='Y';
      l_child_item_id       := NULL;
      l_re_relation_flag    :='N';
      x_return_status       := NULL;
      x2_return_status      := NULL;
      x2_err_msg            := NULL;
      l_prog_error_msg      := NULL;
      l_msg_data            := null;
      l_rel_trx_date        := NULL;
      l_rel_trx_typ_id      := NULL;
      --
	    -- ===========================================================
      -- Getting master Item Instance Attribute
      --============================================================
      --
		  BEGIN
        --
        SELECT CII.*
        INTO  l_mstr_instace_rel_rec
        FROM  csi_item_instances            CII,
              mtl_system_items_b            MSI,
              xxssys_events                 XSE
        WHERE CII.serial_number           = l_csi_rel_pull_tab(i).mstr_serial_num
        AND   MSI.inventory_item_id       = CII.inventory_item_id
        AND   MSI.organization_id         = CII.last_vld_organization_id
        and   MSI.segment1                = l_csi_rel_pull_tab(i).mstr_segment1
        AND   XSE.entity_id               = CII.instance_id
        AND   XSE.entity_name             = 'CSI_INST'
        and   XSE.status                  = 'NEW'
        AND   CII.attribute17 IS NULL;
        --
			EXCEPTION
			WHEN no_data_found THEN
			  l_val_flag_itm :='N';
			  l_prog_error_msg :=l_prog_error_msg||'| '||' Master Item Instance not found ' ;
        log_msg('Serial number'||l_csi_rel_pull_tab(I).serial_number||':entity_id :'||
        l_csi_rel_pull_tab(i).entity_id||':segment1'||l_csi_rel_pull_tab(i).segment1,p_debug);
			  log_msg(l_prog_error_msg,p_debug);
			WHEN OTHERS THEN
			  l_val_flag_itm :='N';
        --
        l_prog_error_msg :=l_prog_error_msg||'| '||' Master Item Instance not found(inside Exception)' ;
        --
        log_msg('Serial number'||l_csi_rel_pull_tab(I).serial_number||':entity_id :'||
        l_csi_rel_pull_tab(i).entity_id||':segment1'||l_csi_rel_pull_tab(i).segment1,p_debug);
			  log_msg(l_prog_error_msg,p_debug);
		  END;
		  --
      --======================================================
		   LOG_MSG('Getting Transaction Status for Relationship Creation for master Instance:'||l_mstr_instace_rel_rec.instance_id,P_DEBUG);
		  --======================================================
      IF l_mstr_instace_rel_rec.instance_id IS NOT NULL THEN
        BEGIN
          SELECT MIN(TRANSACTION_DATE)
                ,MIN(TRANSACTION_TYPE_ID)
          INTO  l_rel_trx_date
                ,L_REL_TRX_TYP_ID
          FROM  CSI_INST_TRANSACTIONS_V CIT
          WHERE instance_id=101360;
        EXCEPTION WHEN OTHERS THEN
          l_prog_error_msg :=l_prog_error_msg||'| '||'EXCEPTION while getting Transaction Details :'||sqlerrm ;
          log_msg(l_prog_error_msg,p_debug);
          l_val_flag_itm :='N';
       END;
      END IF;
      --==
      log_msg('Just After Begin- Starting MASTER item_instance :'||l_mstr_instace_rel_rec.instance_id,P_DEBUG);
      --
		  --======================================================
		  -- Validate if the instances are already created
		  --======================================================
      --
		  BEGIN
        SELECT instance_id
        INTO l_ch_instance_id
        FROM mtl_system_items_b             MSI,
           csi_item_instances               CSI,
           xxcref_cs_ib_item_instance       XCI
        WHERE MSI.segment1 			      	  = l_csi_rel_pull_tab(i).segment1
        AND   CSI.inventory_item_id	  		= MSI.inventory_item_id
        AND   CSI.LAST_VLD_ORGANIZATION_ID 		= l_mstr_instace_rel_rec.LAST_VLD_ORGANIZATION_ID
        AND   NVL(CSI.serial_number,1)    = NVL(l_csi_rel_pull_tab(i).serial_number,1)
        AND   XCI.S3_ID                   = CSI.INSTANCE_ID
        AND   XCI.ATTRIBUTE3              = l_mstr_instace_rel_rec.instance_id
        and   xci.attribute4              = l_csi_rel_pull_tab(i).parent_id;
        --
      EXCEPTION WHEN NO_DATA_FOUND THEN
		    l_val_flag_itm :='N';
        log_msg('No Duplicate Instance found for same Serial number and segment1 in an inv org',p_debug);
		  WHEN OTHERS THEN
        l_prog_error_msg :=l_prog_error_msg||'| '||'EXCEPTION while getting item detail :'||sqlerrm ;
        log_msg(l_prog_error_msg,p_debug);
        l_val_flag_itm :='N';
		  END;
		  --
		  --Validate if child item is present or not
      --
      IF l_ch_instance_id IS NOT NULL THEN
        l_prog_error_msg := l_prog_error_msg||'|'||'Instance Already Created For Serial Number :'||l_csi_rel_pull_tab(I).SERIAL_NUMBER;
        l_val_flag_itm :='Y';
      END IF;
      --
      log_msg('Validate if Item Relationship is created for serial_number- :'||l_csi_rel_pull_tab(i).serial_number,p_debug);
      --
		  BEGIN
		    SELECT  DISTINCT CSI.instance_id
        INTO l_rel_instance_id
        FROM mtl_system_items_b               MSI,
             csi_item_instances               CSI,
             csi_ii_relationships             cir,
             XXCREF_CS_IB_ITEM_INSTANCE       XCI
        WHERE MSI.SEGMENT1 			                  =	L_CSI_REL_PULL_TAB(I).SEGMENT1
        AND   CSI.inventory_item_id	              =	MSI.inventory_item_id
        AND   nvl(CSI.SERIAL_NUMBER,1)            = nvl(L_CSI_REL_PULL_TAB(I).SERIAL_NUMBER,1) -- need to update the substr
        AND   CSI.LAST_VLD_ORGANIZATION_ID             = l_mstr_instace_rel_rec.LAST_VLD_ORGANIZATION_ID
        AND   CIR.SUBJECT_ID                      = CSI.instance_id
        AND   CSI.INSTANCE_ID                     = XCI.S3_ID
        AND   CIR.OBJECT_ID                       = XCI.ATTRIBUTE3
        AND   CSI.instance_id                     = l_ch_instance_id;
        --
		 EXCEPTION WHEN NO_DATA_FOUND THEN
		    l_val_flag_rel :='Y';
        l_prog_error_msg :=l_prog_error_msg||'| '||'Relationship not found ,Validation Passed :' ;
			  log_msg(l_prog_error_msg,p_debug);
		 WHEN OTHERS THEN
			  l_prog_error_msg :=l_prog_error_msg||'| '||'EXCEPTION while getting item detail:'||sqlerrm ;
			  log_msg(l_prog_error_msg,'Y');
			  l_val_flag_rel :='N';
		  END;
		  --
      --============================================================================================
      log_msg('Getting Inv Item ids for child instance id SEGMENT:'||l_csi_rel_pull_tab(i).segment1
      ||': ORGANIZATION_ID :-'||l_mstr_instace_rel_rec.LAST_VLD_ORGANIZATION_ID,p_debug);
      --
      --============================================================================================
       BEGIN
         SELECT INVENTORY_ITEM_ID INTO
         l_child_item_id
         FROM MTL_SYSTEM_ITEMS_B MSI
         WHERE MSI.SEGMENT1=l_csi_rel_pull_tab(i).segment1
         AND   msi.ORGANIZATION_ID = l_mstr_instace_rel_rec.LAST_VLD_ORGANIZATION_ID;
       EXCEPTION WHEN OTHERS THEN
         l_prog_error_msg :=l_prog_error_msg||'| '||'EXCEPTION while getting child item id:'||sqlerrm ;
			   log_msg(l_prog_error_msg,'Y');
			   L_VAL_FLAG_ITM :='N';
       END;
      LOG_MSG('l_val_flag_itm:'||L_VAL_FLAG_ITM||':l_val_flag_rel'||L_VAL_FLAG_REL,P_DEBUG);
     --
     --
     --====================================================================
     LOG_MSG( 'inserting data into Relationship cursor',P_DEBUG);
     --====================================================================
     --
     IF (L_VAL_FLAG_REL='Y' AND L_VAL_FLAG_ITM='Y') THEN
       --
       IF l_ch_instance_id IS NOT NULL THEN
            log_msg(' Instance_id created is :'||l_ch_instance_id,p_debug);
            --
            --======================================================================
            log_msg('START CREATING RELATIONSHIP for event_id :'||l_csi_rel_pull_tab(i).entity_id,P_DEBUG);
            --=====================================================================
            --
            --l_inst_rel_tbl(1).relationship_id                   := v_relationship_id;
            L_REL_TBL(1).relationship_type_code            := 'COMPONENT-OF';
            L_REL_TBL(1).OBJECT_ID                         := l_mstr_instace_rel_rec.INSTANCE_ID;
            L_REL_TBL(1).SUBJECT_ID                        := l_ch_instance_id;
            L_REL_TBL(1).subject_has_child                 := 'Y';
            L_REL_TBL(1).position_reference                := NULL;
            L_REL_TBL(1).active_start_date                 := trunc(sysdate);
            L_REL_TBL(1).active_end_date                   := NULL;
            L_REL_TBL(1).display_order                     := NULL;
            L_REL_TBL(1).mandatory_flag                    := 'N';
            L_REL_TBL(1).CONTEXT                           := NULL;
            L_REL_TBL(1).attribute1                        := NULL;
            L_REL_TBL(1).attribute2                        := NULL;
            L_REL_TBL(1).attribute3                        := NULL;
            L_REL_TBL(1).attribute4                        := NULL;
            L_REL_TBL(1).attribute5                        := NULL;
            L_REL_TBL(1).attribute6                        := NULL;
            L_REL_TBL(1).attribute7                        := NULL;
            L_REL_TBL(1).attribute8                        := NULL;
            L_REL_TBL(1).attribute9                        := NULL;
            L_REL_TBL(1).attribute10                       := NULL;
            L_REL_TBL(1).attribute11                       := NULL;
            L_REL_TBL(1).attribute12                       := NULL;
            L_REL_TBL(1).attribute13                       := NULL;
            L_REL_TBL(1).attribute14                       := NULL;
            L_REL_TBL(1).attribute15                       := NULL;
            L_REL_TBL(1).object_version_number             := 1;
            l_tx_rel_rec.transaction_date                              := l_rel_trx_date;
            l_tx_rel_rec.source_transaction_date                       := l_rel_trx_date;
            l_tx_rel_rec.transaction_type_id                           := L_REL_TRX_TYP_ID;
            l_tx_rel_rec.object_version_number                         := 1;
            --
            -- calling Relationship API
            --
            log_msg('calling Relationship API',p_debug);
            --
            --
            XXCSI_LEGACY_S3_INT_PKG.create_inst_relation (p_xxcSi_inst_rel_rec            => L_REL_TBL,
                                                          P_XXCSI_TXN_REC                 => l_tx_rel_rec,
                                                          p_debug                         => p_debug,
                                                          p_status                        => x2_return_status,
                                                          P_ERR_MSG                       => X2_ERR_MSG,
                                                          P_RELATIONSHIP_ID               => L_REL_INST_ID_OUT
                                                    );

            L_REL_INST_ID_OUT :=L_REL_TBL(1).RELATIONSHIP_ID ;
            --
        END IF;--l_ch_instance_id IS NOT NULL
        LOG_MSG(l_prog_error_msg,P_DEBUG);
        --==========================================================
        LOG_MSG('Updating Status in xxssys_events table',P_DEBUG);
        --==========================================================
        --
        IF (x2_return_status ='S') THEN
            -- Calling Package to update the status to success
          xxssys_event_pkg.update_success(l_csi_rel_pull_tab(i).event_id);
          --
          --================================================================
          -- Inserting Data into xxref table XXCREF_CS_IB_ITEM_INSTANCE
          --================================================================
          --
          xxcust_convert_xref_pkg.upsert_legacy_cross_ref_table ( p_entity_name => 'INSTALL-BASE',
														p_legacy_id  	=> l_csi_rel_pull_tab(i).instance_id,
														p_s3_id      	=> l_ch_instance_id,
														p_org_id     	=> l_mstr_instace_rel_rec.LAST_VLD_ORGANIZATION_ID,
														p_attribute1 	=> l_csi_rel_pull_tab(i).sf_id,
														p_attribute2 	=> L_REL_INST_ID_OUT,
														p_attribute3 	=> l_mstr_instace_rel_rec.INSTANCE_ID,
														p_attribute4 	=> l_csi_rel_pull_tab(i).parent_id,
														p_attribute5 	=> NULL,
														p_err_code   	=> x2_return_status,
														p_err_message	=> l_prog_error_msg
													  );
            --
            l_prog_error_msg:='|'||l_prog_error_msg;
            LOG_MSG('After inserting Values in Xref Table:'||l_prog_error_msg,p_debug);
            --
          ELSE xxssys_event_pkg.process_event_error(p_event_id=>l_csi_rel_pull_tab(i).event_id,
                                p_error_system=>'CSI_INST' ,
                                p_err_message => X2_ERR_MSG
                              );
        END IF; --(x2_return_status ='S')
       --
       --
     END IF; --(L_VAL_FLAG_REL='Y'
  END LOOP;--
 END pull_relationship;
  --
END xxcsi_legacy_s3_int_pull_pkg;
