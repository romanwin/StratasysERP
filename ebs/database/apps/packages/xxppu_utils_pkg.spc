create or replace package xxppu_utils_pkg IS

  c_yes                  CONSTANT VARCHAR2(10) := 'Y';
  c_no                   CONSTANT VARCHAR2(10) := 'N';
  c_last_run_date_format CONSTANT VARCHAR2(30) := 'YYYYMMDDHH24MISS';
  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  -- 1.1     10.9.2019    Bellona B.      CHG0046049 - added get_so_order_type, get_so_line_type,
  --                                      is_system_item, is_material_item, check_ppu_system_item  
  ------------------------------------------------------------------------------------------  
  PROCEDURE set_last_run_date(p_last_run_date DATE,
		      p_error_desc    OUT VARCHAR2,
		      p_error_code    OUT VARCHAR2);

  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-28   Roman W.        CHG0045829
  ------------------------------------------------------------------------------------------    
  FUNCTION get_qubic_inch_per_unit(p_material_part_id NUMBER) RETURN NUMBER;

  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  ------------------------------------------------------------------------------------------
  PROCEDURE fill_data_main(errbuf  OUT VARCHAR2,
		   retcode OUT VARCHAR2);

  FUNCTION get_last_run_date RETURN DATE;

  --------------------------------------------------------------------
  --  purpose :     CHG0046049 - called from form personalization - add get_SO_line_type
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  --------------------------------------------------------------------

  FUNCTION get_so_line_type(p_line_id NUMBER) RETURN VARCHAR2;

  ------------------------------------------------------------
  -- Name: is_system_item
  -- Description: Returns Y if the supplied item is of type:
  --              1. Systems (net) 2. Systems-Used
  --              and N if not.       
  -------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  ------------------------------------------------------------
  FUNCTION is_system_item(p_inventory_item_id NUMBER) RETURN VARCHAR2;

  ------------------------------------------------------------
  -- Name: is_waterjet_item
  -- Description: Returns Y if the supplied item is of type:
  --              Water-Jet
  --              and N if not.       
  -------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  ------------------------------------------------------------
  FUNCTION is_waterjet_item(p_inventory_item_id NUMBER) RETURN VARCHAR2; 
  ------------------------------------------------------------
  -- Name: is_material_item
  -- Description: Returns Y if the supplied item is Materials item
  --              [product hierarchy category segment1 ='Materials']
  --              and N if not.       
  -------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  ------------------------------------------------------------
  FUNCTION is_material_item(p_inventory_item_id NUMBER) RETURN VARCHAR2;
  

  ------------------------------------------------------------
  -- Name: show_ppu_system_item_msg
  -- Description: Returns Y if related conditions of CHG0046049 satisfies
  --              For Material items (product hierarchy category segmnet1 ='Materials') 
  --              the line DFF 'Service S/N'  (attribute1) is not null, 
  --              contract template of the S/N in this DFF is in ('Partner PPU','PPU Warranty') 
  --              and returns N if not.       
  -------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  ------------------------------------------------------------
  FUNCTION show_ppu_system_item_msg(p_header_id  NUMBER,
			p_order_type VARCHAR2) RETURN VARCHAR2;
            
  ------------------------------------------------------------
  -- Name: show_ppu_material_item_msg
  -- Description: Returns Y if related conditions of CHG0046049 satisfies
  --              For Material items (product hierarchy category segmnet1 ='Materials') 
  --              the line DFF 'Service S/N'  (attribute1) is not null, 
  --              contract template of the S/N in this DFF is in ('Partner PPU','PPU Warranty') 
  --              and returns N if not.       
  -------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  ------------------------------------------------------------
  FUNCTION show_ppu_material_item_msg(p_header_id  NUMBER,
			p_order_type VARCHAR2) RETURN VARCHAR2;            

  PROCEDURE is_contract_active(p_printer_part_number_id IN NUMBER,
		       p_printer_sn             IN VARCHAR2,
		       p_account_number         IN VARCHAR2,
		       p_contract_flag          OUT VARCHAR2,
		       p_error_desc             OUT VARCHAR2,
		       p_error_code             OUT VARCHAR2);
END xxppu_utils_pkg;
/