CREATE OR REPLACE TRIGGER AVATAX_UPD_AI_TRX_NUM AFTER UPDATE OF TRX_NUMBER ON RA_CUSTOMER_TRX_ALL FOR EACH ROW

DECLARE
l_TaxAmt                RA_CUSTOMER_TRX_LINES_ALL.TAX_RECOVERABLE%TYPE;
l_TotalAmt              RA_CUSTOMER_TRX_LINES_ALL.LINE_RECOVERABLE%TYPE;
l_col                   FND_DESCR_FLEX_COLUMN_USAGES.application_column_name%TYPE;
v_query_str             VARCHAR2(1000);
l_avtx_company_code     VARCHAR2(100);
AvaTaxDocParams         AVATAX_GEN_PKG.AvaTaxDocParams;
xml_AvaTaxResponse      xmltype;
l_commit                number;
l_commit_flag           varchar2(1);
l_commit_status         varchar2(50);
l_tax_regime_code       zx_regimes_usages.tax_regime_code%type;
l_shipto_country        fnd_territories_vl.territory_code%type;

 --V1.0 22 Aug2017 - CHG0040036 Custom Code added for SSYS  - start
  l_env          varchar2(20)  := apps.xxobjt_general_utils_pkg.am_i_in_production; -- return Y if Production
  --V1.0 22 Aug2017 - CHG0040036 End of SSYS custom code

cursor get_country_code is
    SELECT upper(trim(REPLACE(terr.territory_code, ','))) Country
    FROM HZ_CUST_SITE_USES_ALL cust_site_uses ,
      hz_cust_acct_sites_all addr ,
      hz_party_sites party_site ,
      fnd_territories_vl terr ,
      hz_locations loc ,
      fnd_languages_vl lang
    WHERE addr.party_site_id             = party_site.party_site_id
    AND loc.location_id                  = party_site.location_id
    AND loc.country                      = terr.territory_code(+)
    AND loc.LANGUAGE                     = lang.language_code(+)
    AND cust_site_uses.CUST_ACCT_SITE_ID = addr.cust_acct_site_id
    AND cust_site_uses.SITE_USE_ID       = NVL(:old.ship_to_site_use_id,:old.bill_to_site_use_id) ;

cursor get_regime_code (p_country_code varchar2) is
    select DISTINCT ru.tax_regime_code
    from  zx_srvc_subscriptions ss,
          zx_regimes_usages ru,
          zx_regimes_b reg,
          zx_subscription_options so,
          ZX_PARTY_TAX_PROFILE zptp
    where ss.srvc_provider_id           = 3  /* AVALARA */
    and   ss.prod_family_grp_code       = 'O2C'
    and   nvl(ss.enabled_flag, 'N')     = 'Y'
    and   ss.effective_from             <= sysdate
    and   nvl(ss.effective_to,sysdate)  >= sysdate
    and   ss.regime_usage_id            = ru.regime_usage_id
    and   so.regime_usage_id            = ru.regime_usage_id
    and   nvl(so.enabled_flag, 'N')     = 'Y'
    and   nvl(so.effective_to,sysdate)  >= sysdate
    and   so.effective_from             <= sysdate
    and   ru.tax_regime_code            = reg.tax_regime_code
    and   nvl(reg.effective_to,sysdate) >= sysdate
    and   ru.FIRST_PTY_ORG_ID           = zptp.PARTY_TAX_PROFILE_ID
    and   reg.country_code              = p_country_code;

CURSOR get_det_trx_num
IS
  SELECT distinct det.trx_number
  FROM avatax_ebs_tax_call_det det,
    avatax_doc_status ads
  WHERE det.application_code = 'AR'
  AND ads.ebs_appl_code      = 'AR'
  AND det.avatax_doc_id      = ads.avt_doc_id
  AND det.commit_flag        = 'N'
  AND det.trx_id             = :old.customer_trx_id;

l_det_trx_num   avatax_ebs_tax_call_det.trx_number%type;
l_doc_type VARCHAR2(20);
BEGIN
  IF (UPDATING) and (:old.trx_number <> :new.trx_number) then
    avatax_connector_utility_pkg.GlobalPrintOption := 'Y';
    avatax_connector_utility_pkg.PrintOut('AVATAX O2C: AVATAX_UPD_AI_TRX_NUM TRIGGER, Version: 1.2.0 =>.02');
    avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Org ID            = '||:OLD.ORG_ID);

      BEGIN
        SELECT DECODE(upper(type),'INV','SalesInvoice','CM','ReturnInvoice','SalesInvoice')
        INTO l_doc_type
        FROM RA_CUST_TRX_TYPES_ALL
        WHERE cust_trx_type_id = :OLD.cust_trx_type_id
        AND ORG_ID             = :OLD.ORG_ID;
      EXCEPTION
      WHEN OTHERS THEN
        avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Error while fetching the Trnasction type..');
        RETURN;
      END;
      avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Document Type      = '||l_doc_type);


      l_shipto_country := null;
      for rec in get_country_code loop
        l_shipto_country := rec.Country;
      end loop;
      l_tax_regime_code := null;
      for rec in get_regime_code(l_shipto_country)
      loop
        l_tax_regime_code := rec.tax_regime_code;
      end loop;
      avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Tax Regime Code   = '||l_tax_regime_code);
      /*Cursor below is to fetch the trx number from the avatax_ebs_tax_cal_det table */
      l_det_trx_num := null;
      for det_rec in get_det_trx_num
      loop
       l_det_trx_num := det_rec.trx_number;
       avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Trx Number in call det   = '||l_det_trx_num);
      end loop;

      IF l_tax_regime_code is not null
      THEN
          BEGIN
            SELECT NVL(SUM(line_recoverable), 0), NVL(SUM(tax_recoverable), 0)
            INTO l_TotalAmt, l_TaxAmt
            FROM ra_customer_trx_Lines_all
            WHERE customer_trx_id = :old.customer_trx_id
            AND line_type = 'LINE';
          EXCEPTION
          WHEN OTHERS THEN
          l_TotalAmt := 0;
          l_TaxAmt := 0;
          END;

          l_avtx_company_code := null;
          BEGIN
            SELECT a.application_column_name
            INTO l_col
            FROM FND_DESCR_FLEX_COLUMN_USAGES a
              , fnd_descriptive_flexs b
            WHERE a.application_id  = b.application_id
            AND a.DESCRIPTIVE_FLEXFIELD_NAME = b.DESCRIPTIVE_FLEXFIELD_NAME
            AND a.DESCRIPTIVE_FLEXFIELD_NAME = 'PER_ORGANIZATION_UNITS'
            AND a.DESCRIPTIVE_FLEX_CONTEXT_CODE = 'Global Data Elements'
            AND rtrim(ltrim(upper(a.end_user_column_name))) = 'AVATAX_COMPANY_CODE'
            AND a.enabled_flag  = 'Y'
            and rownum=1;
          EXCEPTION
          WHEN OTHERS THEN
            l_col := NULL;
          END;
          v_query_str := 'SELECT '||l_col||' FROM hr_organization_units_v WHERE organization_id  = :1';
          EXECUTE IMMEDIATE v_query_str
          INTO l_avtx_company_code
          USING :OLD.ORG_ID;
            
          --V1.0 22 Aug2017 - CHG0040036 Custom Code added for SSYS  - start
          If nvl(l_env, 'N') = 'N' then
             l_avtx_company_code := 'TEST-SSYS';
             avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Not Production - Override Tax Company');
             avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Test Company Code: '||l_avtx_company_code);
          End If;
          --V1.0 22 Aug2017 - CHG0040036 End of SSYS custom code
 
 
          avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Old Transaction Number  = '||:old.trx_number);
          avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: New Transaction Number  = '||:new.trx_number);
          avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Total Amount            = '||l_TotalAmt);
          avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Total Tax Amount        = '||l_TaxAmt);
          avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Company Code            = '||l_avtx_company_code);
          l_commit := 1; -- true

          if (l_avtx_company_code is not null) then

            if :old.trx_number = '~$~$$$' then
                /* Do nothing when trx number changes from $$$ to first invoice number sequence.
                   The else part will take care of committing gapless invoice number to Avatax and overwrite the TRX_ID-<customer_trx_id>"
                   when the initially generated invoice number is replaced by gapless invoice number by AR at completion time */
                  avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Transaction Number ['||:old.trx_number||'] is updated to ['||:new.trx_number||'] in EBS');
                  avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Stratasys Custom Logic: Using Customer Trx ID ['||:old.customer_trx_id||'] as Avatax Doc Code');
                  avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Calling AvaTax PostTax API to commit the data');

                  AvaTaxDocParams.PostTaxResponse := avatax_generic_connector.POST_TAX_CALC(
                                        'postTax',
                                        l_doc_type,
                                        l_avtx_company_code,
                                        :old.trx_date,
                                        :OLD.CUSTOMER_TRX_ID, --l_det_trx_num, /* Stratasys: This is really customer trx id and not trx_number */
                                        :OLD.CUSTOMER_TRX_ID, --l_det_trx_num,
                                        NULL,
                                        l_commit,
                                        :old.trx_date,
                                        l_TotalAmt,
                                        l_taxamt,
                                        NULL);

              avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: AvaTaxDocParams.PostTaxResponse => '||AvaTaxDocParams.PostTaxResponse);
              if AvaTaxDocParams.PostTaxResponse is not null then

                xml_AvaTaxResponse := XMLTYPE(Replace(AvaTaxDocParams.PostTaxResponse,'&',' '));
                xmltype.toobject(xml_AvaTaxResponse, AvaTaxDocParams.PostTaxResult);
                if upper(AvaTaxDocParams.PostTaxResult.Resultcode) IN ('ERROR','EXCEPTION') then

                    if (l_taxamt = 0) and
                        (instr(upper(AvaTaxDocParams.PostTaxResult.ERRORMSG), 'THE TAX DOCUMENT COULD NOT BE FOUND') > 0) then
                          avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Document does not exist in AvaTax application');
                    else
                        begin
                          update avatax_ebs_tax_call_det
                          set
                          --trx_number = :old.trx_number,
                          avatax_doc_id = AvaTaxDocParams.PostTaxResult.AVTDOCID,
                          avatax_result_code = AvaTaxDocParams.PostTaxResult.Resultcode,
                          avatax_error_msg = AvaTaxDocParams.PostTaxResult.ERRORMSG,
                          last_updated_by = fnd_global.user_id
                          where trx_id = :old.customer_trx_id
                          and avatax_call_id in (select max(avatax_call_id)
                                from avatax_ebs_tax_call_det
                                where trx_id = :old.customer_trx_id
                                and application_code <> 'ONT');
                        exception
                          when others then
                            avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Document does not exist in AvaTax application');
                        end;
                        RAISE_APPLICATION_ERROR(-20004, 'AVATAX: Error occurred while updating the Document Code in AvaTax application');
                    end if;

                else /* if upper(AvaTaxDocParams.PostTaxResult.Resultcode) IN ('ERROR','EXCEPTION') */
                      l_commit_status := 'Committed';
                      l_commit_flag := 'Y';
                    avatax_connector_utility_pkg.UpdateAvaTaxDocStatusTbl(
                              :old.customer_trx_id,
                              'AR',
                              AvaTaxDocParams.PostTaxResult.AVTDOCID,
                              l_det_trx_num,
                              l_commit_status,
                              l_doc_type,
                              null);
                    begin
                      update avatax_ebs_tax_call_det
                      set
                      --trx_number = l_det_trx_num, -- Stratasys Custom Logic: trx_number is already equal to customer_trx_id and does not change, so do not try to update this column
                      commit_flag = l_commit_flag,
                      avatax_doc_id = AvaTaxDocParams.PostTaxResult.AVTDOCID,
                      avatax_result_code = AvaTaxDocParams.PostTaxResult.Resultcode,
                      line_amount = l_TotalAmt,
                      last_updated_by = fnd_global.user_id
                      where trx_id = :old.customer_trx_id
                      and avatax_call_id in (select max(avatax_call_id)
                            from avatax_ebs_tax_call_det
                            where trx_id = :old.customer_trx_id
                            and application_code <> 'ONT');
                      avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Rows updated in avatax_ebs_tax_call_det = '||sql%rowcount);

                    exception
                      when others then
                        avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: Failed to update rows in avatax_ebs_tax_call_det');
                    end;
                end if; /* if upper(AvaTaxDocParams.PostTaxResult.Resultcode) = 'ERROR' */

              end if; /* if AvaTaxDocParams.PostTaxResponse is not null */

            end if;  /* else of : if :old.trx_number = '~$~$$$'    */

          end if; /* if (l_avtx_company_code is not null) then  */

        END IF; /* IF l_tax_regime_code is not null */

      avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_AI_TRX_NUM: AVATAX_UPD_AI_TRX_NUM TRIGGER <=');
    END IF;
EXCEPTION
     WHEN OTHERS THEN
       RAISE;
END avatax_upd_ai_trx_num;
/
