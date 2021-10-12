CREATE OR REPLACE PACKAGE BODY xxs3_ptm_item_cross_ref_pkg AS

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
  PROCEDURE item_cross_ref_extract(x_errbuf  OUT VARCHAR2,
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
    CURSOR cur_cross_ref_extract IS
       SELECT
       mcr.cross_reference_id      cross_reference_id,
       mcr.cross_reference_type    cross_reference_type,
       mcr.inv_item_concat_segs    inv_item_concat_segs,
       mc.description              description,
       --x.segment1 item,
       mcr.org_independent_flag    org_independent_flag,
       mcr.organization_code       organization_code,
       mcr.cross_reference         cross_reference_value,
       mcr.description             cross_reference_description,
       mcr.attribute1              attribute1,
       mcr.attribute2              attribute2,
       mcr.attribute3              attribute3,
       mcr.attribute4              attribute4,
       mcr.attribute5              attribute5,
       mcr.attribute6              attribute6,
       mcr.attribute7              attribute7,
       mcr.attribute8              attribute8,
       mcr.attribute9              attribute9
  FROM apps.mtl_cross_references_v    mcr,
       --XXS3_ITEMS                X,
       apps.mtl_cross_reference_types MC
 WHERE NVL(mcr.end_date_active, SYSDATE + 1) > SYSDATE
   --AND MCR.INVENTORY_ITEM_ID = X.INVENTORY_ITEM_ID
 AND mcr.cross_reference_type = mc.cross_reference_type;
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
 EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptm_item_cross_ref';
 FOR i IN cur_cross_ref_extract LOOP
     INSERT INTO xxobjt.xxs3_ptm_item_cross_ref
     (xx_cross_reference_id,
     cross_reference_id,
     legacy_cross_reference_id,
     cross_reference_type,
     cross_reference_value,
     cross_reference_description,
     item,
     org_independent_flag,
     organization_code,
     attribute1,
     attribute2,
     attribute3,
     attribute4,
     attribute5,
     attribute6,
     attribute7,
     attribute8,
     attribute9,
     date_extracted_on,
     process_flag)
 VALUES
     (xxs3_ptm_item_cross_ref_seq.NEXTVAL,
     NULL,
     i.cross_reference_id,
     i.cross_reference_type,
     i.cross_reference_value,
     i.cross_reference_description,
     i.inv_item_concat_segs,
     i.org_independent_flag,
     'GIM',--i.organization_code,
     i.attribute1,
     i.attribute2,
     i.attribute3,
     i.attribute4,
     i.attribute5,
     i.attribute6,
     i.attribute7,
     i.attribute8,
     i.attribute9,
     SYSDATE,
     'N');
   END LOOP;
   COMMIT;
   /*EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;*/
    --
    --calling report prc
    /* XXS3_OTC_PARTY_PKG.DQ_party_report_data;
    XXS3_OTC_PARTY_PKG.DQ_party_report_data_reject;*/
    --
  EXCEPTION
    WHEN OTHERS THEN
      X_RETCODE        := 2;
      X_ERRBUF         := 'Unexpected error: ' || SQLERRM;
      L_STATUS_MESSAGE := SQLCODE || CHR(10) || SQLERRM;
      /*FND_FILE.PUT_LINE(FND_FILE.LOG,
      'Unexpected error during data extraction : ' ||
      CHR(10) || L_STATUS_MESSAGE);*/
    /*FND_FILE.PUT_LINE(FND_FILE.LOG,
    '--------------------------------------');*/
    /*fnd_file.put_line(fnd_file.output, 'Concurrent Request processed successfully');
    fnd_file.put_line(fnd_file.output, '--------------------------------------'); */
    END item_cross_ref_extract;
  END xxs3_ptm_item_cross_ref_pkg;
 /
 
