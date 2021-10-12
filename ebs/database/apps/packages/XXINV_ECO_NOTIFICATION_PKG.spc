CREATE OR REPLACE PACKAGE "XXINV_ECO_NOTIFICATION_PKG" is
  --  1) XXINV_ECO_SYNC_DATA/XXINV: Eco Sync Agile Data
  --  2) Add to report DB Name
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------

  C_SYNC_DATA_LAST_RUN_PRF CONSTANT VARCHAR2(240) := 'XXINV_ECO_SYNC_DATA_LAST_RUN';
  C_DATE_TIME_FORMAT       CONSTANT VARCHAR2(240) := 'DD-MON-RRRR HH24:MI:SS';
  C_NEW                    CONSTANT VARCHAR2(240) := 'NEW';
  C_SUCCESS_INT            CONSTANT VARCHAR2(240) := 'SUCCESS_INT';
  C_SUCCESS_EXT            CONSTANT VARCHAR2(240) := 'SUCCESS_EXT';
  C_SUCCESS_COMP           CONSTANT VARCHAR2(240) := 'SUCCESS_COMP';
  C_ERROR                  CONSTANT VARCHAR2(240) := 'ERROR';

  C_ERROR_NO_EMAIL   CONSTANT VARCHAR2(240) := 'ERROR : No email to contact';
  C_ERROR_NO_CONTACT CONSTANT VARCHAR2(240) := 'ERROR : No contact to account';
  C_ERROR_HEADER     CONSTANT VARCHAR2(240) := 'ERROR : No contact to account or contact without email';

  C_XXINV_ECO_NOTIF_DIRECTORY CONSTANT VARCHAR2(240) := 'XXINV_ECO_NOTIF_DIRECTORY';

  -------- Attachment Entity ----------
  C_ENTITY_XXINV_ECO_HEADER CONSTANT VARCHAR2(240) := 'XXINV_ECO_HEADER';
  C_ENTITY_XXINV_ECO_LINES  CONSTANT VARCHAR2(240) := 'XXINV_ECO_LINES';
  --  C_ENTITY_XXINV_ECO_LINES  CONSTANT VARCHAR2(240) := 'XXINV_ECO_LINES';
  ------- Attachment Category ---------
  C_CATEGORY_XXINV_ECO_HEADER CONSTANT VARCHAR2(240) := 'XXINV ECO Notifications';

  C_REVISION   CONSTANT VARCHAR2(300) := 'REVISION';
  C_SUBSTITUTE CONSTANT VARCHAR2(300) := 'SUBSTITUTE';

  P_EMAIL_ADDRESS VARCHAR2(250);
  P_EMAIL_FLAG    VARCHAR2(1);
  P_FILENAME      VARCHAR2(250);
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  PROCEDURE message(p_msg IN VARCHAR2);

  ----------------------------------------------------------------------
  -- Ver   When         Who       Descr
  -- ----  -----------  --------  --------------------------------------
  -- 1.0   15/10/2020  Roman W.   CHG0048470 - Change notification to customers
  -------------------------------------------------------------------------
  procedure remove_file(p_directory  in varchar2,
                        p_file_name  in varchar2,
                        p_error_code out varchar2,
                        p_error_desc out varchar2);

  -------------------------------------------------------------------------------------
  -- Ver   When          Who              Description
  -- ----  ------------  ---------------  ---------------------------------------------
  -- 1.0   16/11/2020    Roman W.         CHG0048470 - Change notification to customers
  -------------------------------------------------------------------------------------
  function get_email_subject(p_str VARCHAR2) return varchar2;

  -------------------------------------------------------------------------------------
  -- Ver   When          Who              Description
  -- ----  ------------  ---------------  ---------------------------------------------
  -- 1.0   11/11/2020    Roman W.         CHG0048470 - Change notification to customers
  -------------------------------------------------------------------------------------
  procedure update_header_mail_status(p_eco_header_id IN NUMBER,
                                      p_mail_status   IN VARCHAR2,
                                      p_note          IN VARCHAR2,
                                      p_email_sent_to IN VARCHAR2 DEFAULT NULL,
                                      p_error_code    OUT VARCHAR2,
                                      p_error_desc    OUT VARCHAR2);
  -------------------------------------------------------------------------------------
  -- Ver   When          Who              Description
  -- ----  ------------  ---------------  ---------------------------------------------
  -- 1.0   11/11/2020    Roman W.         CHG0048470 - Change notification to customers
  -------------------------------------------------------------------------------------
  procedure update_line_mail_status(p_eco_line_id IN NUMBER,
                                    p_mail_status IN VARCHAR2,
                                    p_note        IN VARCHAR2,
                                    p_error_code  OUT VARCHAR2,
                                    p_error_desc  OUT VARCHAR2);
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   29/09/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure set_profile_value(pv_profile_name IN VARCHAR2 default C_SYNC_DATA_LAST_RUN_PRF,
                              pv_value        IN VARCHAR2,
                              pv_error_code   OUT VARCHAR2,
                              pv_error_desc   OUT VARCHAR2);

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   14/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  function get_notification_int_email(p_eco VARCHAR2) return varchar2;

  ------------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   27/10/2020   Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  PROCEDURE set_account_contact(p_eco_header_id     IN NUMBER,
                                p_eco_line_id       IN NUMBER,
                                p_inventory_item_id IN NUMBER,
                                p_cust_account_id   IN NUMBER,
                                p_error_code        OUT VARCHAR2,
                                p_error_desc        OUT VARCHAR2);

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   15/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  function get_bursting_pdf_location return varchar2;

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   01/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure insert_item_customer(p_row         IN XXINV_ECO_LINE_CUSTOMERS%ROWTYPE,
                                 pv_error_code OUT VARCHAR2,
                                 pv_error_desc OUT VARCHAR2);
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   01/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure insert_line(p_xxinv_eco_lines IN OUT XXINV_ECO_LINES%ROWTYPE,
                        pv_error_code     OUT VARCHAR2,
                        pv_error_desc     OUT VARCHAR2);

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   01/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure insert_header(p_xxinv_eco_header_row IN OUT XXINV_ECO_HEADER%ROWTYPE,
                          pv_error_code          OUT VARCHAR2,
                          pv_error_desc          OUT VARCHAR2);

  --------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  ----------------------------------------------
  -- 1.0   14/10/2020   Roman W.    CHG0048470 - Change notification to customers
  --------------------------------------------------------------------------------
  procedure submit_bursting(p_conc_request_id IN NUMBER,
                            p_error_code      OUT VARCHAR2,
                            p_error_desc      OUT VARCHAR2);

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure sync_data(errbuf           OUT VARCHAR2,
                      retcode          OUT VARCHAR2,
                      p_sync_from_date IN VARCHAR2 -- DD-MON-RRRR HH24:MI:SS
                      );

  ------------------------------------------------------------------------------
  -- Concurrent : XXINV_ECO_NOTIF_INT / XXINV: Eco Notification Internal
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure notification_int(errbuf         OUT VARCHAR2,
                             retcode        OUT VARCHAR2,
                             p_date         IN VARCHAR2, -- DD-MON-RRRR HH24:MI:SS
                             p_pdf_location IN VARCHAR2);

  ------------------------------------------------------------------------------
  -- Concurrent : XXINV_ECO_NOTIF_EXT / XXINV: Eco Notification External
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure notification_ext(errbuf  OUT VARCHAR2,
                             retcode OUT VARCHAR2,
                             p_date  IN VARCHAR2 -- DD-MON-RRRR HH24:MI:SS
                             );

  ------------------------------------------------------------------------------
  -- Concurrent : XXINV_ECO_NOTIF_COMP / XXINV: Eco Completion Notification
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure notification_completion(errbuf  OUT VARCHAR2,
                                    retcode OUT VARCHAR2,
                                    p_date  IN VARCHAR2 -- dd-mon-rrrr hh24:mi:ss
                                    );

end XXINV_ECO_NOTIFICATION_PKG;
/
