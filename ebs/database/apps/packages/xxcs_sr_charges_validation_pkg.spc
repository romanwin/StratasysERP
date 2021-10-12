CREATE OR REPLACE PACKAGE xxcs_sr_charges_validation_pkg IS
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
  -------------------------------------------------------------------- 
  PROCEDURE check_sr_charges_validation(p_incident_id       IN NUMBER,
                                        p_new_inc_status_id IN NUMBER,
                                        p_out_status        IN OUT VARCHAR2);
                                         
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
                                p_comment           IN  VARCHAR2);
                                         
END XXCS_SR_CHARGES_VALIDATION_PKG;
/
