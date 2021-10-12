CREATE OR REPLACE PACKAGE xxagile_asl_pkg IS

  ---------------------------------------------------------------------------
  -- $Header: xxagile_file_export_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxagile_asl_pkg
  -- Created: 
  -- Author  : yuval tal
  --------------------------------------------------------------------------
  -- Perpose: create ASL items from agile file 
  -- bpel process named: xxAgileAslInterface listen on agile directory /Agile/Files
  -- file format ASL*.agl
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  20.10.2010                  Initial Build
  ---------------------------------------------------------------------------

  PROCEDURE process_agile_asl_interface(errbuf             OUT VARCHAR2,
                                        retcode            OUT NUMBER,
                                        p_bpel_instance_id NUMBER);

  PROCEDURE handle_asl(p_seq_id      NUMBER,
                       p_err_code    OUT NUMBER,
                       p_err_message OUT VARCHAR2);

  PROCEDURE insert_row(p_item_ind         VARCHAR2,
                       p_item_code        VARCHAR2,
                       p_vendor_name      VARCHAR2,
                       p_asl_status       VARCHAR2,
                       p_api_status       VARCHAR2,
                       p_note             VARCHAR2,
                       p_bpel_instance_id VARCHAR2,
                       p_file_name        VARCHAR2);

END xxagile_asl_pkg;
/

