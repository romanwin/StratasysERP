create or replace package xxoe_order_acknowledgment_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: xxoe_order_acknowledgment_pkg
  ---------------------------------------------------------------------------
  -- Package: xxoe_order_acknowledgment_pkg
  -- Created: 10/02/2011
  -- Author : Yuval Tal
  --------------------------------------------------------------------------
  -- Perpose: Sales order approval process
  --------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -------------------------------------
  -- 1.0                                  Initial Build
  -- 1.1      2.10.11     yuval tal       add submit_order_ack_by_mail
  -- 1.2      17.10.11    yuval tal       change logic in get_mail_dist
  -- 1.3      08/04/2015  Diptasurjya     CHG0036213 - submit_aerospace_ack, submit_aerospace_email added
  -- 1.4      07/03/2017  Lingaraj        CHG0040074 - Warranty extension - DACH
  --                                      Added a new Procedure get_warranty_extension_msg
  ---------------------------------------------------------------------------
  PROCEDURE submit_order_acknowledgment(p_header_id IN NUMBER);
  PROCEDURE submit_order_ack_by_mail(errbuf  OUT VARCHAR2,
                                     retcode OUT VARCHAR2);
  FUNCTION get_contact_mail_distribution(p_header_id NUMBER) RETURN VARCHAR2;


  --------------------------------------------------------------------
  --  Name      :        submit_aerospace_email
  --  Created By:        Diptasurjya Chatterjee
  --  Revision:          1.0
  --  Creation Date:     09/21/2015
  --------------------------------------------------------------------
  --  Purpose :          CHG0036213 - This procedure will be called from
  --                     the order header workflow XX: Order Flow - Generic
  --                     to submit XML Bursting program for
  --                     Order Acknowledgement program request ID
  --------------------------------------------------------------------
  --  Ver  Date          Name                         Desc
  --  1.0  09/21/2015    Diptasurjya Chatterjee       Initial Build
  --------------------------------------------------------------------
  PROCEDURE submit_aerospace_email(errbuf  OUT VARCHAR2,
                                   retcode OUT VARCHAR2,
                                   p_header_id IN varchar2);
  
  --------------------------------------------------------------------
  --  customization code: CHG0040074
  --  name:               get_warranty_extension_msg
  --  create by:          Lingaraj Sarangi
  --  Revision:           1.0
  --  creation date:      07-Mar-2017 
  --  Purpose :           This is the Procedure which support the dynamic sql.
  --  Return Value:       VARCHAR2                             
  ----------------------------------------------------------------------
  --  ver   date          name                desc
  --  1.0   07-Mar-2017   Lingaraj Sarangi    Initial Build: CHG0040074
  ----------------------------------------------------------------------
  PROCEDURE get_warranty_extension_msg(p_oh_header_id IN  NUMBER,--Order Header Id
                                       x_ret_msg   OUT VARCHAR2,
                                       x_errcode   OUT VARCHAR2,
                                       x_errbuf    OUT VARCHAR2);                                 

END xxoe_order_acknowledgment_pkg;
/