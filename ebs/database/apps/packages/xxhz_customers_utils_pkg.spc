CREATE OR REPLACE PACKAGE xxhz_customers_utils_pkg IS

  -----------------------------------------------------------------------
  --  customization code: GENERAL
  --  name:               XXHZ_CUSTOMERS_UTILS_PKG
  --  create by:          Dalit A. RAviv
  --  $Revision:          1.0 
  --  creation date:      12/10/2010 
  --  Purpose :           Customers generic package
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/10/2010    Dalit A. Raviv  Initial version
  --  1.1   03.11.2011    yuval atl       add upd_site_salesrep
  --  1.2   16/04/2012    Dalit A. Raviv  add procedure close person + relationship
  --                                      inactive_contact_person, inactive_person_relationship
  -----------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            create_cust_account_role
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   12/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that create cust account role                
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_cust_account_role(errbuf  OUT VARCHAR2,
                                     retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            create_cust_account
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that create cust account for partyies with no account           
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_cust_account(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            upd_org_contact_job_title
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   13/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that update job title and job title_code   
  --                   at update_org_contact     
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                                   
  PROCEDURE upd_org_contact_job_title(errbuf   OUT VARCHAR2,
                                      retcode  OUT VARCHAR2,
                                      p_entity IN VARCHAR2);

  PROCEDURE upd_site_salesrep(errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_agent_id        NUMBER,
                              p_sales_person    NUMBER,
                              p_party_id        NUMBER,
                              p_postal_code     VARCHAR2,
                              p_Country         VARCHAR2,
                              p_state           VARCHAR2,
                              p_new_salesrep_id NUMBER);

  --------------------------------------------------------------------
  --  name:            inactive_contact_person
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/04/2012 
  --------------------------------------------------------------------
  --  purpose :        Procedure that close prty from type person (Inactive) 
  --                   at hz_party              
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/04/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure inactive_contact_person(errbuf       out varchar2,
                                    retcode      out varchar2,
                                    p_party_name in  varchar2,
                                    p_status     in  varchar2);

  --------------------------------------------------------------------
  --  name:            inactive_person_relationship
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   16/04/2012 
  --------------------------------------------------------------------
  --  purpose :        Procedure that close person relationships (Inactive)             
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/04/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure inactive_person_relationship(errbuf       out varchar2,
                                         retcode      out varchar2,
                                         p_party_name in  varchar2,
                                         p_status     in  varchar2);

  --------------------------------------------------------------------
  --  name:            inactive_cust_acc_role
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   27/09/2012 
  --------------------------------------------------------------------
  --  purpose :        Procedure that close person cust account role (Inactive) 
  --                   this proceduer run first then close relationship and then 
  --                   close perosn           
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/09/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure inactive_cust_acc_role (errbuf       out varchar2,
                                    retcode      out varchar2,
                                    p_party_name in  varchar2,
                                    p_status     in  varchar2 );
                                    
  --------------------------------------------------------------------
  --  name:            upd_site_agente
  --  create by:       Ofer Suad
  --  Revision:        1.0 
  --  creation date:   09/08/2012 
  --------------------------------------------------------------------
  --  purpose :        chage parties agent        
  --------------------------------------------------------------------

  PROCEDURE upd_site_agent(errbuf          OUT VARCHAR2,
                           retcode         OUT VARCHAR2,
                           p_from_agent_id NUMBER,
                           p_party_id      NUMBER,
                           p_postal_code   VARCHAR2,
                           p_Country       VARCHAR2,
                           p_state         VARCHAR2,
                           p_to_agent_id   NUMBER);
END xxhz_customers_utils_pkg;
/
