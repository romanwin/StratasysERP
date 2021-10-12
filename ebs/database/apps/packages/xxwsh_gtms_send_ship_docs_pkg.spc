create or replace package xxwsh_gtms_send_ship_docs_pkg IS
  --------------------------------------------------------------------
  --  name:            xxwsh_gtms_send_ship_docs_pkg
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   12/05/2015
  --------------------------------------------------------------------
  --  purpose :        Sending shipping documents by FTP Folder
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --  1.1   19.2.17       YUVAL TAL       CHG0039163 modify submit_shipping_docs
  --  1.2   20.02.2018  bellona banerjee  CHG0041294- Added P_Delivery_Name to 
  --	    							  send_shipping_docs, submit_shipping_docs
  --									  submit_document_set as part of delivery_id 
  --									  to delivery_name conversion.
  --------------------------------------------------------------------
  
  
  --------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               send_shipping_docs
  --  create by:          Michal Tzvik
  --  creation date:      12/05/2015
  --  Purpose :           CHG0034901 - Sending shipping documents by FTP Folder
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/05/2015    Michal Tzvik  Initial Build
  ----------------------------------------------------------------------
  PROCEDURE send_shipping_docs(errbuf        OUT VARCHAR2,
               retcode       OUT VARCHAR2,
               --p_delivery_id IN NUMBER);    -- CHG0041294 on 20/02/2018 for delivery id to name change
               p_delivery_name     in varchar2);

  --------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               submit_shipping_docs
  --  create by:          Michal Tzvik
  --  creation date:      12/05/2015
  --  Purpose :           CHG0034901 - Sending shipping documents by FTP Folder
  --                      Run concurrent program XXWSH_SEND_SHIPPING_DOCS
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/05/2015    Michal Tzvik  Initial Build
  -- 1.1    19.2.17       YUVAL TAL     CHG0039163 FORWARD proc to new proc submit_document_set
  ----------------------------------------------------------------------
  PROCEDURE submit_shipping_docs(--p_delivery_id IN NUMBER, -- CHG0041294 on 20/02/2018 for delivery id to name change
                 p_delivery_name     in varchar2,
                 x_err_code    OUT NUMBER,
                 x_err_msg     OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CHG0039163
  --  name:               submit_document_set
  --  create by:          Lingaraj Sarangi
  --  creation date:      19/02/2017
  --  Purpose :           CHG0039163 - Auto submit Shipping docs
  --                      Submit the Concurrent Program 'XXCUSTDOCSUB' to Submit a Set of Programs
  ----------------------------------------------------------------------
  --  ver   date          name               desc
  --  1.0   19/02/2017    Lingaraj Sarangi   Initial Build  
  ----------------------------------------------------------------------
  PROCEDURE submit_document_set(p_set_code    IN VARCHAR2 DEFAULT 'GTMS',
                --p_delivery_id IN VARCHAR2,    -- CHG0041294 on 20/02/2018 for delivery id to name change
                p_delivery_name     in varchar2,
                x_err_code    OUT NUMBER,
                x_err_msg     OUT VARCHAR2);

END xxwsh_gtms_send_ship_docs_pkg;
/