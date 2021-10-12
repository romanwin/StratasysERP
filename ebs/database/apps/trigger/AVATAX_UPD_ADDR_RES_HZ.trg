CREATE OR REPLACE TRIGGER AVATAX_UPD_ADDR_RES_HZ
  before Insert or Update of ADDRESS1, CITY, POSTAL_CODE, /*COUNTY*/
STATE, COUNTRY, VALIDATION_STATUS_CODE
/*New trigger variables can only be changed in before row insert or update triggers*/
on "AR"."HZ_LOCATIONS"
  for each row
--------------------------------------------------------------------
  --  ver   date         name           desc
  --  ----  -----------  ------------   ------------------------------
  --  1.0   XX/XX/XXXX   XXXXXXX        initial build
  --  1.1   17/07/2019   Bellona.B      CHG0046120 - Disable Avalara address validation for country code CA
  --  1.2   03/12/2020   Roman W.       CHG0047450 - Account, Contact interface - ReDo  
  --------------------------------------------------------------------
DECLARE
  P_ADDR_VALIDATE      VARCHAR2(3);
  AvaTaxDocParams      AVATAX_GEN_PKG.AvaTaxDocParams;
  AddressLines         AddressLinesTbl := AddressLinesTbl();
  x_return_status      boolean;
  l_count_organization NUMBER;

BEGIN
  x_return_status                                := true;
  AVATAX_CONNECTOR_UTILITY_PKG.g_debug_prefix    := 'AVATAX_UPD_ADDR_RES_HZ';
  AVATAX_CONNECTOR_UTILITY_PKG.GlobalPrintOption := 'N';
  IF (nvl(fnd_profile.value('AFLOG_ENABLED'), 'N') = 'Y') THEN
    IF (nvl(fnd_global.conc_request_id, -1) <> -1) THEN
      AVATAX_CONNECTOR_UTILITY_PKG.GlobalPrintOption := 'L';
    ELSE
      AVATAX_CONNECTOR_UTILITY_PKG.GlobalPrintOption := 'Y';
    END IF;
  END IF;
  avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_ADDR_RES_HZ VERSION => 1.2.0.01');

  P_ADDR_VALIDATE := NVL(FND_PROFILE.VALUE('AVATAX_EXPLICIT_ADDR_VALIDATION'),
                         'N');
  AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AVATAX_CONNECTOR_UTILITY_PKG.GlobalPrintOption = ' ||
                                        AVATAX_CONNECTOR_UTILITY_PKG.GlobalPrintOption);
  AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: P_ADDR_VALIDATE = ' ||
                                        P_ADDR_VALIDATE);
  AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AVATAX_CONNECTOR_UTILITY_PKG.g_upd_addr_validate_res_flag = ' ||
                                        AVATAX_CONNECTOR_UTILITY_PKG.g_upd_addr_validate_res_flag);

  IF (P_ADDR_VALIDATE = 'Y') and
     (nvl(AVATAX_CONNECTOR_UTILITY_PKG.g_upd_addr_validate_res_flag, 'N') = 'N') and
     (UPPER(:NEW.COUNTRY) = 'US' /*or UPPER(:NEW.COUNTRY) = 'CA'*/
     ) then
  
    -- Added By Roman W. 03/12/2020 CHG0047450 --  
    select count(1)
      into l_count_organization
      from hz_party_sites hps, hz_parties hp
     where 1 = 1
       and hp.status = 'A'
       and hp.party_id = hps.party_id
       and hp.party_type = 'ORGANIZATION'
       and hps.location_id = :NEW.location_id
       and ROWNUM = 1;
  
    if 0 < l_count_organization then
      -- Added By Roman W. 03/12/2020 CHG0047450 --
    
      --Commented as part of CHG0046120  
      AddressLines.extend;
      AddressLines(1) := AddressLinesObj('HZ',
                                         :NEW.LOCATION_ID,
                                         substrb(:NEW.ADDRESS1, 1, 50),
                                         substrb(:NEW.ADDRESS2, 1, 50),
                                         substrb(:NEW.ADDRESS3, 1, 50),
                                         substrb(:NEW.CITY, 1, 50),
                                         substrb(:NEW.STATE, 1, 2),
                                         substrb(:NEW.POSTAL_CODE, 1, 11),
                                         UPPER(:NEW.COUNTRY));
    
      AvaTaxDocParams.XMLSplitSize   := 32000;
      AvaTaxDocParams.AddressRawResp := XMLRespTbl();
      AvaTaxDocParams.AddressRawResp := avatax_generic_connector.ADDRESSES_VALIDATION(AvaTaxDocParams.XMLSplitSize,
                                                                                      'XMLRESPTBL',
                                                                                      AddressLines);
      AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AvaTaxDocParams.AddressRawResp count := [' ||
                                            AvaTaxDocParams.AddressRawResp.count || ']');
      AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: ******** End of AVATAX_GENERIC_CONNECTOR.ADDRESS_VALIDATION *********');
    
      AvaTaxDocParams.AddressLinesInfo := null;
      for i in 1 .. AvaTaxDocParams.AddressRawResp.count loop
        AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AvaTaxDocParams.AddressRawResp(' || i ||
                                              ').PartXML => ' || AvaTaxDocParams.AddressRawResp(i)
                                              .PartXML);
        AvaTaxDocParams.AddressLinesInfo := AvaTaxDocParams.AddressLinesInfo || AvaTaxDocParams.AddressRawResp(i)
                                           .PartXML;
      end loop;
    
      AVATAX_CONNECTOR_UTILITY_PKG.TransAddressValidateResult(AvaTaxDocParams.AddressLinesInfo,
                                                              AvaTaxDocParams.AddrLinesResult,
                                                              x_return_status);
    
      if x_return_status then
        for i in 1 .. AvaTaxDocParams.AddrLinesResult.AddressLinesOUT.count loop
          if (:NEW.LOCATION_ID = AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
             .AddressID) and
             (upper(AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                    .Resultcode) = 'SUCCESS') then
          
            :NEW.VALIDATED_FLAG := 'Y';
            :NEW.ADDRESS1       := AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                                   .LINE1;
            :NEW.ADDRESS2       := AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                                   .LINE2;
            :NEW.ADDRESS3       := AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                                   .LINE3;
            :NEW.CITY           := AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i).CITY;
            :NEW.STATE          := AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                                   .REGION;
            :NEW.COUNTY         := AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                                   .COUNTY;
            :NEW.POSTAL_CODE    := AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                                   .POSTALCODE;
            if nvl(AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                   .TAXREGIONID,
                   0) <> 0 then
              :NEW.SALES_TAX_GEOCODE := AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                                        .TAXREGIONID;
            end if;
            :NEW.VALIDATION_STATUS_CODE := 'AvaTax: Valid address';
            :NEW.DATE_VALIDATED         := SYSDATE;
            avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_ADDR_RES_HZ: :NEW.VALIDATION_STATUS_CODE => ' ||
                                                  :NEW.VALIDATION_STATUS_CODE);
            avatax_connector_utility_pkg.PrintOut('AVATAX_UPD_ADDR_RES_HZ: :NEW.SALES_TAX_GEOCODE => ' ||
                                                  :NEW.SALES_TAX_GEOCODE);
          end if;
        end loop;
      else
        AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AVATAX_CONNECTOR_UTILITY_PKG.TransAddressValidateResult() return status is false');
        for i in 1 .. AvaTaxDocParams.AddrLinesResult.AddressLinesOUT.count loop
          IF (:NEW.LOCATION_ID = AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
             .AddressID) and
             (upper(AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                    .Resultcode) <> 'SUCCESS') then
            AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: AvaTax Address Validation Result Code => ' || AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                                                  .Resultcode);
            AVATAX_CONNECTOR_UTILITY_PKG.PrintOut('AVATAX_UPD_ADDR_RES_HZ: Error Message => ' || AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                                                  .ErrorMsg);
            RAISE_APPLICATION_ERROR(-20002,
                                    'AVATAX: ' || AvaTaxDocParams.AddrLinesResult.AddressLinesOUT(i)
                                    .ErrorMsg);
          END IF;
        end loop;
        RAISE_APPLICATION_ERROR(-20003,
                                'AVATAX: Error occurred during Address Validation');
      end if;
    end if; -- Added By Roman W. 03/12/2020 CHG0047450 --
  END IF;
  FND_LOG.STRING(2,
                 'ZX.PLSQL.AVATAX_UPD_ADDR_RES_HZ.TRIGGER',
                 'HZ LOCATIONS');
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END AVATAX_UPD_ADDR_RES_HZ;
/
