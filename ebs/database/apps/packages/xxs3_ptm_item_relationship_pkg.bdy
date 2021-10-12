CREATE OR REPLACE PACKAGE BODY xxs3_ptm_item_relationship_pkg AS

  ----------------------------------------------------------------------------
  --  name:            xxs3_ptm_item_cross_ref_pkg
  --  create by:       Mishal Kumar
  --  Revision:        1.0
  --  creation date:   24/06/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract Item Cross References fields
  --                   from Legacy system
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  24/06/2016  Mishal Kumar                 Initial build
  ----------------------------------------------------------------------------
  REPORT_ERROR EXCEPTION;
  G_REQUEST_ID CONSTANT NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Item Cross Reference Fields fields and insert into
  --           staging table xxs3_ptm_item_cross_ref
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE item_relationship_extract(x_errbuf  OUT VARCHAR2,
                               x_retcode OUT NUMBER
                               /*p_email_id IN VARCHAR2,*/) IS
    --l_request_id         NUMBER := fnd_global.conc_request_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_counter            NUMBER;
    --
    CURSOR cur_item_relation_extract IS
SELECT DISTINCT (SELECT organization_code
                   FROM org_organization_definitions
                  WHERE organization_id = M.organization_id) organization_code,
                m.organization_id,
                mi1.segment1 item,
                mi2.segment1 related_item,
                m.relationship_type_id,
                (SELECT f.meaning
                   FROM fnd_lookup_values f
                  WHERE f.lookup_type = 'MTL_RELATIONSHIP_TYPES'
                    AND F.LANGUAGE = 'US'
                    AND f.lookup_code = m.relationship_type_id) relationship_type,
                m.reciprocal_flag,
                m.planning_enabled_flag,
                m.start_date,
                m.end_date,
                m.attr_char1,
                m.attr_char2,
                m.attr_char3,
                m.attr_char4,
                m.attr_char5,
                m.attr_char6,
                m.attr_char7,
                m.attr_char8,
                m.attr_char9,
                m.attr_char10,
                m.attr_num1,
                m.attr_num2,
                m.attr_num3,
                m.attr_num4,
                m.attr_num5,
                m.attr_num6,
                m.attr_num7,
                m.attr_num8,
                m.attr_num9,
                m.attr_num10,
                m.attr_date1,
                m.attr_date2,
                m.attr_date3,
                m.attr_date4,
                m.attr_date5,
                m.attr_date6,
                m.attr_date7,
                m.attr_date8,
                m.attr_date9,
                m.attr_date10
  FROM mtl_related_items_all_v m,
       mtl_system_items_b      mi1,
       mtl_system_items_b      mi2
--xxs3_items x1, xxs3_items x2
 WHERE m.inventory_item_id = mi1.inventory_item_id
   AND m.related_item_id = mi2.inventory_item_id
   AND m.organization_id = mi1.organization_id -- exists Added by Sateesh
   AND mi1.organization_id = mi2.organization_id
   AND EXISTS (SELECT l_inventory_item_id
          FROM xxs3_ptm_master_items_ext_stg xxpm
         WHERE xxpm.l_inventory_item_id = m.inventory_item_id
           AND xxpm.legacy_organization_id = m.organization_id
           AND xxpm.extract_rule_name IS NOT NULL
           AND xxpm.process_flag <> 'R'); --Added by Sateesh
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
 EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptm_item_relationship';
 FOR i IN cur_item_relation_extract LOOP
     INSERT INTO xxobjt.xxs3_ptm_item_relationship
     (xx_item_relation_id,
     legacy_organization_code,
     legacy_organization_id,
     s3_organization_code,
     item,
     related_item,
     relationship_type_id,
     relationship_type,
     attr_char1,
     attr_char2,
     attr_char3,
     attr_char4,
     attr_char5,
     attr_char6,
     attr_char7,
     attr_char8,
     attr_char9,
     attr_char10,
     attr_num1,
     attr_num2,
     attr_num3,
     attr_num4,
     attr_num5,
     attr_num6,
     attr_num7,
     attr_num8,
     attr_num9,
     attr_num10,
     attr_date1,
     attr_date2,
     attr_date3,
     attr_date4,
     attr_date5,
     attr_date6,
     attr_date7,
     attr_date8,
     attr_date9,
     attr_date10,
     reciprocal_flag,
     planning_enabled_flag,
     date_extracted_on,
     process_flag
)
 VALUES
     (xxs3_ptm_item_relationship_seq.NEXTVAL,
     i.organization_code,
     i.organization_id,
     'GIM',
     i.item,
     i.related_item,
     i.relationship_type_id,
     i.relationship_type,
     i.attr_char1,
     i.attr_char2,
     i.attr_char3,
     i.attr_char4,
     i.attr_char5,
     i.attr_char6,
     i.attr_char7,
     i.attr_char8,
     i.attr_char9,
     i.attr_char10,
     i.attr_num1,
     i.attr_num2,
     i.attr_num3,
     i.attr_num4,
     i.attr_num5,
     i.attr_num6,
     i.attr_num7,
     i.attr_num8,
     i.attr_num9,
     i.attr_num10,
     i.attr_date1,
     i.attr_date2,
     i.attr_date3,
     i.attr_date4,
     i.attr_date5,
     i.attr_date6,
     i.attr_date7,
     i.attr_date8,
     i.attr_date9,
     i.attr_date10,
     i.reciprocal_flag,
     i.planning_enabled_flag,
     SYSDATE,
     'N');
   END LOOP;
   COMMIT;
    --
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || CHR(10) || SQLERRM;
      /*FND_FILE.PUT_LINE(FND_FILE.LOG,
      'Unexpected error during data extraction : ' ||
      CHR(10) || L_STATUS_MESSAGE);*/
    /*FND_FILE.PUT_LINE(FND_FILE.LOG,
    '--------------------------------------');*/
    /*fnd_file.put_line(fnd_file.output, 'Concurrent Request processed successfully');
    fnd_file.put_line(fnd_file.output, '--------------------------------------'); */
    END item_relationship_extract;
  END xxs3_ptm_item_relationship_pkg;
/
