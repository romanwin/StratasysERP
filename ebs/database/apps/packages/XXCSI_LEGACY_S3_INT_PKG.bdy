CREATE OR REPLACE Package Body XXCSI_legacy_s3_INT_PKG
-- +===================================================================+
-- |                         Stratesys                                 |
-- |                                                                   |
-- +===================================================================+
-- |                                                                   |
-- |Package Name     : XXCSI_S3_LEGACY_INT_PKG                         |
-- |                                                                   |
-- |Description      : This Package is used to create instance and     |
-- |                    relationship rlating to  the same to master instance              |
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |1.0   12-08-2016   Vishal Roy       Initial code version       |
-- |         |
-- |                                                                   |
-- +===================================================================+
IS
G_NEW                   VARCHAR2(10)      := 'NEW';
G_ERROR                 VARCHAR2(10)      := 'ERROR';
G_SUCCESS               VARCHAR2(10)      := 'PROCESSED';
G_IGNORE                VARCHAR2(10)      := 'IGNORED';
--
G_USER_ID               NUMBER            := Apps.Fnd_Global.User_Id;
G_ORG_ID                NUMBER            := Apps.Fnd_Global.Org_Id;
G_REQUEST_ID            NUMBER            := Apps.Fnd_Global.Conc_Request_Id;
G_PRG_APPL_ID           NUMBER            := Apps.Fnd_Global.Prog_Appl_Id;
G_PROGRAM_ID            NUMBER            := Apps.Fnd_Global.Conc_Program_Id;
-- Dbug
--G_LOG           		VARCHAR2(1)   	  := fnd_profile.value('AFLOG_ENABLED');
--G_LOG_MODULE    		VARCHAR2(100)     := fnd_profile.value('AFLOG_MODULE');
--G_REQUEST_ID    		NUMBER            := fnd_profile.value('CONC_REQUEST_ID');
--
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
-- | Parameters       : p._msg                                          |
-- |                                                                   |
-- |                                                                   |
-- +===================================================================+
IS
BEGIN
 IF UPPER(p_debug)='Y' THEN
  apps.Fnd_File.Put_Line (apps.Fnd_File.Log, p_msg);
 END IF;
END;


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
END;
--
--

-- +===================================================================+
-- |                                                                   |
-- |Procedure Name     : create_instance                         	   |
-- |                                                                   |
-- |Description      : This procedure is used to create instance
-- |                   attach the same to master instance              |
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |Draft1A   12-08-2016   Vishal Roy       Initial code version       |
-- |         |
-- |                                                                   |
-- +===================================================================+
PROCEDURE create_instance (P_XXCSI_INST_REC 		  IN csi_datastructures_pub.instance_rec,
						   p_xxcst_ext_attrib_val_rec IN csi_datastructures_pub.extend_attrib_values_rec,
						   P_XXCSI_PARTY_rec          IN csi_datastructures_pub.party_rec,
						   P_XXCSI_party_account_rec  IN csi_datastructures_pub.party_account_rec,
						   p_xxcsi_trx_rec            IN csi_datastructures_pub.transaction_rec,
               p_instance_id              IN OUT    CSI_ITEM_INSTANCES.instance_id%TYPE,
               P_DEBUG                    VARCHAR2,
						   p_status  			            OUT VARCHAR2,
						   P_ERR_MSG                  OUT VARCHAR2
  )
IS
	l_instance_rec                    csi_datastructures_pub.instance_rec;
  L_TRX_REC                         csi_datastructures_pub.transaction_rec;
--	l_txn_rec                          p_xxcsi_trx_rec;
	--
	--lr_party_rec                       P_XXCSI_PARTY_rec;
	--lr_party_account_rec               p_xxcsi_trx_rec;
	--lr_ext_attrib_value_rec            p_xxcst_ext_attrib_val_rec;
	--
	l_ext_attrib_values_tbl             csi_datastructures_pub.extend_attrib_values_tbl;
	l_party_tbl                         csi_datastructures_pub.party_tbl;
	l_party_account_tbl                 csi_datastructures_pub.party_account_tbl;
	l_pricing_attribs_tbl               csi_datastructures_pub.pricing_attribs_tbl;
	l_org_assignments_tbl               csi_datastructures_pub.organization_units_tbl;
	l_asset_assignment_tbl              csi_datastructures_pub.instance_asset_tbl;
	x_instance_id_lst                   csi_datastructures_pub.id_tbl;
	--
	l_return_status             		VARCHAR2(1);
	l_msg_count                 		NUMBER;
	l_msg_data                  		VARCHAR2(4000);
	l_msg_index_out             		VARCHAR2(100);
	l_api_version               		CONSTANT NUMBER := 1.0;
	--
	l_error_stage               		VARCHAR2(240);
	l_start_date                		DATE;
	l_start_time                		DATE;
	BEGIN
		log_msg('-----------------------------------------------',P_DEBUG);
		log_msg ( ' Debug :Creating instance :',P_DEBUG );
		LOG_MSG('-----------------------------------------------',P_DEBUG);
		-- Initializing Variables
    --
    L_MSG_DATA                    := NULL;
    L_RETURN_STATUS               := NULL;
    --
    l_instance_rec                := P_XXCSI_INST_REC;
		l_party_tbl(1) 								:= P_XXCSI_PARTY_rec;
		--
    L_TRX_REC                     := p_xxcsi_trx_rec;
		l_error_stage 							:='Call API CSI_ITEM_INSTANCE_PUB.CREATE_ITEM_INSTANCE';
		--
		l_msg_data 									:= NULL;
		l_msg_index_out 						:= NULL;
		l_msg_count 								:= NULL;
		--
		log_msg('*== Inserting into API',p_debug);
		--
		CSI_ITEM_INSTANCE_PUB.CREATE_ITEM_INSTANCE
		(
			 p_api_version 			    => l_api_version
			,p_commit 				      => FND_API.G_FALSE
			,p_init_msg_list 		    => FND_API.G_FALSE
			,p_validation_level 	  => FND_API.G_VALID_LEVEL_FULL
			,p_instance_rec 		    => l_instance_rec
			,p_ext_attrib_values_tbl => l_ext_attrib_values_tbl
			,p_party_tbl 			      => l_party_tbl
			,p_account_tbl 			    => l_party_account_tbl
			,p_pricing_attrib_tbl   => l_pricing_attribs_tbl
			,p_org_assignments_tbl  => l_org_assignments_tbl
			,p_asset_assignment_tbl => l_asset_assignment_tbl
			,p_txn_rec 				      => L_TRX_REC
			,x_return_status 		    => l_return_status
			,x_msg_count 			      => l_msg_count
			,x_msg_data 			      => l_msg_data
		);
    -- Assigning Value in the Out Parameter
    p_status := l_return_status;
    --
        --
		IF(l_return_status IN ('E', 'U')) THEN
			FOR i IN 1..fnd_msg_pub.count_msg
			LOOP
				fnd_msg_pub.get( p_msg_index => i
				,p_encoded 	      => 'F'
				,p_data 		      => l_msg_data
				,p_msg_index_out 	=> l_msg_index_out);
				--
				LOG_MSG('l_return_status: ' || l_return_status,P_DEBUG);
				--
				LOG_MSG('l_msg_data: ' || SUBSTR(l_msg_data, 1, 250),P_DEBUG);
				L_MSG_DATA := L_MSG_DATA||'-';
			END LOOP;
			--
			ELSIF L_RETURN_STATUS ='S' THEN
        p_instance_id:=to_char(l_instance_rec.INSTANCE_ID);
        LOG_MSG('------------------------------------------',P_DEBUG);
        LOG_MSG('l_return_status: ' || l_return_status,P_DEBUG);
        LOG_MSG('l_msg_data: ' || SUBSTR(l_msg_data, 1, 250),P_DEBUG);
        LOG_MSG('The instance ID: ' || to_char(l_instance_rec.INSTANCE_ID),P_DEBUG);
        LOG_MSG('The instance Number: ' || to_char(l_instance_rec.INSTANCE_NUMBER),P_DEBUG);
        LOG_MSG('------------------------------------------',P_DEBUG);
			--
			COMMIT;
		--
		END IF;--(l_return_status IN ('E', 'U')) THEN
		--
    --
    EXCEPTION WHEN OTHERS THEN
    P_ERR_MSG :='Exception in the main bigin Block :'||SQLERRM;
    LOG_MSG(P_ERR_MSG,P_DEBUG);
	END create_instance;

-- +===================================================================+
-- |                                                                   |
-- |Procedure Name     : update_mstr_instance                          |
-- |                                                                   |
-- |Description      : This Procedure is used to update DFF of master  |
--                     instance.                       |
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |1.0      15-12-2016   Saugata(TCS)       Initial code version      |
-- |                                                                   |
-- |                                                                   |
-- +===================================================================+
PROCEDURE update_mstr_instance (p_xxcsi_inst_rec_mstr	IN csi_datastructures_pub.instance_rec,
								p_xxcsi_ext_att_val_tbl_mstr IN csi_datastructures_pub.extend_attrib_values_tbl,
								p_xxcsi_party_tbl_mstr	IN csi_datastructures_pub.party_tbl,
								p_xxcsi_account_tbl_mstr IN csi_datastructures_pub.party_account_tbl,
								p_xxcsi_pric_attr_tbl_mstr IN csi_datastructures_pub.pricing_attribs_tbl,
								p_xxcsi_org_assig_tbl_mstr IN csi_datastructures_pub.organization_units_tbl,
								p_xxcsi_asset_assig_tbl_mstr IN csi_datastructures_pub.instance_asset_tbl,
								p_xxcsi_txn_rec_mstr IN csi_datastructures_pub.transaction_rec,
								p_debug				VARCHAR2,
								p_status_mstr	OUT VARCHAR2,
								p_err_msg_mstr	OUT VARCHAR2
								)
IS 		
	l_csi_inst_rec_mstr        		  csi_datastructures_pub.instance_rec;
	l_csi_inst_rec_mstr_null   		  csi_datastructures_pub.instance_rec;
    l_ext_attrib_values_mstr          csi_datastructures_pub.extend_attrib_values_tbl;
    l_ext_attrib_values_mstr_null     csi_datastructures_pub.extend_attrib_values_tbl;
    l_party_tbl_mstr                  csi_datastructures_pub.party_tbl;
    l_party_tbl_mstr_null             csi_datastructures_pub.party_tbl;
	l_account_tbl_mstr                csi_datastructures_pub.party_account_tbl;
    l_account_tbl_mstr_null           csi_datastructures_pub.party_account_tbl;
	l_pric_attrib_tbl_mstr         	  csi_datastructures_pub.pricing_attribs_tbl;
    l_pric_attrib_tbl_mstr_null       csi_datastructures_pub.pricing_attribs_tbl;
	l_org_assig_tbl_mstr        	  csi_datastructures_pub.organization_units_tbl;
    l_org_assig_tbl_mstr_null   	  csi_datastructures_pub.organization_units_tbl;
	l_asset_assig_tbl_mstr       	  csi_datastructures_pub.instance_asset_tbl;
    l_asset_assig_tbl_mstr_null       csi_datastructures_pub.instance_asset_tbl;
	l_txn_rec_mstr                    csi_datastructures_pub.transaction_rec;
    l_txn_rec_mstr_null               csi_datastructures_pub.transaction_rec;
	l_instance_id_lst_mstr            csi_datastructures_pub.id_tbl;
    l_instance_id_lst_mstr_null       csi_datastructures_pub.id_tbl;
	
	
	l_msg_data        					VARCHAR2(2500) := NULL;
	l_init_msg_lst	  		    		VARCHAR2(500):= NULL;
	l_return_status_mstr   				VARCHAR2(1);
	l_msg_index_out             		VARCHAR2(100);
	l_api_version               		CONSTANT NUMBER := 1.0;
	l_error_stage               		VARCHAR2(240);
	l_start_date                		DATE;
	l_start_time                		DATE;
	l_validation_level           		NUMBER := NULL;
	
	x3_return_status                    VARCHAR2 (100);
	x3_msg_count						NUMBER;
	x3_msg_data                         VARCHAR2 (2000);
	
	

  BEGIN
		l_csi_inst_rec_mstr := p_xxcsi_inst_rec_mstr;
		l_ext_attrib_values_mstr := p_xxcsi_ext_att_val_tbl_mstr;
		l_party_tbl_mstr := p_xxcsi_party_tbl_mstr;
		l_account_tbl_mstr := p_xxcsi_account_tbl_mstr;
		l_pric_attrib_tbl_mstr := p_xxcsi_pric_attr_tbl_mstr;
		l_org_assig_tbl_mstr := p_xxcsi_org_assig_tbl_mstr;
		l_asset_assig_tbl_mstr := p_xxcsi_asset_assig_tbl_mstr;
		l_txn_rec_mstr := p_xxcsi_txn_rec_mstr;
		l_instance_id_lst_mstr := l_instance_id_lst_mstr_null;
		l_msg_data := NULL;
		l_init_msg_lst := NULL;
		l_validation_level := NULL;
		fnd_msg_pub.initialize;
		
		---- Calling Standard API.
		
		csi_item_instance_pub.update_item_instance(p_api_version           => 1,
                                                   p_commit                => FND_API.G_TRUE,
                                                   p_init_msg_list         => l_init_msg_lst,
                                                   p_validation_level      => l_validation_level,
                                                   p_instance_rec          => l_csi_inst_rec_mstr,
                                                   p_ext_attrib_values_tbl => l_ext_attrib_values_mstr,
                                                   p_party_tbl             => l_party_tbl_mstr,
                                                   p_account_tbl           => l_account_tbl_mstr,
                                                   p_pricing_attrib_tbl    => l_pric_attrib_tbl_mstr,
                                                   p_org_assignments_tbl   => l_org_assig_tbl_mstr,
                                                   p_asset_assignment_tbl  => l_asset_assig_tbl_mstr,
                                                   p_txn_rec               => l_txn_rec_mstr,
                                                   x_instance_id_lst       => l_instance_id_lst_mstr,
                                                   x_return_status         => x3_return_status,
                                                   x_msg_count             => x3_msg_count,
                                                   x_msg_data              => x3_msg_data);
		commit;
		
		---- Assigning value to uot parameters
		
		p_status_mstr := x3_return_status;
		
		IF(x3_return_status IN ('E', 'U')) THEN
			FOR i IN 1..fnd_msg_pub.count_msg
			LOOP
				fnd_msg_pub.get( p_msg_index => i
				,p_encoded 					  => 'F'
				,p_data 					    => l_msg_data
				,p_msg_index_out 			=> l_msg_index_out);
				--
				LOG_MSG('x3_return_status: ' || x3_return_status,P_DEBUG);
				--
				LOG_MSG('l_msg_data: ' || SUBSTR(l_msg_data, 1, 250),P_DEBUG);
				L_MSG_DATA := L_MSG_DATA||'-';
			END LOOP;
			-- Assigning to the outvariables
			x3_msg_data := SUBSTR(L_MSG_DATA,1,250);
			p_err_msg_mstr :=x3_msg_data;
			--
			ROLLBACK;
			--
			ELSIF x3_return_status ='S' THEN
			  --p_relationship_id :=to_char(x_relationship_tbl (1).relationship_id);
			  L_MSG_DATA :=x3_msg_data;
				LOG_MSG('------------------------------------------',P_DEBUG);
				LOG_MSG('x3_return_status: ' || x3_return_status,P_DEBUG);
				LOG_MSG('l_msg_data: ' || SUBSTR(l_msg_data, 1, 250),P_DEBUG);
			--	LOG_MSG('The instance ID: ' || to_char(x_relationship_tbl (1).relationship_id),P_DEBUG);
				LOG_MSG('------------------------------------------',P_DEBUG);
			--
			--
			COMMIT;
		--
		END IF;--(l_return_status IN ('E', 'U')) THEN
		
		
  
  END update_mstr_instance;	
	
--
-- +===================================================================+
-- |                                                                   |
-- |Procedure Name     : create_relationship                           |
-- |                                                                   |
-- |Description      : This procedure is used to create relationship
-- |				   between master instance and child instance	   |
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |Draft1A   12-08-2016   Vishal Roy       Initial code version       |
-- |         										|
-- |                                                                   |
-- +===================================================================+
--
PROCEDURE create_inst_relation (
	p_xxcSi_inst_rel_rec IN csi_datastructures_pub.ii_relationship_tbl,
	P_XXCSI_TXN_REC      IN csi_datastructures_pub.transaction_rec,
	P_DEBUG                  VARCHAR2,
	p_status  			     OUT VARCHAR2,
	P_ERR_MSG            OUT VARCHAR2,
  P_RELATIONSHIP_ID    OUT NUMBER
  )
IS
  --
  --
   x_instance_rec                                    csi_datastructures_pub.instance_rec;
   x_txn_rec                                         csi_datastructures_pub.transaction_rec;
   x2_txn_rec                                        csi_datastructures_pub.transaction_rec;
   x_ext_attrib_values                               csi_datastructures_pub.extend_attrib_values_tbl;
   x_party_tbl                                       csi_datastructures_pub.party_tbl;
   x_account_tbl                                     csi_datastructures_pub.party_account_tbl;
   x_pricing_attrib_tbl                              csi_datastructures_pub.pricing_attribs_tbl;
   x_org_assignments_tbl                             csi_datastructures_pub.organization_units_tbl;
   x_asset_assignment_tbl                            csi_datastructures_pub.instance_asset_tbl;
   x_relationship_tbl                                csi_datastructures_pub.ii_relationship_tbl;
   x_return_status                                   VARCHAR2 (100);
   x_msg_count                                       NUMBER;
   x_msg_data                                        VARCHAR2 (2000);
   x_created_manually_flag                           VARCHAR2 (100);
   n                                                 NUMBER := 1;
   l_instance_id                                     NUMBER;
   p_commit                                          VARCHAR2 (5);
   p2_commit                                         VARCHAR2 (5);
   p_validation_level                                NUMBER;
   p_init_msg_lst                                    VARCHAR2 (500);
   v_instance_party_id                               NUMBER;
   v_ip_account_id                                   NUMBER;
   v_relationship_id                                 NUMBER;
   v_success                                         VARCHAR2 (1) := 'T';
   x2_return_status                                  VARCHAR2 (100);
   x2_msg_count                                      NUMBER;
   x2_msg_data                                       VARCHAR2 (2000);
   p2_validation_level                               NUMBER;
   p2_init_msg_lst                                   VARCHAR2 (500);
   l_msg_data                                        VARCHAR2(4000);
   l_msg_count                 		                   NUMBER;
	 l_msg_index_out             		                   VARCHAR2(100);
BEGIN
	x_relationship_tbl      := p_xxcSi_inst_rel_rec;
	x_txn_rec               := P_XXCSI_TXN_REC;
	P_STATUS                := NULL;
  L_MSG_DATA              := NULL;
  X2_RETURN_STATUS        := NULL;
  l_msg_count             := NULL;
  x2_msg_data             := NULL;
	--
	--
      csi_ii_relationships_pub.create_relationship (p_api_version                 => 1.0
                                                  , p_commit                      => p2_commit
                                                  , p_init_msg_list               => p2_init_msg_lst
                                                  , p_validation_level            => p2_validation_level
                                                  , p_relationship_tbl            => x_relationship_tbl
                                                  , p_txn_rec                     => x_txn_rec
                                                  , x_return_status               => x2_return_status
                                                  , x_msg_count                   => x2_msg_count
                                                  , x_msg_data                    => x2_msg_data
                                                );
    --
		   p_status := X2_RETURN_STATUS;
    --
    --
		IF(x2_return_status IN ('E', 'U')) THEN
			FOR i IN 1..fnd_msg_pub.count_msg
			LOOP
				fnd_msg_pub.get( p_msg_index => i
				,p_encoded 					  => 'F'
				,p_data 					    => l_msg_data
				,p_msg_index_out 			=> l_msg_index_out);
				--
				LOG_MSG('x2_return_status: ' || x2_return_status,P_DEBUG);
				--
				LOG_MSG('l_msg_data: ' || SUBSTR(l_msg_data, 1, 250),P_DEBUG);
				L_MSG_DATA := L_MSG_DATA||'-';
			END LOOP;
			-- Assigning to the outvariables
			x2_msg_data := SUBSTR(L_MSG_DATA,1,250);
			P_ERR_MSG :=x2_msg_data;
			--
			ROLLBACK;
			--
			ELSIF x2_return_status ='S' THEN
			  P_RELATIONSHIP_id:=to_char(x_relationship_tbl (1).relationship_id);
			  L_MSG_DATA :=x_msg_data;
				LOG_MSG('------------------------------------------',P_DEBUG);
				LOG_MSG('x2_return_status: ' || x2_return_status,P_DEBUG);
				LOG_MSG('l_msg_data: ' || SUBSTR(l_msg_data, 1, 250),P_DEBUG);
			--	LOG_MSG('The instance ID: ' || to_char(x_relationship_tbl (1).relationship_id),P_DEBUG);
				LOG_MSG('------------------------------------------',P_DEBUG);
			--
			--
			COMMIT;
		--
		END IF;--(l_return_status IN ('E', 'U')) THEN
  -- END IF;
END create_inst_relation ; --
--
--
END XXCSI_legacy_s3_INT_PKG;
