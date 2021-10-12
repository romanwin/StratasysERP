CREATE OR REPLACE PACKAGE BODY xxcs_sr_charges_validation_pkg IS
--------------------------------------------------------------------
--  name:            XXCS_SR_CHARGES_VALIDATION_PKG
--  create by:       Vitaly K.
--  Revision:        1.0
--  creation date:   15/03/2010
--------------------------------------------------------------------
--  purpose :       Check SR Charges and return Message
--
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  15/03/2010  Vitaly K.         initial build
--  1.1  20/11/2011  Roman V.          Procedure check_sr_charges_validation -
--                                     Change logic of cursor get_unsubmitted_charges
--  1.2  23/05/2012  Adi S.            Procedure check_sr_charges_validation
--                                     Change Logic of get_unsubmitted_charges -
--                                     it's now validate sr with Contract number
--                                     All the logic wrap with profile XXCS_SR_VALID_TM_ONLY
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            check_sr_charges_validation
  --  create by:       Vitaly K.
  --  Revision:        1.0
  --  creation date:   15/03/2010
  --------------------------------------------------------------------
  --  purpose :       Check SR Charges and return Message
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/03/2010  Vitaly K.         initial build
  --  1.1  20/11/2011  Roman V.          Procedure check_sr_charges_validation -
  --                                     Change logic of cursor get_unsubmitted_charges
  --  1.2  13/05/2012  Adi S.            Procedure check_sr_charges_validation
  --                                     Change Logic of get_unsubmitted_charges -
  --                                     it's now validate sr with Contract number
  --                                     All the logic wrap with profile XXCS_SR_VALID_TM_ONLY
  --------------------------------------------------------------------
  PROCEDURE check_sr_charges_validation(p_incident_id       IN NUMBER,
                                        p_new_inc_status_id IN NUMBER,
                                        p_out_status        IN OUT VARCHAR2) IS


    v_get_tm_sr_only         VARCHAR2(3) := nvl(FND_PROFILE.VALUE('XXCS_SR_VALID_TM_ONLY'),'N');

    cursor get_unsubmitted_charges is
      select ccdv.line_number,
             nvl(ccdv.no_charge_flag, 'n')       no_charge_flag,
             nvl(ccdv.interface_to_oe_flag, 'n') interface_to_oe_flag,
             ccdv.attribute1,
             ccdv.attribute2
      from   cs_incidents_all_b                 sr,
             csi_item_instances                 cii,
             cs_incident_types_b                srt,
             cs_charge_details_v                ccdv,
             mtl_system_items_b                 msi,
             cs_transaction_types_b             ctt
      where  sr.incident_id                     = ccdv.incident_id
      and    sr.incident_type_id                = srt.incident_type_id
      and    ctt.transaction_type_id            = ccdv.transaction_type_id
      and    nvl(srt.attribute6, 'Y')           = 'Y'
      AND    nvl(ctt.no_charge_flag, 'N')       <> 'Y'
      AND    nvl(ctt.interface_to_oe_flag, 'N') <> 'N'
      --  1.2 Adi S. 13/05/2012
      and    (sr.contract_number                 IS NULL AND v_get_tm_sr_only = 'Y'
      OR      ccdv.after_warranty_cost != 0 AND msi.material_billable_flag = 'XXOBJ_HEADS' AND v_get_tm_sr_only = 'N')
      -- end 1.2
      and    ccdv.order_num                     is null
      and    ccdv.incident_id                   = p_incident_id  -- parameter
      and    ccdv.inventory_item_id             = msi.inventory_item_id
      and    msi.organization_id                = 91
      and    sr.customer_product_id             = cii.instance_id
      -- 1.1 Roman V. 20/11/2011 change some logic
      and    exists                             (select 1
                                                 from   fnd_flex_values     v,
                                                        fnd_flex_value_sets s,
                                                        fnd_flex_values_tl  t
                                                 where  flex_value_set_name = 'XXCS_CS_REGIONS'
                                                 and    s.flex_value_set_id = v.flex_value_set_id
                                                 and    t.flex_value_id     = v.flex_value_id
                                                 and    v.attribute6        = 'Y'
                                                 and    t.language          = 'US'
                                                 and    v.flex_value        = nvl(cii.attribute8, 'XYZ'))
      and    (msi.segment1                      NOT IN ('TRAVEL-KM', 'TRAVEL-MILES') -- items not validated
              OR cii.attribute8                 IS NULL)        -- no sr_region
      and     not (msi.segment1                 = 'WKHRS-PHONE' -- 'WKHRS-PHONE' for Indirect not validated
              and  EXISTS                       (select 1
                                                 from   fnd_flex_values     v,
                                                        fnd_flex_value_sets s,
                                                        fnd_flex_values_tl  t
                                                 where  flex_value_set_name = 'XXCS_CS_REGIONS'
                                                 and    s.flex_value_set_id = v.flex_value_set_id
                                                 and    t.flex_value_id     = v.flex_value_id
                                                 and    t.language          = 'US'
                                                 and    v.attribute10       = 'Indirect'
                                                 and    v.flex_value        = nvl(cii.attribute8, 'XYZ')))
      -- end 1.1
      order by ccdv.line_number;

    cursor get_new_inc_status_name is
      select stl.name     status_name
      from   cs_incident_statuses_b       s,
             cs_incident_statuses_tl      stl,
             cs_incident_statuses_b_dfv   s_dfv
      where  s.rowid                      = s_dfv.row_id
      and    nvl(s_dfv.xxcs_sr_close_validation,'N') = 'Y'
      and    stl.language                 = 'US'
      and    s.incident_status_id         = stl.incident_status_id
      and    s.incident_status_id         = p_new_inc_status_id;  ---parameter

    CURSOR get_old_inc_status_id IS
      SELECT sr.incident_status_id
      FROM   cs_incidents_all_b           sr
      WHERE  sr.incident_id               = p_incident_id;  ---parameter

    v_return_message          VARCHAR2(3000);
    v_char_dummy              VARCHAR2(3000);
    v_old_inc_status_id       NUMBER;
    stop_validation           EXCEPTION;
    go_to_next_charges_line   EXCEPTION;


  BEGIN

    ----Check parameters---------
    IF p_incident_id IS NULL OR p_new_inc_status_id IS NULL THEN
      RAISE stop_validation; ---missing parameter
    END IF;

    ----Check New SR Status------
    OPEN get_new_inc_status_name;
    FETCH get_new_inc_status_name INTO v_char_dummy;
    IF get_new_inc_status_name%NOTFOUND THEN
      CLOSE get_new_inc_status_name;
      RAISE stop_validation;  ---This New Incident Status is not COMPLETE or CANCELLED
    END IF;
    CLOSE get_new_inc_status_name;

    ----Get Current(Old) SR Status Id---
    OPEN get_old_inc_status_id;
    FETCH get_old_inc_status_id INTO v_old_inc_status_id;
    IF get_old_inc_status_id%NOTFOUND THEN
      CLOSE get_old_inc_status_id;
      RAISE stop_validation;
    END IF;
    CLOSE get_old_inc_status_id;

    ----Is this status update
    IF p_new_inc_status_id=v_old_inc_status_id THEN
      RAISE stop_validation; ---This is NOT status update
    END IF;

    FOR unsubmitted_charge_rec IN get_unsubmitted_charges LOOP
      -------------LOOP----------------
      BEGIN
        IF  unsubmitted_charge_rec.no_charge_flag='Y' THEN
          IF unsubmitted_charge_rec.attribute1 IS NULL OR unsubmitted_charge_rec.attribute2 IS NULL THEN
             v_return_message:=v_return_message||chr(10)||
                               'Charge Line# '||unsubmitted_charge_rec.line_number||
                               ' Approval details are missing'; ---Message 1
             RAISE go_to_next_charges_line; ---Exit without error
          ELSE
             ---DFF is ok
             RAISE go_to_next_charges_line; ---Exit without error
          END IF;
        END IF;

        IF  unsubmitted_charge_rec.interface_to_oe_flag='N' THEN
          IF unsubmitted_charge_rec.attribute1 IS NULL OR unsubmitted_charge_rec.attribute2 IS NULL THEN
             v_return_message:=v_return_message||chr(10)||
                               'Charge Line# '||unsubmitted_charge_rec.line_number||
                               ' Approval details are missing'; ---Message 1
             RAISE go_to_next_charges_line; ---Exit without error
          ELSE
             ---DFF is ok
             RAISE go_to_next_charges_line; ---Exit without error
          END IF;
        ELSE  ---unsubmitted_charge_rec.interface_to_oe_flag='Y'
          IF unsubmitted_charge_rec.attribute1 IS NOT NULL AND unsubmitted_charge_rec.attribute2 IS NOT NULL THEN
             RAISE go_to_next_charges_line; ---Exit without error
          END IF;
        END IF;
         v_return_message:=v_return_message||chr(10)||
                                 'Charge Line# '||unsubmitted_charge_rec.line_number||
                                 ' Not submitted to sales order';  ---Message 2
      EXCEPTION
        WHEN go_to_next_charges_line THEN
           NULL;
      END;
      -------the end of LOOP-----------
    END LOOP;

    v_return_message:= ltrim(v_return_message,chr(10));

    IF v_return_message IS NOT NULL THEN
      ----Charges validation ERRORS
      FND_MESSAGE.set_name ('XXOBJT', 'XXCS_SR_CHARGES_VALIDATION');
      FND_MESSAGE.set_token('ERROR_MESSAGE', v_return_message);
      FND_MSG_PUB.add;
      p_out_status:=fnd_api.g_ret_sts_error;
    ELSE
      ----Charges validation SUCCESS
      p_out_status:=fnd_api.g_ret_sts_success;
    END IF;

    EXCEPTION
      WHEN stop_validation THEN
        p_out_status:=fnd_api.g_ret_sts_success;
      WHEN OTHERS THEN
        p_out_status:=fnd_api.g_ret_sts_success;
  END check_sr_charges_validation;

  --------------------------------------------------------------------
  --  name:            charges_mass_update
  --  create by:       Vitaly K.
  --  Revision:        1.0
  --  creation date:   15/03/2010
  --------------------------------------------------------------------
  --  purpose :       Check SR Charges and return Message
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/03/2010  Vitaly K.         initial build
  --------------------------------------------------------------------
  PROCEDURE charges_mass_update(errbuf              OUT VARCHAR2,
                                retcode             OUT VARCHAR2,
                                p_incident_id       IN NUMBER,
                                p_no_charge_reason  IN  VARCHAR2,
                                p_approved_by       IN  VARCHAR2,
                                p_comment           IN  VARCHAR2) IS
    CURSOR get_sr_charges IS
    SELECT charges.ESTIMATE_DETAIL_ID, charges.line_number, sr.incident_number
    FROM   CS_ESTIMATE_DETAILS    charges,
           CS_INCIDENTS_ALL_B     sr
    WHERE  charges.incident_id=p_incident_id  ---parameter
    AND    charges.incident_id=sr.incident_id
    AND   (nvl(charges.no_charge_flag,'N')='Y' OR nvl(charges.interface_to_oe_flag,'N')='N')
    AND    charges.ATTRIBUTE1 IS NULL  ---no_charge_reason is empty
    ORDER BY charges.line_number;

    v_step                        VARCHAR2(3000);
    v_error_messge                VARCHAR2(3000);
    v_numeric_dummy               NUMBER;
    v_line_number                 NUMBER;
    v_incident_number             NUMBER;
    v_updated_charge_lines_list   VARCHAR2(3000);
    v_num_of_rows_for_update      NUMBER:=0;
    v_updated_rows_counter        NUMBER;
    stop_process                  EXCEPTION;
    resource_busy                 EXCEPTION;
    PRAGMA EXCEPTION_INIT   (resource_busy, -54);

  BEGIN

    v_step:='Step 0';
    ----Check Parameter p_incident_id
    IF p_incident_id IS NULL THEN
       v_error_messge:='PARAMETER p_incident_id IS MISSING';
       RAISE stop_process;
    ELSE
       -------
       BEGIN
         SELECT sr.incident_number
         INTO   v_incident_number
         FROM   CS_INCIDENTS_ALL_B  sr
         WHERE  sr.incident_id=p_incident_id;  ---parameter
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
            v_error_messge:='PARAMETER p_incident_id='||p_incident_id|| ' DOES NOT EXISTS IN CS_INCIDENTS_ALL_B TABLE';
            RAISE stop_process;
       END;
       -------
    END IF;

    v_step:='Step 10';
    ----Check Parameter p_no_charge_reason
    IF p_no_charge_reason IS NULL THEN
      v_error_messge:='PARAMETER p_no_charge_reason IS MISSING';
      RAISE stop_process;
    ELSE
      -------
      BEGIN
        SELECT 1
        INTO   v_numeric_dummy
        FROM   FND_FLEX_VALUES      v,
               FND_FLEX_VALUE_SETS  s,
               FND_FLEX_VALUES_TL   t
        WHERE  FLEX_VALUE_SET_NAME='XXCS_NO_CHARGE_REASON'
        AND    s.FLEX_VALUE_SET_ID = v.FLEX_VALUE_SET_ID
        AND    t.FLEX_VALUE_ID = v.FLEX_VALUE_ID
        AND    t.language='US'
        AND    v.FLEX_VALUE=p_no_charge_reason;  ---parameter
      EXCEPTION
       WHEN NO_DATA_FOUND THEN
          v_error_messge:='PARAMETER p_no_charge_reason='''||p_no_charge_reason|| ''' DOES NOT EXISTS IN VALUE SET ''XXCS_NO_CHARGE_REASON''';
          RAISE stop_process;
      END;
    END IF;

    v_step:='Step 20';
    ----Check Parameter p_approved_by
    IF p_approved_by IS NULL THEN
       v_error_messge:='PARAMETER p_approved_by IS MISSING';
       RAISE stop_process;
    ELSE
      BEGIN
        SELECT 1
        INTO   v_numeric_dummy
        FROM   PER_ALL_PEOPLE_F       papf,
               JTF_RS_RESOURCES_VL    jrrv,
               JTF_RS_DEFRESOURCES_V  jrdv
        WHERE  papf.party_id = jrrv.person_party_id
        and    jrrv.resource_id = jrdv.RESOURCE_ID
        and    jrdv.ATTRIBUTE2 = 'YES'
        AND    papf.full_name=p_approved_by;  ---parameter
      EXCEPTION
       WHEN NO_DATA_FOUND THEN
          v_error_messge:='PARAMETER p_incident_id='||p_incident_id|| ' DOES NOT EXISTS IN CS_INCIDENTS_ALL_B TABLE';
          RAISE stop_process;
      END;
    END IF;

    v_step:='Step 30';
    ----Comment is required for no_charge_reason='Other'
    IF p_no_charge_reason='Other' AND p_comment IS NULL THEN
      v_error_messge:='PARAMETER p_comment IS REQUIRED IF NO_CHARGE_REASON=''Other''';
      RAISE stop_process;
    END IF;

    fnd_file.put_line(fnd_file.log,'=========PARAMETERS:');
    fnd_file.put_line(fnd_file.log,'====================SR#=                ' ||v_incident_number||'  (p_incident_id='||p_incident_id||')');
    fnd_file.put_line(fnd_file.log,'====================p_no_charge_reason='''||p_no_charge_reason||'''');
    fnd_file.put_line(fnd_file.log,'====================p_approved_by=     '''||p_approved_by||'''');
    fnd_file.put_line(fnd_file.log,'====================p_comment=         '''||p_comment||'''');
    fnd_file.put_line(fnd_file.log,''); ---empty row
    fnd_file.put_line(fnd_file.log,''); ---empty row

    v_step:='Step 40';
    ------Are these charges rows busy
    v_line_number    :=NULL;
    v_incident_number:=NULL;
    v_num_of_rows_for_update:=0;
    v_updated_charge_lines_list:='';
    FOR charge_rec IN get_sr_charges LOOP
      ------------Charges Lines LOOP-------------------
      v_line_number           :=charge_rec.line_number;
      v_incident_number       :=charge_rec.incident_number;
      v_num_of_rows_for_update:=v_num_of_rows_for_update+1;
      v_updated_charge_lines_list:=v_updated_charge_lines_list||','||charge_rec.line_number;
      ----Are these charges rows busy
      SELECT 1
      INTO   v_numeric_dummy
      FROM   CS_ESTIMATE_DETAILS    c
      WHERE  c.estimate_detail_id=charge_rec.estimate_detail_id
      FOR UPDATE NOWAIT;
      ---------the end of Charges Lines LOOP-----------
    END LOOP;

    v_step:='Step 50';
    IF v_num_of_rows_for_update=0 THEN
      v_error_messge:='NO CHARGES FOR UPDATE';
      RAISE stop_process;
    END IF;

    v_step:='Step 60';
    ------UPDATE NO_CHARGE_REASON-----------
    UPDATE  CS_ESTIMATE_DETAILS    charges
    SET     charges.ATTRIBUTE1=p_no_charge_reason,
            charges.ATTRIBUTE2=p_approved_by,
            charges.ATTRIBUTE3=p_comment
    WHERE   charges.incident_id=p_incident_id  ---parameter
    AND    (nvl(charges.no_charge_flag,'N')='Y' OR nvl(charges.interface_to_oe_flag,'N')='N')
    AND     charges.ATTRIBUTE1 IS NULL;  ---no_charge_reason is empty

    v_updated_rows_counter:=SQL%ROWCOUNT;
    fnd_file.put_line(fnd_file.log,'================SR#'||v_incident_number||': CHARGE LINES#'||ltrim(v_updated_charge_lines_list,',')||'  ('||v_updated_rows_counter||' rows) WERE SUCCESSFULY UPDATED===============');
    COMMIT;

  EXCEPTION
    WHEN stop_process THEN
      fnd_file.put_line(fnd_file.log,'======ERROR========='||v_error_messge||'===============');
      errbuf  := v_error_messge;
      retcode := '2';
    WHEN resource_busy THEN
      ROLLBACK;
      v_error_messge:='CHARGE LINE# '||v_line_number||
                      ' FOR SR# '||v_incident_number||' IS LOCKED. PLEASE SAVE YOUR SR-FORM AND TRY AGAIN';
      fnd_file.put_line(fnd_file.log,'======ERROR========='||v_error_messge||'===============');
      errbuf  := v_error_messge;
      retcode := '2';
    WHEN OTHERS THEN
      ROLLBACK;
      v_error_messge:='UNEXPECTED ERROR : '||SQLERRM;
      fnd_file.put_line(fnd_file.log,'=====step='||v_step||'=========='||v_error_messge||'===============');
      errbuf  := v_error_messge;
      retcode := '2';
  END charges_mass_update;
    -------------------------------------

END XXCS_SR_CHARGES_VALIDATION_PKG;
/
