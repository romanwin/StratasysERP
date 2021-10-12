CREATE OR REPLACE PACKAGE xxcsf_alerts_pub AUTHID CURRENT_USER AS
/*$Header: csfAlerts.pls 120.0.12000000.5 2007/07/24 09:35:49 htank noship $*/

--------------------------------------------------------------------
--  customization code: CUST457 - CSF Task Assignment WF modification
--  name:               XXcsf_alerts_pub
--  create by:          Dalit A. Raviv
--  $Revision:          1.0
--  creation date:      21/09/2011
--  Purpose :           This package call from WF Field Service Task Assignment Alerts
--                      original WF call csf_alerts_pub package.
--                      to be able to modify WF to our needs there was a need to change
--                      and copy oracle package (csf_alerts_pub).
--
--                      1) add field to global variable task_asgn_record
--                      2) correct bug at function getTaskDetails
--                      3) change procedure getAssignedMessage
--
--                      NOTE:
--                      When patch install need to modify this package if there was changes
--                      at csf_alerts_pub package.
----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0  21/09/2011    Dalit A. Raviv  initial build
--  1.1  03/11/2011    Dalit A. Raviv  correct source of varibale according to
--                                     oracle patch 120.0.12000000.8
--  1.2  13/02/2012    Dalit A. Raviv  add new function getSubject - handle message subject str
-----------------------------------------------------------------------

--------------------------------------------------------------------
--  customization code: CUST457 - CSF Task Assignment WF modification
--  name:               XXcsf_alerts_pub
--  create by:          Dalit A. Raviv
--  $Revision:          1.0
--  creation date:      21/09/2011
--  Purpose :           add field task_type
----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0  21/09/2011    Dalit A. Raviv  initial build
-----------------------------------------------------------------------
  -- to store task detail for notification content
  type task_asgn_record is record
    ( task_number      jtf_tasks_b.task_number%type,
      task_name        jtf_tasks_vl.task_name%type,
      task_desc        jtf_tasks_vl.description%type,
      sch_st_date      jtf_tasks_b.scheduled_start_date%type,
      old_sch_st_date  jtf_tasks_b.scheduled_start_date%type,
      sch_end_date     jtf_tasks_b.scheduled_end_date%type,
      old_sch_end_date jtf_tasks_b.scheduled_end_date%type,
      planned_effort   varchar2(100),
      priority         jtf_task_priorities_vl.name%type,
      asgm_sts_name    jtf_task_statuses_vl.name%type,
      sr_number        cs_incidents_all_b.incident_number%type,
      -- 03/11/2011 Dalit A. Raviv
      --sr_summary       s.summary%type,
      sr_summary       cs_incidents_all_tl.summary%type, -- Oracle patch 120.0.12000000.8
      --
      product_nr       mtl_system_items_vl.concatenated_segments%type,
      item_serial      cs_customer_products_all.current_serial_number%type,
      item_description mtl_system_items_vl.description%type,
      cust_name        hz_parties.party_name%type,
      cust_address     varchar2(1000),
      contact_name     varchar2(100),
      contact_phone    varchar2(100),
      contact_email    varchar2(250),
      task_type        varchar2(100) -- 1.0  21/09/2011    Dalit A. Raviv
    );

  -- to store contact details for notification content
  type contact_record is record
    ( contact_name    varchar2(100),
      contact_phone   varchar2(100),
      contact_email   varchar2(250)
    );

  /*-- procedure to check event type
  procedure checkEvent (itemtype in varchar2,
                          itemkey in varchar2,
                          actid in number,
                          funcmode in varchar2,
                          resultout out nocopy varchar2);

  -- procedure to check task precondition
  -- before generating reminder notification
  procedure check_again (itemtype in varchar2,
                          itemkey in varchar2,
                          actid in number,
                          funcmode in varchar2,
                          resultout out nocopy varchar2);

  -- check CSF: Alert Auto Reject profile is set or not
  procedure check_auto_reject (itemtype in varchar2,
                          itemkey in varchar2,
                          actid in number,
                          funcmode in varchar2,
                          resultout out nocopy varchar2);

  -- Procedure to change task assignment status to default Accepted profile
  procedure accept_assgn (itemtype in varchar2,
                          itemkey in varchar2,
                          actid in number,
                          funcmode in varchar2,
                          resultout out nocopy varchar2);

  -- Procedure to change task assignment status to default Rejected profile
  procedure cancel_assgn (itemtype in varchar2,
                          itemkey in varchar2,
                          actid in number,
                          funcmode in varchar2,
                          resultout out nocopy varchar2);

  -- subscription function for oracle.apps.csf.alerts.sendNotification event
  function sendNotification (p_subscription_guid in raw,
                             p_event in out nocopy WF_EVENT_T) return varchar2;

  -- generates Send Date for CSF event based on profile values
  function getSendDate (p_resource_id number,
                        p_resource_type_code varchar2,
                        p_scheduled_start_date date,
                        p_scheduled_end_date date) return date;
  */
  -- Returns user_id for a given ersource
  function getUserId (p_resource_id number,
                      p_resource_type varchar2) return number;
  /*
  -- Returns user_name for a given resource
  function getUserName (p_resource_id number,
                      p_resource_type varchar2) return varchar2;
  */
  -- Returns Category type for resource type
  function category_type ( p_rs_category varchar2 ) return varchar2;
  /*
  -- Generated item_key for workflow
  function getItemKey (p_event_type varchar2,
                      p_resource_id number,
                      p_resource_type_code varchar2,
                      p_task_assignment_id varchar2,
                      p_old_event_id varchar2) return varchar2;

  -- Check profile for a given resource
  function checkAlertsEnabled(p_resource_id number,
                                p_resource_type_code varchar2) return boolean;
  */
  -- Generates Assigned notification content
  procedure getAssignedMessage(document_id varchar2,
                              display_type varchar2,
                              document in out nocopy varchar2,
                              document_type in out nocopy varchar2);
  /*
  -- Generates Reminder notification content
  procedure getReminderMessage(document_id varchar2,
                              display_type varchar2,
                              document in out nocopy varchar2,
                              document_type in out nocopy varchar2);

  -- Generates Cancelled notification content
  procedure getDeleteMessage(document_id varchar2,
                              display_type varchar2,
                              document in out nocopy varchar2,
                              document_type in out nocopy varchar2);

  -- Generates Rescheduled notification content
  procedure getRescheduleMessage(document_id varchar2,
                              display_type varchar2,
                              document in out nocopy varchar2,
                              document_type in out nocopy varchar2);
  */
  -- Returns contact details for SR
  function getContactDetail(p_incident_id number,
                              p_contact_type varchar2,
                              p_party_id number) return contact_record;

  --------------------------------------------------------------------
  --  customization code: CUST457 - CSF Task Assignment WF modification
  --  name:               getTaskDetails
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      21/09/2011
  --  Purpose :           correct oracle bug
  --                      at the condition
  --                      and msi_b.organization_id (+) = c_b.inv_organization_id--c_b.org_id
  --                      oracle compare organization id to org_id (OU)
  --                      the correction is to compare organization_id to inv_organization_id
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/04/2011    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  -- Returns all the required task details to generate notification content
  function getTaskDetails(p_task_id number,
                              p_task_asgn_id number,
                              p_task_audit_id number) return task_asgn_record;
  /*
  -- Subscription function for task assignemnt events
  function checkForAlerts (p_subscription_guid in raw,
                             p_event in out nocopy WF_EVENT_T) return varchar2;
  */
  -- Returns date in client timezone
  function getClientTime (p_server_time date, p_user_id number) return date;

  -- Returns translated prompt
  function getPrompt (p_name varchar2) return varchar2;
  /*
  -- Returns WF ROLE NAME
  function getWFRole (p_resource_id number) return varchar2;
  */

  --------------------------------------------------------------------
  --  customization code: CUST457 - CSF Task Assignment WF modification
  --  name:               getSubject
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      13/02/2012
  --  Purpose :           change notification subject
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/02/2012    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  procedure getSubject(document_id   varchar2,
                       display_type  varchar2,
                       document      in out nocopy varchar2,
                       document_type in out nocopy varchar2);
END XXcsf_alerts_pub;
/
