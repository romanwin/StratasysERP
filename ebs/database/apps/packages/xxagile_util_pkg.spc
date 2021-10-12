CREATE OR REPLACE PACKAGE xxagile_util_pkg IS
   ---------------------------------------------------------------------------
   -- $Header: xxagile_util_pkg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Package: xxagile_util_pkg
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: Agile procedures
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
   FUNCTION get_bpel_domain RETURN VARCHAR2;

   PROCEDURE report_bpel_error(p_bpel_instance_id IN VARCHAR2,
                               p_process_name     IN VARCHAR2,
                               p_error_text       IN VARCHAR2);

   PROCEDURE update_status(p_launcher_instance_id IN VARCHAR2,
                           p_status               IN VARCHAR2);

   PROCEDURE run_common_bill(p_bill_name          IN VARCHAR2,
                             p_org_id             IN NUMBER,
                             p_owner_organization IN VARCHAR2);

   PROCEDURE run_autoimpl_eco_conc(p_eco_name VARCHAR2,
                                   p_org_id   IN NUMBER,
                                   p_type     IN VARCHAR2,
                                   p_user_id  IN NUMBER);

   PROCEDURE log_agile_file(p_directory IN VARCHAR2,
                            p_file_name IN VARCHAR2,
                            p_log_step  IN VARCHAR2);

   PROCEDURE log_file_alert(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

   FUNCTION get_territory(p_territory IN VARCHAR2) RETURN VARCHAR2;

   PROCEDURE process_csv_misc(p_instance_id    IN NUMBER,
                              p_item_file_name IN VARCHAR2,
                              p_aml_file_name  OUT VARCHAR2,
                              p_bom_file_name  OUT VARCHAR2,
                              p_eco_type       OUT VARCHAR2);

   PROCEDURE update_log_table(p_status OUT VARCHAR2);

   PROCEDURE update_error_seq(p_error  IN VARCHAR2 DEFAULT NULL,
                              p_status OUT VARCHAR2);

   PROCEDURE initiate_process(errbuf OUT VARCHAR2, retcode OUT NUMBER);
END xxagile_util_pkg;
/

