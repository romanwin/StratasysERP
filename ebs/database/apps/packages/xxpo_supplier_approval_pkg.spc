CREATE OR REPLACE PACKAGE xxpo_supplier_approval_pkg IS

  --------------------------------------------------------------------
  --  name:       xxpo_supplier_approval_pkg     
  --  create by:    yuval tal  
  --  Revision:        1.0 
  --  creation date:   26.11.2012 
  --------------------------------------------------------------------
  --  purpose :        CUST607- support supplier approval process
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.11.2012    yuval tal      initial build
  --------------------------------------------------------------------  

  --------------------------------------------------------------------
  --  name:           
  --  create by:       
  --  Revision:        1.0 
  --  creation date:   
  --------------------------------------------------------------------
  --  purpose:    Define for each Vendor type if to include in approval process or not      

  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.11.2012    yuval tal    initial build
  --------------------------------------------------------------------  
  FUNCTION is_approval_process_needed(p_vendor_type VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_mail_dist(p_supplier_status VARCHAR2, p_created_by NUMBER)
    RETURN VARCHAR2;

  PROCEDURE send_mail(p_vendor_id      NUMBER,
                      p_created_by     NUMBER,
                      p_supplier_name  VARCHAR2,
                      p_old_status     VARCHAR2,
                      p_new_status     VARCHAR2,
                      p_history_ind    VARCHAR2 DEFAULT 'N',
                      p_dist_role_name VARCHAR2 DEFAULT NULL,
                      p_subject_prefix VARCHAR2 DEFAULT NULL);

  FUNCTION attachment_exists(p_vendor_id            NUMBER,
                             p_approval_status_code VARCHAR2) RETURN VARCHAR2;

  FUNCTION is_hierarchy_exists(p_old_status VARCHAR2,
                               p_new_status VARCHAR2) RETURN NUMBER;

  FUNCTION get_approval_status_by_seq(p_seq NUMBER) RETURN VARCHAR2;
  FUNCTION get_last_status RETURN VARCHAR2;
  PROCEDURE status_escalation(errbuff OUT VARCHAR2, errcode OUT VARCHAR2);
END xxpo_supplier_approval_pkg;
/
