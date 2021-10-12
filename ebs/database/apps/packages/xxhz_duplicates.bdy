CREATE OR REPLACE PACKAGE BODY xxhz_duplicates AS
--------------------------------------------------------------------
--  name:            XXHZ_DUPLICATES
--  create by:       Mike Mazanet
--  Revision:        1.1
--  creation date:   20/11/2014 
--------------------------------------------------------------------
--  purpose : Packaged used for dealing with duplicates in the HZ 
--            customer module
--
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.1  10/01/2015  Diptasurjya       CHG0034258 - Added common handling 
--                                     of duplicate site checks as is prsent in
--                                     the new customer form. This will be used 
--                                     reporting duplicate customer site reporting
--------------------------------------------------------------------

g_log           VARCHAR2(1)   := fnd_profile.value('AFLOG_ENABLED');
g_log_module    VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
g_program_unit  VARCHAR2(30);


  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  01/16/2015  mmazanet    CHG0034258.  initial build
  -- ---------------------------------------------------------------------------------------------
   PROCEDURE write_log(p_msg  VARCHAR2)
   IS 
   BEGIN
      IF g_log = 'Y' AND 'xxhz.duplicates.xxhz_duplicates.'||g_program_unit LIKE LOWER(g_log_module) THEN
         fnd_file.put_line(fnd_file.log,TO_CHAR(SYSDATE,'HH:MI:SS')||' - '||p_msg); 
      END IF;
   END write_log; 

  -- ----------------------------------------------------------------------------------
  -- Purpose: Find Duplicate Sites given an address. This will use the same function 
  --          as is being used from the new Customer Form- XXHZ_API_PKG.find_duplicate_sites
  -- ----------------------------------------------------------------------------------
  -- Ver  Date        Name                        Description
  -- 1.0  10/01/2015  Diptasurjya Chatterjee      CHG0034258.  initial build
  -- ----------------------------------------------------------------------------------
  
  FUNCTION dup_cust_site_wrapper (p_address1                  IN VARCHAR2,
                                  p_address2                  IN VARCHAR2,
                                  p_address3                  IN VARCHAR2,
                                  p_address4                  IN VARCHAR2,
                                  p_city                      IN VARCHAR2,
                                  p_state                     IN VARCHAR2,
                                  p_province                  IN VARCHAR2,
                                  p_postal_code               IN VARCHAR2,
                                  p_country                   IN VARCHAR2,
                                  p_location_id               IN NUMBER,
                                  p_cust_account_id           IN NUMBER) return varchar2 IS
    l_site_dup_status  varchar2(2000) := 'N';
    
    l_dup_tbl          xxhz_api_pkg.dup_tbl;
    l_api_status       varchar2(1);
    l_api_status_msg   varchar2(4000);
  BEGIN
    XXHZ_API_PKG.find_duplicate_sites(p_cust_account_id   => p_cust_account_id,
                                      p_location_id       => p_location_id,
                                      p_address1          => p_address1,
                                      p_address2          => p_address2,
                                      p_address3          => p_address3,
                                      p_address4          => p_address4,
                                      p_city              => p_city,
                                      p_state             => p_state,
                                      p_province          => p_province,
                                      p_postal_code       => p_postal_code,
                                      p_country           => p_country,
                                      p_dup_sites_tbl     => l_dup_tbl,
                                      x_return_status     => l_api_status,
                                      x_return_message    => l_api_status_msg);
                                      
    if l_api_status = 'D' and l_dup_tbl is not null and l_dup_tbl.count > 0 then
      l_site_dup_status := l_dup_tbl(1).match_type;
    end if;
    return l_site_dup_status;
  END;
END xxhz_duplicates; 
/
SHOW ERRORS