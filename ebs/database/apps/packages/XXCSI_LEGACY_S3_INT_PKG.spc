CREATE OR REPLACE Package XXCSI_LEGACY_S3_INT_PKG
-- +===================================================================+
-- |                         Stratesys                                 |
-- |                                                                   |
-- +===================================================================+
-- |                                                                   |
-- |Program Name     : XXCSI_LEGACY_S3_INT_PKG                         |
-- |                                                                   |
-- |Description      : This Package is used to create instance  and
-- |				   relationship
-- |                   attach the same to master instance              |
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |Draft1A   12-08-2016   Vishal Roy       Initial code version       |
-- |         														   |
-- |                                                                   |
-- +===================================================================+
IS
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
						   P_DEBUG                        VARCHAR2,
						   p_status  			            OUT VARCHAR2,
						   P_ERR_MSG                  OUT VARCHAR2
  );
-- +===================================================================+
-- |                                                                   |
-- |Procedure Name     : update_mstr_instance                      	   |
-- |                                                                   |
-- |Description      : This procedure is used to create instance
-- |                   attach the same to master instance              |
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |Draft1A   15-12-2016   Saugata Mitra       Initial code version    |
-- |         														   |
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
								);    
  

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
PROCEDURE create_inst_relation (
	p_xxcSi_inst_rel_rec IN csi_datastructures_pub.ii_relationship_tbl,
	P_XXCSI_TXN_REC      IN csi_datastructures_pub.transaction_rec,
	P_DEBUG                  VARCHAR2,
	p_status  			     OUT VARCHAR2,
	P_ERR_MSG            OUT VARCHAR2,
  P_RELATIONSHIP_ID    OUT NUMBER
  );
END;
