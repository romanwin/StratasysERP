CREATE OR REPLACE PACKAGE BODY xxibe_eu_freight_calc_pkg AS
  g_quote_header_id NUMBER(30);
  g_zone            VARCHAR2(500);

  g_country         VARCHAR2(260);
  g_weight          NUMBER(30, 2);
  g_shipping_method VARCHAR2(200);
  g_creation_date   DATE DEFAULT SYSDATE;
  g_error_message   VARCHAR2(2000);
  g_error_code      VARCHAR2(30);
  g_package_name    VARCHAR2(32) := 'XXIBE_EU_FREIGHT_CALC_PKG';
  g_procedure_name  VARCHAR2(32);
  FUNCTION xxibe_eu_freight_fun(ip_quote_header_id IN NUMBER) RETURN NUMBER
  /*=======================================================================
    FILE NAME:   XXIBE_EU_FREIGHT_CALC_PKG
    VERSION:     1.3
    OBJECT NAME: XXIBE_EU_FREIGHT_CALC_PKG
    OBJECT TYPE: Public Package
    DESCRIPTION: 1. this package contains the function to calculate the freight charges for istore
                 2. This also includes the Tax calculated on the freight terms.
    PARAMETERS:  None
    RETURNS:     None
    DATE:        12-AUG-2012
    AUTHOR :     APPSASSOCIATES
    =====================================================================*/
   IS
    l_freight     NUMBER; --:= 00;---null;
    l_weight      NUMBER := NULL;
    l_zone        VARCHAR2(100);
    l_country     VARCHAR2(260) := NULL;
    l_shipmethod  VARCHAR2(260) := NULL;
    l_dg_count    VARCHAR2(2);
    l_dg_rate     NUMBER;
    l_org_id      NUMBER;
    l_tax         NUMBER(5);
    l_frt_flag    VARCHAR2(2);
    l_profile_tax NUMBER(5, 2);
  
    g_quote_header_id VARCHAR2(100) := ip_quote_header_id;
    g_procedure_name  VARCHAR2(100) := 'XXIBE_EU_FREIGHT_FUN';
    g_creation_date   DATE DEFAULT SYSDATE;
    g_error_message   VARCHAR2(2000);
    g_error_code      VARCHAR2(30);
    g_package_name    VARCHAR2(32) := 'XXIBE_EU_FREIGHT_CALC_PKG';
  BEGIN
    SELECT fl.meaning,
           SUM(aqla.quantity *
               inv_rcv_cache.convert_qty(msib.inventory_item_id,
                                         msib.unit_weight,
                                         msib.weight_uom_code,
                                         'KG')) weight,
           qr.character2 shipping_method,
           (SELECT COUNT(*)
              FROM aso_quote_lines_all aqll, mtl_system_items_b msib
             WHERE quote_header_id = ip_quote_header_id
               AND msib.inventory_item_id = aqll.inventory_item_id
               AND msib.organization_id = aqll.organization_id
               AND msib.hazardous_material_flag = 'Y') "DG_Count",
           msib.organization_id,
           aqha.total_tax,
           qr.character8 flag
      INTO l_country,
           l_weight,
           l_shipmethod,
           l_dg_count,
           
           l_org_id,
           l_tax,
           l_frt_flag
      FROM aso_quote_headers_all aqha,
           aso_quote_lines_all   aqla,
           aso_shipments         as1,
           hz_party_sites        hps,
           hz_locations          hl,
           mtl_system_items_b    msib,
           fnd_lookups           fl,
           mtl_parameters        mp,
           qa_results            qr,
           qa_plans              qp
     WHERE 1 = 1
       AND aqha.quote_header_id = aqla.quote_header_id
       AND as1.quote_header_id = aqha.quote_header_id
       AND as1.quote_line_id IS NULL
       AND hps.party_site_id = as1.ship_to_party_site_id
       AND hps.location_id = hl.location_id
       AND aqla.inventory_item_id = msib.inventory_item_id
       AND fl.lookup_type = 'JEES_EURO_COUNTRY_CODES'
       AND fl.lookup_code = hl.country
       AND aqha.quote_header_id = ip_quote_header_id
       AND msib.organization_id = mp.organization_id
       AND mp.master_organization_id = 91
       AND aqla.organization_id = mp.organization_id
       AND qr.character1 = as1.ship_method_code
       AND qr.plan_id = qp.plan_id
       AND qp.name = 'FREIGHT TERMS AND SHIP METHODS'
       AND qr.character7 = '96'
          
       AND qr.character8 = 'Y'
     GROUP BY fl.meaning,
              qr.character2,
              msib.organization_id,
              aqha.total_tax,
              qr.character8;
    dbms_output.put_line('1st query' || l_tax || l_frt_flag);
  
    SELECT MAX(freight), ezcm.zone
      INTO l_freight, l_zone
      FROM xxibe_eu_freight_charges efc, xxibe_eu_zone_country_map ezcm
     WHERE ezcm.country = l_country
       AND efc.shipping_method = l_shipmethod
       AND weight <= l_weight
       AND efc.zone = ezcm.zone
     GROUP BY ezcm.zone;
    dbms_output.put_line('2 query');
  
    SELECT fl.description
      INTO l_dg_rate
      FROM org_organization_definitions ood,
           mtl_parameters               mp,
           fnd_lookups                  fl
     WHERE 1 = 1
       AND ood.organization_id = mp.organization_id
       AND mp.organization_id = l_org_id
       AND lookup_type LIKE 'XXIBE_CHARGES_DG_VALUE'
       AND ood.operating_unit = fl.meaning;
  
    dbms_output.put_line('DG rate' || l_dg_rate);
  
    SELECT fnd_profile.value('XXIBE_EU_STORE_VAT') profile_value
      INTO l_profile_tax
      FROM dual;
  
    dbms_output.put_line('profile_value' || l_profile_tax);
    --
    IF (l_dg_count > 0) THEN
      l_freight := l_freight + l_dg_rate;
      --  return L_FREIGHT;
      --else
      --return L_FREIGHT;
    END IF;
  
    IF (l_tax > 0) THEN
      l_freight := l_freight + (l_freight * (l_profile_tax / 100));
      dbms_output.put_line('tax included freight' || l_freight);
      --else
      --return 0;
      --return l_freight;
    END IF;
  
    RETURN l_freight;
  
  EXCEPTION
    WHEN no_data_found THEN
      g_error_message := 'Quote Header I d Does Not Exists' || SQLERRM;
      g_error_code    := SQLCODE;
      l_freight       := 0;
      dbms_output.put_line('no data found');
    
      INSERT INTO xxibe_eu_err_freight
      VALUES
        (g_error_code,
         g_quote_header_id,
         l_zone,
         l_country,
         l_weight,
         l_shipmethod,
         g_creation_date,
         
         g_error_message,
         g_package_name,
         g_procedure_name);
      RETURN l_freight;
    WHEN OTHERS THEN
      g_error_message := 'UnExpected Error : ' || SQLERRM;
      g_error_code    := SQLCODE;
      l_freight       := 0;
      dbms_output.put_line('when others' || SQLERRM);
    
      INSERT INTO xxibe_eu_err_freight
      VALUES
        (g_error_code,
         g_quote_header_id,
         l_zone,
         l_country,
         l_weight,
         l_shipmethod,
         g_creation_date,
         g_error_message,
         g_package_name,
         g_procedure_name);
      RETURN l_freight;
    
  END xxibe_eu_freight_fun;
END xxibe_eu_freight_calc_pkg;
/
