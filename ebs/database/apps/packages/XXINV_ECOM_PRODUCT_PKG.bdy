create or replace PACKAGE BODY xxinv_ecom_product_pkg IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXINV_ECOM_PRODUCT_PKG.bdy
  Author's Name:   Sandeep Akula
  Date Written:    06-MARCH-2015
  Purpose:         Send Item Attribute updates to e-Commerce 
  Program Style:   Stored Package BODY
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  06-MARCH-2015        1.0                  Sandeep Akula    Initial Version (CHG0034783)
  ---------------------------------------------------------------------------------------------------*/
  
FUNCTION PRODUCT_EXISTS(p_inventory_item_id IN NUMBER,
                        p_organization_id IN NUMBER)
RETURN BOOLEAN IS
l_count NUMBER;   
BEGIN

l_count := '';
SELECT COUNT(*)
INTO l_count
FROM xxinv_ecom_products
WHERE inventory_item_id = p_inventory_item_id and
      organization_id = p_organization_id;
      
IF l_count > '0' THEN
RETURN(TRUE);
ELSE
RETURN(FALSE);
END IF;

END PRODUCT_EXISTS;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    IS_ECOM_ITEM
  Author's Name:   Sandeep Akula
  Date Written:    26-MAR-2015
  Purpose:         This Function determines if the Item is a e-commerce Item
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  09-MAR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/
FUNCTION IS_ECOM_ITEM(p_inventory_item_id IN NUMBER,
                      p_organization_id IN NUMBER)
RETURN VARCHAR2 IS
l_cnt NUMBER;
BEGIN

SELECT count(*)
INTO l_cnt
FROM mtl_system_items msi
WHERE msi.inventory_item_id = p_inventory_item_id
  AND msi.organization_id = p_organization_id
  AND msi.orderable_on_web_flag = 'Y'   -- Web Enabled Item
  AND msi.customer_order_enabled_flag = 'Y';  -- Web Enabled Item
 
 IF l_cnt > '0' THEN
     RETURN('Y');
 ELSE
     RETURN('N');
 END IF;

EXCEPTION
WHEN OTHERS THEN
RETURN('N');
END IS_ECOM_ITEM;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    get_item_info
  Author's Name:   Sandeep Akula
  Date Written:    27-MAR-2015
  Purpose:         This Function retrives Item Attributes Information 
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  27-MAR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/

FUNCTION get_item_info(p_inventory_item_id IN NUMBER,
                       p_organization_id IN NUMBER,
                       p_source IN VARCHAR2)
RETURN  item_rec_type IS

item_rec item_rec_type;

BEGIN

select msi.inventory_item_id,
       msi.segment1,
       msi.organization_id,
       msi.description,
       msi.primary_unit_of_measure,
       msi.hazardous_material_flag,
       msi.dimension_uom_code,
       msi.unit_length,
       msi.unit_width,
       msi.unit_height,
       msi.weight_uom_code,
       msi.unit_weight,
       msi.created_by,
       msi.last_updated_by,
       msi.orderable_on_web_flag,
       msi.customer_order_enabled_flag,
       p_source
into item_rec
from mtl_system_items msi
where inventory_item_id = p_inventory_item_id and
      organization_id = p_organization_id;

RETURN(item_rec);

EXCEPTION
WHEN NO_DATA_FOUND THEN
RETURN(item_rec);
END get_item_info;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    get_dimensions_uom_conv_code
  Author's Name:   Sandeep Akula
  Date Written:    14-APR-2015
  Purpose:         This Function gives the converted Dimension UOM Code 
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  14-APR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/
FUNCTION get_dimensions_uom_conv_code(p_unit_code IN VARCHAR2,
                                      p_inventory_item_id IN NUMBER)
RETURN VARCHAR2  IS
l_code VARCHAR2(100);
BEGIN

select (CASE WHEN inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_unit_code,p_to_uom_code => 'IN') = '1'  OR 
                  inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_unit_code,p_to_uom_code => 'IN') = '-99999' THEN p_unit_code
             ELSE 'IN' END) 
into l_code
from dual;

RETURN(l_code);

EXCEPTION
WHEN OTHERS THEN
RETURN(p_unit_code);
END get_dimensions_uom_conv_code;
  
--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    get_weight_uom_conv_code
  Author's Name:   Sandeep Akula
  Date Written:    14-APR-2015
  Purpose:         This Function gives the converted Weight UOM Code 
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  14-APR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/
FUNCTION get_weight_uom_conv_code(p_unit_code IN VARCHAR2,
                                  p_inventory_item_id IN NUMBER)
RETURN VARCHAR2 IS
l_code VARCHAR2(100);
BEGIN

select (CASE WHEN inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_unit_code,p_to_uom_code => 'LBS') = '1' OR 
                  inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_unit_code,p_to_uom_code => 'LBS') = '-99999' THEN p_unit_code
             ELSE 'LBS' END) 
into l_code
from dual;

RETURN(l_code);

EXCEPTION
WHEN OTHERS THEN
RETURN(p_unit_code);
END get_weight_uom_conv_code;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    get_dimensions_conv_value
  Author's Name:   Sandeep Akula
  Date Written:    14-APR-2015
  Purpose:         This Function gives the converted value of the Item Dimensions in Inches 
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  14-APR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/
FUNCTION get_dimensions_conv_value(p_unit_value IN NUMBER,
                                   p_inventory_item_id IN NUMBER,
                                   p_uom_code IN VARCHAR2)
RETURN NUMBER IS
l_rate NUMBER;
l_conv_value NUMBER;
BEGIN

l_rate := '';
select (case when inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_uom_code,p_to_uom_code => 'IN') = '-99999' THEN 1
             else inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_uom_code,p_to_uom_code => 'IN') end)
into l_rate            
from dual;

l_conv_value := ROUND(p_unit_value * l_rate,2);

RETURN(l_conv_value);

EXCEPTION
WHEN NO_DATA_FOUND THEN
RETURN(p_unit_value);
WHEN OTHERS THEN
RETURN(p_unit_value);
END get_dimensions_conv_value;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    get_weight_conv_value
  Author's Name:   Sandeep Akula
  Date Written:    14-APR-2015
  Purpose:         This Function gives the converted value of the Item weight in Pounds 
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  14-APR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/  
FUNCTION get_weight_conv_value(p_unit_value IN NUMBER,
                              p_inventory_item_id IN NUMBER,
                              p_uom_code IN VARCHAR2)
RETURN NUMBER IS
l_rate NUMBER;
l_conv_value NUMBER;
BEGIN

l_rate := '';
select (case when inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_uom_code,p_to_uom_code => 'LBS') = '-99999' THEN 1
             else inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_uom_code,p_to_uom_code => 'LBS') end)
into l_rate            
from dual;

l_conv_value := ROUND(p_unit_value * l_rate,2);

RETURN(l_conv_value);

EXCEPTION
WHEN NO_DATA_FOUND THEN
RETURN(p_unit_value);
WHEN OTHERS THEN
RETURN(p_unit_value);
END get_weight_conv_value;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    UPDATE_PRODUCT_DATA
  Author's Name:   Sandeep Akula
  Date Written:    09-MAR-2015
  Purpose:         This Procedure Updates the Product Staging table with Latest Item Attribute Values 
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  09-MAR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE UPDATE_PRODUCT_DATA(p_old_item_rec IN item_rec_type,
                              p_new_item_rec IN item_rec_type,
                              p_err_code OUT NUMBER,
                              p_err_message OUT VARCHAR2) IS
PRAGMA AUTONOMOUS_TRANSACTION;                              
no_record_excp EXCEPTION;
l_err_code NUMBER;
l_err_message VARCHAR2(2000);
BEGIN
      
--IF NOT PRODUCT_EXISTS(p_new_item_rec.inventory_item_id,p_new_item_rec.organization_id) THEN
--RAISE no_record_excp;
--END IF;


UPDATE xxinv_ecom_products
SET description =  p_new_item_rec.description,
    primary_unit_of_measure =  p_new_item_rec.primary_unit_of_measure,
    hazardous_material_flag =  p_new_item_rec.hazardous_material_flag,
    dimension_uom_code =  p_new_item_rec.dimension_uom_code,
    unit_length =  p_new_item_rec.unit_length,
    unit_width =  p_new_item_rec.unit_width,
    unit_height =  p_new_item_rec.unit_height,
    weight_uom_code =  p_new_item_rec.weight_uom_code,
    unit_weight =  p_new_item_rec.unit_weight,
    orderable_on_web_flag = p_new_item_rec.orderable_on_web_flag,
    customer_order_enabled_flag = p_new_item_rec.customer_order_enabled_flag,
    last_updated_by =  p_new_item_rec.last_updated_by,
    last_update_date = SYSDATE,
    status = 'UNPROCESSED',
    processed_flag = NULL,
    processed_date = NULL,
    trigger_action = 'AUR',
    source = p_new_item_rec.source
WHERE inventory_item_id = p_new_item_rec.inventory_item_id and
      organization_id = p_new_item_rec.organization_id;
      
COMMIT;  

p_err_code := '0';
p_err_message := NULL;

EXCEPTION
/*WHEN no_record_excp THEN
insert_product_data(p_new_item_rec   => p_new_item_rec,
                    p_err_code => p_err_code,
                    p_err_message => p_err_message);*/
WHEN OTHERS THEN
p_err_code := '1';
p_err_message := SQLERRM;
ROLLBACK;
END UPDATE_PRODUCT_DATA;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    INSERT_PRODUCT_DATA
  Author's Name:   Sandeep Akula
  Date Written:    09-MAR-2015
  Purpose:         This Procedure Inserts data into the Product Staging table
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  09-MAR-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE INSERT_PRODUCT_DATA(p_new_item_rec IN item_rec_type,
                              p_err_code OUT NUMBER,
                              p_err_message OUT VARCHAR2) IS
PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN

INSERT INTO xxinv_ecom_products
                   (inventory_item_id,
                    item_number,
                    organization_id,
                    description,
                    primary_unit_of_measure,
                    hazardous_material_flag,
                    dimension_uom_code,
                    unit_length,
                    unit_width,
                    unit_height,
                    weight_uom_code,
                    unit_weight,
                    orderable_on_web_flag,
                    customer_order_enabled_flag,
                    created_by,
                    last_updated_by,
                    creation_date,
                    last_update_date,
                    status,
                    --processed_flag,
                    --processed_date,
                    source,
                    destination,
                    trigger_action)
              VALUES(p_new_item_rec.inventory_item_id,
                     p_new_item_rec.segment1,
                     p_new_item_rec.organization_id,
                     p_new_item_rec.description,
                     p_new_item_rec.primary_unit_of_measure,
                     p_new_item_rec.hazardous_material_flag,
                     p_new_item_rec.dimension_uom_code,
                     p_new_item_rec.unit_length,
                     p_new_item_rec.unit_width,
                     p_new_item_rec.unit_height,
                     p_new_item_rec.weight_uom_code,
                     p_new_item_rec.unit_weight,
                     p_new_item_rec.orderable_on_web_flag,
                     p_new_item_rec.customer_order_enabled_flag,
                     p_new_item_rec.created_by,
                     p_new_item_rec.last_updated_by,
                     SYSDATE,  -- creation_date
                     SYSDATE,  -- last_update_date
                     'UNPROCESSED',  -- status
                     --'N',  -- processed_flag
                     --SYDATE, -- processed_date
                     p_new_item_rec.source,  -- source
                     'E-COMMERCE',  -- destination
                     'AIR'); -- trigger_action

COMMIT;

p_err_code := '0';
p_err_message := NULL;

EXCEPTION
WHEN OTHERS THEN
p_err_code := '1';
p_err_message := SQLERRM;
ROLLBACK;
END INSERT_PRODUCT_DATA;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    MTL_UPDATE
  Author's Name:   Sandeep Akula
  Date Written:    01-APRIL-2015
  Purpose:         This Procedure updates the staging table 
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  01-APRIL-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE MTL_UPDATE(p_old_item_rec IN item_rec_type,
                     p_new_item_rec IN item_rec_type,
                     p_err_code OUT NUMBER,
                     p_err_message OUT VARCHAR2) IS
                     
l_error_code NUMBER;
l_error_message VARCHAR2(2000);                     
                       
BEGIN


IF xxinv_ecom_product_pkg.product_exists(p_new_item_rec.inventory_item_id,p_new_item_rec.organization_id) THEN
 
       xxinv_ecom_product_pkg.update_product_data(p_old_item_rec => p_old_item_rec,
                                                  p_new_item_rec   => p_new_item_rec,
                                                  p_err_code  => l_error_code,
                                                  p_err_message => l_error_message);
                                             
            IF  l_error_code = '1' THEN
               p_err_code := l_error_code;
               p_err_message := l_error_message; 
            END IF; 
ELSE
        
       --IF xxinv_ecom_product_pkg.is_ecom_item(p_new_item_rec.inventory_item_id,p_new_item_rec.organization_id) = 'Y' THEN
         IF p_new_item_rec.orderable_on_web_flag = 'Y' AND p_new_item_rec.customer_order_enabled_flag = 'Y' THEN 
       
             xxinv_ecom_product_pkg.insert_product_data(p_new_item_rec   => p_new_item_rec,
                                                        p_err_code  => l_error_code,
                                                        p_err_message => l_error_message); 
                                           
                   IF  l_error_code = '1' THEN
                      p_err_code := l_error_code;
                      p_err_message := l_error_message; 
                   END IF;
                   
        END IF;
    
END IF;

END MTL_UPDATE;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    MTL_INSERT
  Author's Name:   Sandeep Akula
  Date Written:    01-APRIL-2015
  Purpose:         This Procedure inserts into the staging table 
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  01-APRIL-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE MTL_INSERT(p_new_item_rec IN item_rec_type,
                     p_err_code OUT NUMBER,
                     p_err_message OUT VARCHAR2) IS
                     
l_error_code NUMBER;
l_error_message VARCHAR2(2000);                     
                       
BEGIN

IF p_new_item_rec.source = 'MTL_ITEM_CATEGORIES' AND p_new_item_rec.orderable_on_web_flag = 'Y' AND p_new_item_rec.customer_order_enabled_flag = 'Y' THEN 

 xxinv_ecom_product_pkg.update_product_data(p_new_item_rec   => p_new_item_rec,
                                            p_err_code  => l_error_code,
                                            p_err_message => l_error_message); 
                                             
                   IF  l_error_code = '1' THEN
                      p_err_code := l_error_code;
                      p_err_message := l_error_message; 
                   END IF;


ELSE

IF NOT xxinv_ecom_product_pkg.product_exists(p_new_item_rec.inventory_item_id,p_new_item_rec.organization_id) AND
       --xxinv_ecom_product_pkg.is_ecom_item(p_new_item_rec.inventory_item_id,p_new_item_rec.organization_id) = 'Y' THEN
       p_new_item_rec.orderable_on_web_flag = 'Y' AND p_new_item_rec.customer_order_enabled_flag = 'Y' THEN 

   xxinv_ecom_product_pkg.insert_product_data(p_new_item_rec   => p_new_item_rec,
                                              p_err_code  => l_error_code,
                                              p_err_message => l_error_message); 
                                             
                   IF  l_error_code = '1' THEN
                      p_err_code := l_error_code;
                      p_err_message := l_error_message; 
                   END IF;
END IF;

END IF;

END MTL_INSERT;
--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    MAIN
  Author's Name:   Sandeep Akula
  Date Written:    12-MARCH-2015
  Purpose:         This Procedure generates Product File for Hybris
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  12-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034783
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_file_name IN VARCHAR2,
               p_data_dir IN VARCHAR2) IS

CURSOR C_ITEMS_EXTRACT IS
SELECT rowid,
       inventory_item_id,
       item_number,
       organization_id,
       description,
       primary_unit_of_measure,
       hazardous_material_flag,
       --dimension_uom_code,
       get_dimensions_uom_conv_code(dimension_uom_code,inventory_item_id) dimension_uom_code,
       --unit_length,
       --unit_width,
       --unit_height,
       get_dimensions_conv_value(unit_length,inventory_item_id,dimension_uom_code) unit_length,
       get_dimensions_conv_value(unit_width,inventory_item_id,dimension_uom_code) unit_width,
       get_dimensions_conv_value(unit_height,inventory_item_id,dimension_uom_code) unit_height,
       --weight_uom_code,
       get_weight_uom_conv_code(weight_uom_code,inventory_item_id) weight_uom_code,             
       --unit_weight,
       get_weight_conv_value(unit_weight,inventory_item_id,weight_uom_code) unit_weight,
       created_by,
       last_updated_by,
       creation_date,
       last_update_date,
       status,
       source,
       destination,
       trigger_action,
       orderable_on_web_flag,
       customer_order_enabled_flag,
       (CASE WHEN orderable_on_web_flag = 'Y' AND customer_order_enabled_flag = 'Y' THEN '0' -- Active
             ELSE '1' -- InActive Flag
             END) active_flag,
       xxinv_utils_pkg.get_category_segment('SEGMENT5',1100000221,inventory_item_id) family,  -- Oracle Flavor segment is equal to Hybris Family 
       xxinv_utils_pkg.get_category_segment('SEGMENT1',1100000221,inventory_item_id) line_of_business,
       xxinv_utils_pkg.get_category_segment('SEGMENT6',1100000221,inventory_item_id) technology,
       XXINV_UTILS_PKG.get_category_segment('SEGMENT1',1100000201,inventory_item_id) ava_tax_code
FROM xxinv_ecom_products
WHERE processed_flag IS NULL AND
      status = 'UNPROCESSED' and
      organization_id = '91'; -- OMA Organization 

file_handle               UTL_FILE.FILE_TYPE;
l_instance_name   v$database.name%type;
l_directory       VARCHAR2(2000);
l_programid       NUMBER := apps.fnd_global.conc_program_id ;
l_request_id      NUMBER:= fnd_global.conc_request_id;
l_sysdate         VARCHAR2(100);
l_file_creation_date VARCHAR2(100);
l_count           NUMBER := '';
l_prg_exe_counter        VARCHAR2(100) := '';
l_file_name              VARCHAR2(200) := '';
l_error_message          varchar2(32767) := '';
l_mail_list VARCHAR2(500);
l_err_code  NUMBER;
l_err_msg   VARCHAR2(200);
FILE_RENAME_EXCP EXCEPTION;
l_default_value fnd_descr_flex_col_usage_vl.default_value%type;

-- Error Notification Variables
l_notf_data_directory varchar2(500) := '';
l_notf_file_name varchar2(100) := '';
l_notf_requestor varchar2(200) := '';
l_notf_data varchar(32767) := '';
l_notf_program_short_name varchar2(100) := '';

BEGIN

 l_prg_exe_counter := '0';

  /* Getting data elements for Error Notification*/
l_error_message := 'Error Occured while getting Notification Details for Request ID :'||l_request_id;
select trim(substr(argument_text,1,instr(argument_text,',',1,1)-1)) file_name,
       trim(substr(argument_text,instr(argument_text,',',1,1)+1)) data_directory,
       requestor,
       program_short_name
into l_notf_file_name,l_notf_data_directory,l_notf_requestor,l_notf_program_short_name
from fnd_conc_req_summary_v
where request_id = l_request_id;

l_prg_exe_counter := '1';

l_notf_data := 'Data Directory:'||l_notf_data_directory||chr(10)||
               'File Name:'||l_notf_file_name||chr(10)||
               'Requestor:'||l_notf_requestor;

l_prg_exe_counter := '2';

                     -- Deriving the Instance Name

                      l_error_message := 'Instance Name could not be found';

                      SELECT NAME
                      INTO  l_INSTANCE_NAME
                      FROM V$DATABASE;


                      -- Deriving the Directory Path

                       l_error_message := 'Directory Path Could not be Found';
                        SELECT p_data_dir
                        INTO  l_DIRECTORY
                        FROM DUAL;

        l_prg_exe_counter := '3';

l_default_value := '';
begin        
select default_value
into l_default_value
from fnd_descr_flex_col_usage_vl
where application_id=222 and 
      descriptive_flexfield_name like 'RA_CUSTOMER_TRX_LINES' and 
      descriptive_flex_context_code = 'Global Data Elements' and
      end_user_column_name = 'Avalara Tax Code';
exception
when no_data_found then
l_default_value := null;
end;

l_prg_exe_counter := '3.1';

l_file_name:= '';
l_error_message := ' Error Occured while Deriving l_file_name';
l_file_name := p_file_name||'_'||to_char(sysdate,'MMDDRRRRHH24MISS')||'.csv.tmp';  -- Creating file with .tmp extension so that BPEL cannot process the file
l_prg_exe_counter := '4';

 -- File Handle for Outbound File
 l_error_message := 'Error Occured in UTL_FILE.FOPEN (FILE_HANDLE)';
FILE_HANDLE  := UTL_FILE.FOPEN(l_DIRECTORY,l_file_name,'W',32767);
l_prg_exe_counter := '5';

l_error_message   := 'Error Occured in UTL_FILE.PUT_LINE (FILE_HANDLE): Headers';
UTL_FILE.PUT_LINE(FILE_HANDLE,'erpItemId'||'|'||
                              'erpName'||'|'||
                              'erpDescription'||'|'||
                              'ItemUOM'||'|'||
                              'hazardousMaterial'||'|'||
                              'dimensionUOM'||'|'||
                              'packingLength'||'|'||
                              'packingWidth'||'|'||
                              'packingHeight'||'|'||
                              'weigthUOM'||'|'||
                              'weigth'||'|'||
                              'family'||'|'||
                              'lineOfBusiness'||'|'||
                              'technology'||'|'||
                              'Status'||'|'||
                              'TaxCode'
                       );

l_prg_exe_counter := '5.1';
l_count := '0';
l_error_message := 'Error Occured While Opening Cursor c_items_extract';
for c_1 in c_items_extract loop
l_prg_exe_counter := '6';

l_error_message   := 'Error Occured in UTL_FILE.PUT_LINE (FILE_HANDLE): Data';
UTL_FILE.PUT_LINE(FILE_HANDLE,c_1.inventory_item_id||'|'||           -- ERP Item ID
                              c_1.item_number||'|'||                 -- erpName
                              c_1.description||'|'||                 -- erpDescription
                              c_1.primary_unit_of_measure||'|'||     -- ItemUOM
                              c_1.hazardous_material_flag||'|'||     -- hazardousMaterial
                              c_1.dimension_uom_code||'|'||          -- dimensionUOM
                              c_1.unit_length||'|'||                 -- packingLength
                              c_1.unit_width||'|'||                  -- packingWidth
                              c_1.unit_height||'|'||                 -- packingHeight
                              c_1.weight_uom_code||'|'||             -- weigthUOM 
                              c_1.unit_weight||'|'||                 -- weigth
                              c_1.family||'|'||                      -- family
                              c_1.line_of_business||'|'||            -- lineOfBusiness
                              c_1.technology||'|'||                  -- technology
                              c_1.Active_flag||'|'||                 -- Status
                              NVL(c_1.ava_tax_code,l_default_value)  -- Avalara Tax Code 
                       );

      l_prg_exe_counter := '7';
     
     l_error_message := 'Error Occured while updating table xxinv_ecom_products for Item :'||c_1.item_number||' and organization id :'||c_1.organization_id; 
      UPDATE xxinv_ecom_products
      SET processed_flag = 'Y',
          processed_date = SYSDATE,
          status = 'PROCESSED'
      WHERE rowid = c_1.rowid;
      
      l_count := l_count + 1;  -- Count of Records

END LOOP;
l_prg_exe_counter := '8';

IF l_count > '0' THEN
l_prg_exe_counter := '9';

         -- Output File

        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'=========================  LOADING SUMMARY  ======================');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'-------------------------------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,CHR(10));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Request ID: ' || L_REQUEST_ID) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Instance Name: ' ||l_INSTANCE_NAME) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Directory Path is : ' ||l_DIRECTORY) ;
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+======================  Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_data_dir   :'||p_data_dir);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'p_file_name   :'||p_file_name);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================== End Of Parameters  ============================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'---------------------------------------------');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Temp File Name is : '||l_file_name);
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'The File Name is : '||substr(l_file_name,0,length(l_file_name)-4));      
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'Record Count is : '||(l_count));
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'+====================================================================+');
        FND_FILE.PUT_LINE(FND_FILE.OUTPUT,'----------------------------------------------');
        l_prg_exe_counter := '11';

   l_error_message := 'Error Occured in Closing the FILE_HANDLE (file_handle)';
        UTL_FILE.FCLOSE(file_handle);
         l_prg_exe_counter := '12';
         
-- Renaming the file name so that BPEL Processes the File 
BEGIN
          l_prg_exe_counter := '12.1';
          UTL_FILE.frename(l_DIRECTORY,l_file_name,l_DIRECTORY,substr(l_file_name,0,length(l_file_name)-4),TRUE);
EXCEPTION
WHEN OTHERS THEN
l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : Error while Renaming the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
RAISE FILE_RENAME_EXCP;
END;
        
l_prg_exe_counter := '12.2';

ELSE
l_prg_exe_counter := '13';
 l_error_message := 'Error Occured in Closing the FILE_HANDLE (file_handle)';
        UTL_FILE.FCLOSE(file_handle);
l_prg_exe_counter := '14';
 BEGIN
          l_prg_exe_counter := '15';
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;

l_prg_exe_counter := '16';
END IF;
l_prg_exe_counter := '17';

COMMIT;

EXCEPTION
WHEN NO_DATA_FOUND THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : NO_DATA_FOUND - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : NO_DATA_FOUND - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINV_PRODUCT_OUTBOUND');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'E-Commerce Product Outbound Failed'||' - '||l_request_id,
                              p_body_text   => 'E-Commerce Product Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create Product File for Hybris'||chr(10)||
                                               'NO_DATA_FOUND Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* E-Commerce Product Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN UTL_FILE.INVALID_PATH THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.INVALID_PATH - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.INVALID_PATH - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINV_PRODUCT_OUTBOUND');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'E-Commerce Product Outbound Failed'||' - '||l_request_id,
                              p_body_text   => 'E-Commerce Product Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create Product File for Hybris'||chr(10)||
                                               'UTL_FILE.INVALID_PATH Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* E-Commerce Product Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN UTL_FILE.READ_ERROR THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.READ_ERROR - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.READ_ERROR - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINV_PRODUCT_OUTBOUND');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'E-Commerce Product Outbound Failed'||' - '||l_request_id,
                              p_body_text   => 'E-Commerce Product Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create Product File for Hybris'||chr(10)||
                                               'UTL_FILE.READ_ERROR Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* E-Commerce Product Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN UTL_FILE.WRITE_ERROR THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.WRITE_ERROR - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : UTL_FILE.WRITE_ERROR - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINV_PRODUCT_OUTBOUND');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'E-Commerce Product Outbound Failed'||' - '||l_request_id,
                              p_body_text   => 'E-Commerce Product Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create Product File for Hybris'||chr(10)||
                                               'UTL_FILE.WRITE_ERROR Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* E-Commerce Product Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
WHEN FILE_RENAME_EXCP THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : FILE_RENAME_EXCP - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : FILE_RENAME_EXCP - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINV_PRODUCT_OUTBOUND');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'E-Commerce Product Outbound Failed'||' - '||l_request_id,
                              p_body_text   => 'E-Commerce Product Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create Product File for Hybris'||chr(10)||
                                               'FILE_RENAME_EXCP Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* E-Commerce Product Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);                              
WHEN OTHERS THEN
UTL_FILE.FCLOSE(file_handle);
ROLLBACK;
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
retcode := '2';
errbuf := l_error_message;
/* Deleting File in case of Failure */
      BEGIN
          UTL_FILE.fremove (l_DIRECTORY,l_file_name);
      EXCEPTION
                 WHEN UTL_FILE.delete_failed THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : OTHERS - Error while deleting the file :'||l_file_name||' | '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
                 WHEN OTHERS THEN
                 l_ERROR_MESSAGE := l_ERROR_MESSAGE||' : OTHERS - Error while deleting the file :'||l_file_name||' | OTHERS Exception : '||SQLERRM||' Prg Cntr :'||l_prg_exe_counter;
                 FND_FILE.PUT_LINE(FND_FILE.LOG,l_error_message);
      END;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXINV_PRODUCT_OUTBOUND');
xxobjt_wf_mail.send_mail_text(p_to_role     => l_notf_requestor,
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'E-Commerce Product Outbound Failed'||' - '||l_request_id,
                              p_body_text   => 'E-Commerce Product Outbound Request Id :'||l_request_id||chr(10)||
                                               'Could not create Product File for Hybris'||chr(10)||
                                               'OTHERS Exception'||chr(10)||
                                                'Error Message :' ||l_error_message||chr(10)||
                                                '******* E-Commerce Product Outbound Parameters *********'||chr(10)||
                                                l_notf_data,
                              p_err_code    => l_err_code,
                              p_err_message => l_err_msg);
END MAIN;
END xxinv_ecom_product_pkg;
/
