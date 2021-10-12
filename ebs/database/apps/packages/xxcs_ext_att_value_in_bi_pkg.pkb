create or replace package body XXCS_EXT_ATT_VALUE_IN_BI_PKG is

--------------------------------------------------------------------
--  name:            XXCS_EXT_ATT_VALUE_IN_BI_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   28/02/2010
--------------------------------------------------------------------
--  purpose :        Set Extra attributes value In BI                   
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  28/02/2010  Dalit A. Raviv    initial build
--------------------------------------------------------------------  

  --------------------------------------------------------------------
  --  name:            upd_ib_refurbished_flag 
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   28/02/2010
  --------------------------------------------------------------------
  --  purpose :        Program will locate population to update, call 
  --                   API to update refurbished flag at IB.
  --                   Set Refurbished flag to YES in case of Refurbish SR existance
  --                   benefit - Identify refurbish printers in IB
  --                   Create program that based on reate_extended_attrib_values API
  --                   to update IB in case of existing SR
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  28/02/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  PROCEDURE upd_ib_refurbished_flag (p_error_desc OUT VARCHAR2,
                                     p_error_code OUT VARCHAR2) is
                                     /*(errbuf  OUT VARCHAR2,
                                     retcode OUT VARCHAR2) is */
       
    CURSOR get_refurbish_population_c IS
      select ciab.customer_product_id instance_id,
             'OBJ_REFURBISH' attribute_code,
             '13000' attribute_id,
             --'Y' attribute_value,
             to_char(ciab.close_date, 'DD-MON-YYYY') attribute_value,
             sysdate active_start_date
        from cs_incidents_all_b      ciab,
             cs_incident_statuses_b  cisb,
             cs_incident_statuses_tl cist,
             csi_item_instances      cii
       where ciab.incident_status_id = cisb.incident_status_id
         and cisb.close_flag = 'Y'
         and cisb.incident_status_id = cist.incident_status_id
         and cist.language = 'US'
         and cist.name != 'Cancelled'
         and ciab.customer_product_id = cii.instance_id
         and ciab.incident_type_id = 11016
         and cii.instance_id not in
             (select civ.instance_id
                from csi_iea_values civ, csi_i_extended_attribs cie
               where civ.attribute_id = cie.attribute_id
                 and cie.attribute_code = 'OBJ_REFURBISH');
         --and  cii.instance_id = 14452; fot test                  
    
    x_return_status      VARCHAR2(2000) := NULL;
    x_msg_count          NUMBER         := NULL;
    x_msg_data           VARCHAR2(2000) := NULL;
    l_msg_index          NUMBER         := 0;
    l_msg_count          NUMBER         := 0;
    l_count              NUMBER         := 0;
    l_attribute_value_id NUMBER         := 0;
    l_validation_level   NUMBER         := NULL;
    l_ext_attrib_values csi_datastructures_pub.extend_attrib_values_tbl;
    l_txn_rec           csi_datastructures_pub.transaction_rec;
  BEGIN
       
    -- populate l_ext_attrib_values table variable
    FOR get_refurbish_population_r in get_refurbish_population_c loop
      --l_ext_attrib_values := null;
      -- init collection variables
      l_ext_attrib_values.DELETE;
      --l_txn_rec.DELETE;
    
      l_count := 1;
      -- get attribute value id       
      SELECT csi_iea_values_s.NEXTVAL
      INTO   l_attribute_value_id
      FROM   dual;
                 
      l_ext_attrib_values(l_count).attribute_value_id := l_attribute_value_id;
      l_ext_attrib_values(l_count).instance_id        := get_refurbish_population_r.instance_id;
      l_ext_attrib_values(l_count).attribute_id       := get_refurbish_population_r.attribute_id;
      l_ext_attrib_values(l_count).attribute_code     := get_refurbish_population_r.attribute_code;
      l_ext_attrib_values(l_count).attribute_value    := get_refurbish_population_r.attribute_value;
      l_ext_attrib_values(l_count).active_start_date  := get_refurbish_population_r.active_start_date;
     
      --TXN 
      l_txn_rec.transaction_id              := NULL;
      l_txn_rec.transaction_date            := trunc(SYSDATE);
      l_txn_rec.source_transaction_date     := trunc(SYSDATE);
      l_txn_rec.transaction_type_id         := 1;
      l_txn_rec.txn_sub_type_id             := NULL;
      l_txn_rec.source_group_ref_id         := NULL;
      l_txn_rec.source_group_ref            := '';
      l_txn_rec.source_header_ref_id        := NULL;
      l_txn_rec.source_header_ref           := '';
      l_txn_rec.source_line_ref_id          := NULL;
      l_txn_rec.source_line_ref             := '';
      l_txn_rec.source_dist_ref_id1         := NULL;
      l_txn_rec.source_dist_ref_id2         := NULL;
      l_txn_rec.inv_material_transaction_id := NULL;
      l_txn_rec.transaction_quantity        := NULL;
      l_txn_rec.transaction_uom_code        := '';
      l_txn_rec.transacted_by               := NULL;
      l_txn_rec.transaction_status_code     := '';
      l_txn_rec.transaction_action_code     := '';
      l_txn_rec.message_id                  := NULL;
      l_txn_rec.object_version_number       := '';
      l_txn_rec.split_reason_code           := '';
      -- call to API   
      CSI_ITEM_INSTANCE_PUB.create_extended_attrib_values -- update_extended_attrib_values --
                            ( p_api_version         => 1,
                              p_commit              => fnd_api.g_false, -- 'F'
                              p_init_msg_list       => 'T',
                              p_validation_level    => l_validation_level,
                              p_ext_attrib_tbl      => l_ext_attrib_values,
                              p_txn_rec             => l_txn_rec,
                              x_return_status       => x_return_status,
                              x_msg_count           => x_msg_count,
                              x_msg_data            => x_msg_data
                            );                      
      
      IF NOT(x_return_status = FND_API.G_RET_STS_SUCCESS) THEN -- <> 'S'
        l_msg_index := 1;
        l_msg_count := x_msg_count;
        WHILE l_msg_count > 0 LOOP
          x_msg_data := FND_MSG_PUB.GET( l_msg_count, FND_API.G_FALSE );
          fnd_file.put_line(fnd_file.log,
                'Failed Update Refurbish '||chr(10)||
                ' l_msg_index   '||l_msg_index|| chr(10)||
                ' Instance      '||to_char(get_refurbish_population_r.instance_id) || chr(10)||
                ' Atribute      '||get_refurbish_population_r.attribute_id || chr(10)||
                ' Error Message '||x_msg_data || chr(10));
          l_msg_index := l_msg_index + 1;
          l_msg_count := l_msg_count - 1;
        END LOOP;
        rollback;
        p_error_desc := 'Problem Update IB Refurbished Flag';
        p_error_code := 2;
         
      ELSE
        fnd_file.put_line(fnd_file.log,
                'Success Update Refurbished Flag'||
                ' Instance '  ||to_char(get_refurbish_population_r.instance_id) || chr(10)||
                ' Atribute '  ||get_refurbish_population_r.attribute_id || chr(10));
        commit;                
      END IF;                            
    END LOOP;    
  END upd_ib_refurbished_flag;
  
  --------------------------------------------------------------------
  --  name:            create_FCO_Date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/03/2010
  --------------------------------------------------------------------
  --  purpose :        Call API to update refurbished flag at IB.
  --                   Set FCO date according to closure date of SR.
  --                   Create program that based on create_extended_attrib_values API
  --                   to update IB in case of existing SR
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/03/2010  Dalit A. Raviv    initial build
  --  1.1  11/11/2012  Adi Safin         Change logic. support multiple FCO's 
  --                                     use the category id of the SR instead the value set                                                
  -------------------------------------------------------------------- 
  procedure create_FCO_Date         (p_error_desc OUT VARCHAR2,
                                     p_error_code OUT VARCHAR2) is
                                     
    CURSOR get_foc_date_population_c IS
    --  1.1  11/11/2012  Adi Safin 
      select ciab.customer_product_id  instance_id,
             cie1.attribute_code       attribute_code,
             cie1.attribute_id         attribute_id,
             to_char(ciab.close_date,  'DD-MON-YYYY') attribute_value,
             sysdate                   active_start_date
        from cs_incidents_all_b        ciab,
             cs_incident_statuses_b    cisb,
             cs_incident_statuses_tl   cist,
             csi_item_instances        cii,
             csi_i_extended_attribs    cie1
       where ciab.incident_status_id   = cisb.incident_status_id
         and cisb.close_flag           = 'Y'
         and cisb.incident_status_id   = cist.incident_status_id
         and cist.language             = 'US'
         and cist.name                 != 'Cancelled'
         and ciab.customer_product_id  = cii.instance_id
         --AND ciab.incident_number ='58239'
         AND cie1.Attribute_Name IN (ciab.external_attribute_5,ciab.external_attribute_12,ciab.external_attribute_13)
         and ciab.category_id     = cie1.item_category_id
         and cii.instance_id           not in ( select civ.instance_id
                                                from   csi_iea_values         civ, 
                                                       csi_i_extended_attribs cie
                                               where   civ.attribute_id       = cie.attribute_id
                                                 and   cie.attribute_code     = cie1.attribute_code);
                                                
-- Remark By Adi at 11/11/2012                                                 
/*     select ciab.customer_product_id  instance_id,
             cie1.attribute_code       attribute_code,
             cie1.attribute_id         attribute_id,
             to_char(ciab.close_date,  'DD-MON-YYYY') attribute_value,
             sysdate                   active_start_date
        from cs_incidents_all_b        ciab,
             cs_incident_statuses_b    cisb,
             cs_incident_statuses_tl   cist,
             csi_item_instances        cii,
             csi_i_extended_attribs    cie1,
             fnd_flex_values           flv
       where ciab.incident_status_id   = cisb.incident_status_id
         and cisb.close_flag           = 'Y'
         and cisb.incident_status_id   = cist.incident_status_id
         and cist.language             = 'US'
         and cist.name                 != 'Cancelled'
         and ciab.customer_product_id  = cii.instance_id
         and ciab.external_attribute_5 is not null
         and ciab.external_attribute_5 = flv.flex_value
         and flv.attribute1            = to_char(cie1.attribute_id)
         and cii.instance_id           not in ( select civ.instance_id
                                                from   csi_iea_values         civ, 
                                                       csi_i_extended_attribs cie
                                               where   civ.attribute_id       = cie.attribute_id
                                                 and   cie.attribute_code     = cie1.attribute_code);*/                                                 
  --end   1.1  11/11/2012  Adi Safin
    x_return_status      VARCHAR2(2000) := NULL;
    x_msg_count          NUMBER         := NULL;
    x_msg_data           VARCHAR2(2000) := NULL;
    l_msg_index          NUMBER         := 0;
    l_msg_count          NUMBER         := 0;
    l_count              NUMBER         := 0;
    l_attribute_value_id NUMBER         := 0;
    l_validation_level   NUMBER         := NULL;
    l_ext_attrib_values  csi_datastructures_pub.extend_attrib_values_tbl;
    l_txn_rec            csi_datastructures_pub.transaction_rec;
  
  begin
    -- populate l_ext_attrib_values table variable
    FOR get_foc_date_population_r in get_foc_date_population_c loop
      --l_ext_attrib_values := null;
      -- init collection variables
      l_ext_attrib_values.DELETE;
      --l_txn_rec.DELETE;
    
      l_count := 1;
      -- get attribute value id       
      SELECT csi_iea_values_s.NEXTVAL
      INTO   l_attribute_value_id
      FROM   dual;
                 
      l_ext_attrib_values(l_count).attribute_value_id := l_attribute_value_id;
      l_ext_attrib_values(l_count).instance_id        := get_foc_date_population_r.instance_id;
      l_ext_attrib_values(l_count).attribute_id       := get_foc_date_population_r.attribute_id;
      l_ext_attrib_values(l_count).attribute_code     := get_foc_date_population_r.attribute_code;
      l_ext_attrib_values(l_count).attribute_value    := get_foc_date_population_r.attribute_value;
      l_ext_attrib_values(l_count).active_start_date  := get_foc_date_population_r.active_start_date;
     
      --TXN 
      l_txn_rec.transaction_id              := NULL;
      l_txn_rec.transaction_date            := trunc(SYSDATE);
      l_txn_rec.source_transaction_date     := trunc(SYSDATE);
      l_txn_rec.transaction_type_id         := 1;
      l_txn_rec.txn_sub_type_id             := NULL;
      l_txn_rec.source_group_ref_id         := NULL;
      l_txn_rec.source_group_ref            := '';
      l_txn_rec.source_header_ref_id        := NULL;
      l_txn_rec.source_header_ref           := '';
      l_txn_rec.source_line_ref_id          := NULL;
      l_txn_rec.source_line_ref             := '';
      l_txn_rec.source_dist_ref_id1         := NULL;
      l_txn_rec.source_dist_ref_id2         := NULL;
      l_txn_rec.inv_material_transaction_id := NULL;
      l_txn_rec.transaction_quantity        := NULL;
      l_txn_rec.transaction_uom_code        := '';
      l_txn_rec.transacted_by               := NULL;
      l_txn_rec.transaction_status_code     := '';
      l_txn_rec.transaction_action_code     := '';
      l_txn_rec.message_id                  := NULL;
      l_txn_rec.object_version_number       := '';
      l_txn_rec.split_reason_code           := '';
      -- call to API   
      CSI_ITEM_INSTANCE_PUB.create_extended_attrib_values -- update_extended_attrib_values --
                            ( p_api_version         => 1,
                              p_commit              => fnd_api.g_false, -- 'F'
                              p_init_msg_list       => 'T',
                              p_validation_level    => l_validation_level,
                              p_ext_attrib_tbl      => l_ext_attrib_values,
                              p_txn_rec             => l_txn_rec,
                              x_return_status       => x_return_status,
                              x_msg_count           => x_msg_count,
                              x_msg_data            => x_msg_data
                            );                      
      
      IF NOT(x_return_status = FND_API.G_RET_STS_SUCCESS) THEN -- <> 'S'
        l_msg_index := 1;
        l_msg_count := x_msg_count;
        WHILE l_msg_count > 0 LOOP
          x_msg_data := FND_MSG_PUB.GET( l_msg_count, FND_API.G_FALSE );
          fnd_file.put_line(fnd_file.log,
                'Failed Update FCO '||chr(10)||
                ' l_msg_index   '||l_msg_index|| chr(10)||
                ' Instance      '||to_char(get_foc_date_population_r.instance_id) || chr(10)||
                ' Atribute      '||get_foc_date_population_r.attribute_id || chr(10)||
                ' Error Message '||x_msg_data || chr(10));
          l_msg_index := l_msg_index + 1;
          l_msg_count := l_msg_count - 1;
        END LOOP;
        rollback;
        p_error_desc := 'Problem Update FOC Date';
        p_error_code := 2;
         
      ELSE
        fnd_file.put_line(fnd_file.log,
                'Success Update FOC Date'||
                ' Instance '  ||to_char(get_foc_date_population_r.instance_id) || chr(10)||
                ' Atribute '  ||get_foc_date_population_r.attribute_id || chr(10));
        commit;                
      END IF;                            
    END LOOP;
    
  end create_FCO_Date;                                     
  
  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/03/2010
  --------------------------------------------------------------------
  --  purpose :        Procedure that will be called from concurrent
  --                   will run each day periodic (one time each day).
  --                   will call to refurbish procedure and FCO Date procedure
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/03/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                             
  Procedure main                    (errbuf       OUT VARCHAR2,
                                     retcode      OUT VARCHAR2) is 
  
    l_error_desc varchar2(1000) := null;
    l_error_code varchar2(100)  := '0';
                                     
  begin
    
    -- Refurbish
    fnd_file.put_line(fnd_file.log,'-------- START REFURBISHED FLAG --------');
    upd_ib_refurbished_flag (p_error_desc => l_error_desc,
                             p_error_code => l_error_code);
    
    if l_error_code <> '0' then
      retcode := l_error_code;
      errbuf  := l_error_desc;
    end if;                                                    
    fnd_file.put_line(fnd_file.log,'-------- END   REFURBISHED FLAG --------');
    
    -- FOC Date
    l_error_desc := null;
    l_error_code := '0';
    fnd_file.put_line(fnd_file.log,'-------- START FOC DATE FLAG --------');
    create_FCO_Date (p_error_desc => l_error_desc,
                     p_error_code => l_error_code);

    if l_error_code <> '0' then
      retcode := l_error_code;
      errbuf  := l_error_desc;    
    end if;                                                    
    fnd_file.put_line(fnd_file.log,'-------- END   FOC DATE FLAG --------');
  end main;                                      
                                    
  --------------------------------------------------------------------
  --  name:            internet_sample 
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   01/03/2010
  --------------------------------------------------------------------
  --  purpose :        Sample from Internet - for my lerning
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/03/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------  
  procedure internet_sample (errbuf  OUT VARCHAR2,
                             retcode OUT VARCHAR2) is 

    -- Variables needed to call the Item Instance update API
    l_api_version CONSTANT NUMBER := 1.0;
    l_msg_count             NUMBER;
    l_msg_data              VARCHAR2(4000);
    l_msg_index             NUMBER;
    l_return_status         VARCHAR2(5);
    l_instance_id_lst       csi_datastructures_pub.id_tbl;
    l_instance_header_rec   csi_datastructures_pub.instance_header_rec;
    l_party_header_tbl      csi_datastructures_pub.party_header_tbl;
    l_party_acct_header_tbl csi_datastructures_pub.party_account_header_tbl;
    l_org_unit_header_tbl   csi_datastructures_pub.org_units_header_tbl;
    l_instance_rec          csi_datastructures_pub.instance_rec;
    l_party_tbl             csi_datastructures_pub.party_tbl;
    l_account_tbl           csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl    csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl   csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl  csi_datastructures_pub.instance_asset_tbl;
    l_ext_attrib_values_tbl csi_datastructures_pub.extend_attrib_values_tbl;
    l_pricing_attribs_tbl   csi_datastructures_pub.pricing_attribs_tbl;
    l_ext_attrib_def_tbl    csi_datastructures_pub.extend_attrib_tbl;
    l_asset_header_tbl      csi_datastructures_pub.instance_asset_header_tbl;
    l_txn_rec               csi_datastructures_pub.transaction_rec;
    lc_init_msg_lst         VARCHAR2(1) := 'T';
    ln_validation_level     NUMBER;
    lc_error_text           VARCHAR2(4000);
    --lc_status_code          VARCHAR2(2000);

    l_instance_header_rec_clr   csi_datastructures_pub.instance_header_rec;
    l_party_header_tbl_clr      csi_datastructures_pub.party_header_tbl;
    l_party_acct_header_tbl_clr csi_datastructures_pub.party_account_header_tbl;
    l_org_unit_header_tbl_clr   csi_datastructures_pub.org_units_header_tbl;
    l_instance_rec_clr          csi_datastructures_pub.instance_rec;
    l_party_tbl_clr             csi_datastructures_pub.party_tbl;
    l_account_tbl_clr           csi_datastructures_pub.party_account_tbl;
    l_pricing_attrib_tbl_clr    csi_datastructures_pub.pricing_attribs_tbl;
    l_org_assignments_tbl_clr   csi_datastructures_pub.organization_units_tbl;
    l_asset_assignment_tbl_clr  csi_datastructures_pub.instance_asset_tbl;
    l_ext_attrib_values_tbl_clr csi_datastructures_pub.extend_attrib_values_tbl;
    l_pricing_attribs_tbl_clr   csi_datastructures_pub.pricing_attribs_tbl;
    l_ext_attrib_def_tbl_clr    csi_datastructures_pub.extend_attrib_tbl;
    l_asset_header_tbl_clr      csi_datastructures_pub.instance_asset_header_tbl;
    l_txn_rec_clr               csi_datastructures_pub.transaction_rec;

    j                            BINARY_INTEGER := 0;
    ln_rec_count                 NUMBER := 0;
    
    l_attribute_value_id         number := null;
    
    CURSOR csi_cur IS
      --get_refurbish_population_c IS
      select ciab.customer_product_id instance_id,
             cie.attribute_code,
             cie.attribute_id,
             'Y' attribute_value,
             sysdate active_start_date
        from cs_incidents_all_b      ciab,
             cs_incident_statuses_b  cisb,
             cs_incident_statuses_tl cist,
             csi_iea_values          civ,
             csi_i_extended_attribs  cie
       where ciab.incident_status_id = cisb.incident_status_id
         and cisb.close_flag         = 'Y'
         and cisb.incident_status_id = cist.incident_status_id
         and cist.language           = 'US'
         and cist.name               != 'Cancelled'
         and civ.instance_id         = ciab.customer_product_id
         and civ.attribute_id        = cie.attribute_id
         and cie.attribute_code      = 'OBJ_REFURBISH'
         and ciab.incident_type_id   = 11016  -- !!!!!!!!!!!!!! to change as Roman will tell
         and civ.attribute_value     is null
         and ciab.incident_id        = 12744; -- For the sample - to be removed

  BEGIN

    --Initialize the collections
    l_instance_header_rec   := l_instance_header_rec_clr;
    l_party_header_tbl      := l_party_header_tbl_clr;
    l_party_acct_header_tbl := l_party_acct_header_tbl_clr;
    l_org_unit_header_tbl   := l_org_unit_header_tbl_clr;
    l_instance_rec          := l_instance_rec_clr;
    l_party_tbl             := l_party_tbl_clr;
    l_account_tbl           := l_account_tbl_clr;
    l_pricing_attrib_tbl    := l_pricing_attrib_tbl_clr;
    l_org_assignments_tbl   := l_org_assignments_tbl_clr;
    l_asset_assignment_tbl  := l_asset_assignment_tbl_clr;
    l_ext_attrib_values_tbl := l_ext_attrib_values_tbl_clr;
    l_pricing_attribs_tbl   := l_pricing_attribs_tbl_clr;
    l_ext_attrib_def_tbl    := l_ext_attrib_def_tbl_clr;
    l_asset_header_tbl      := l_asset_header_tbl_clr;
    l_txn_rec               := l_txn_rec_clr;

    FOR csi_rec IN csi_cur LOOP
    
      l_instance_header_rec.instance_id := csi_rec.instance_id;
    
      --Set Org context 
      okc_context.set_okc_org_context(81, 90);
      csi_item_instance_pub.get_item_instance_details(p_api_version           => l_api_version,
                                                      p_commit                => fnd_api.g_false,
                                                      p_init_msg_list         => fnd_api.g_true,
                                                      p_validation_level      => fnd_api.g_valid_level_full,
                                                      p_instance_rec          => l_instance_header_rec,
                                                      p_get_parties           => fnd_api.g_false,
                                                      p_party_header_tbl      => l_party_header_tbl,
                                                      p_get_accounts          => fnd_api.g_false,
                                                      p_account_header_tbl    => l_party_acct_header_tbl,
                                                      p_get_org_assignments   => fnd_api.g_false, --fnd_api.g_true,
                                                      p_org_header_tbl        => l_org_unit_header_tbl,
                                                      p_get_pricing_attribs   => fnd_api.g_false,
                                                      p_pricing_attrib_tbl    => l_pricing_attribs_tbl,
                                                      p_get_ext_attribs       => fnd_api.g_true, --fnd_api.g_false,
                                                      p_ext_attrib_tbl        => l_ext_attrib_values_tbl,
                                                      p_ext_attrib_def_tbl    => l_ext_attrib_def_tbl,
                                                      p_get_asset_assignments => fnd_api.g_false,
                                                      p_asset_header_tbl      => l_asset_header_tbl,
                                                      p_resolve_id_columns    => fnd_api.g_false,
                                                      p_time_stamp            => SYSDATE,
                                                      x_return_status         => l_return_status,
                                                      x_msg_count             => l_msg_count,
                                                      x_msg_data              => l_msg_data);
      lc_error_text              := NULL;
      l_instance_rec.instance_id := csi_rec.instance_id;
      --Get the last transaction date to make sure that source_transaction_date is greater than the latest transaction date.
      l_instance_rec.object_version_number := nvl(l_instance_header_rec.object_version_number,1);
      l_txn_rec.source_transaction_date    := SYSDATE;
      l_txn_rec.transaction_type_id        := 8; --Id for DATA_CORRECTION transaction type
    
      j := 0;
    
      --Change extra attributes value details
      IF l_ext_attrib_values_tbl.COUNT > 0 THEN
        FOR i IN l_ext_attrib_values_tbl.FIRST .. l_ext_attrib_values_tbl.LAST LOOP
          IF l_ext_attrib_values_tbl(i).instance_id is not null then
            
            l_ext_attrib_values_tbl(j).attribute_id      := csi_rec.attribute_id;
            l_ext_attrib_values_tbl(j).attribute_code    := csi_rec.attribute_code;
            l_ext_attrib_values_tbl(j).attribute_value   := csi_rec.attribute_value;
            l_ext_attrib_values_tbl(j).active_start_date := csi_rec.active_start_date;
            
          END IF;
        END LOOP;
      ELSE
      
        SELECT csi_iea_values_s.NEXTVAL
        INTO   l_attribute_value_id
        FROM   dual;
                   
        l_ext_attrib_values_tbl(j).attribute_value_id := l_attribute_value_id;  
        l_ext_attrib_values_tbl(j).instance_id        := csi_rec.instance_id;
        l_ext_attrib_values_tbl(j).attribute_id       := csi_rec.attribute_id;
        l_ext_attrib_values_tbl(j).attribute_code     := csi_rec.attribute_code;
        l_ext_attrib_values_tbl(j).attribute_value    := csi_rec.attribute_value;
        l_ext_attrib_values_tbl(j).active_start_date  := csi_rec.active_start_date;
      END IF;
      -- Call instance update API if a serial no. is to be updated
      csi_item_instance_pub.update_item_instance(p_api_version           => l_api_version,
                                                 p_commit                => 'F', --Handled outside API
                                                 p_init_msg_list         => lc_init_msg_lst,
                                                 p_validation_level      => ln_validation_level,
                                                 p_instance_rec          => l_instance_rec,
                                                 p_ext_attrib_values_tbl => l_ext_attrib_values_tbl, --Null
                                                 p_party_tbl             => l_party_tbl,             --Null
                                                 p_account_tbl           => l_account_tbl,           --Null
                                                 p_pricing_attrib_tbl    => l_pricing_attrib_tbl,    --Null
                                                 p_org_assignments_tbl   => l_org_assignments_tbl,   --Null
                                                 p_asset_assignment_tbl  => l_asset_assignment_tbl,  
                                                 p_txn_rec               => l_txn_rec,               --Null
                                                 x_instance_id_lst       => l_instance_id_lst,
                                                 x_return_status         => l_return_status,
                                                 x_msg_count             => l_msg_count,
                                                 x_msg_data              => l_msg_data);
      IF l_return_status != 'S' THEN
        fnd_file.put_line(fnd_file.log,
                'Error updating the install base for IB# '||
                ' Instance '  ||to_char(csi_rec.instance_id) || chr(10)||
                ' Atribute '  ||csi_rec.attribute_id || chr(10));
      
        --dbms_output.put_line('Error updating the install base for IB# ' ||
        --                     csi_rec.instance_id);
        FOR i IN 1 .. l_msg_count LOOP
          fnd_msg_pub.get(p_msg_index     => -1,
                          p_encoded       => 'F',
                          p_data          => l_msg_data,
                          p_msg_index_out => l_msg_index);
          fnd_file.put_line(fnd_file.log, 'Error Message '||l_msg_data || chr(10));
          --dbms_output.put_line(l_msg_data);
        END LOOP;
        --lc_status_code := 'ERROR UPDATING IB';
      ELSE
        ln_rec_count := ln_rec_count + 1;
        fnd_file.put_line(fnd_file.log, 'Install base update successful for IB# '||csi_rec.instance_id || chr(10));
        --dbms_output.put_line('Install base update successful for IB# ' || csi_rec.instance_id);
        --lc_status_code := 'IB UPDATED SUCCESSFULLY';
      END IF;
    END LOOP;
    fnd_file.put_line(fnd_file.log, 'Successfully updated '||ln_rec_count ||' install base records.'|| chr(10));
    --dbms_output.put_line('Successfully updated ' || ln_rec_count ||
    --                     ' install base records.');
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error updating the install base '||SQLCODE || ': ' || SQLERRM);
      errbuf  := 'Error updating the install base';
      retcode := 2;
      --dbms_output.put_line(SQLCODE || ': ' || SQLERRM);
  END;

 
end XXCS_EXT_ATT_VALUE_IN_BI_PKG;
/
