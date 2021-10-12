CREATE OR REPLACE PACKAGE xxau_utils_pkg IS

   PROCEDURE submit_request(p_conc_appl_short_name VARCHAR2,
                            p_conc_program_name    VARCHAR2,
                            p_temp_appl_short_name VARCHAR2 DEFAULT NULL,
                            p_template_name        VARCHAR2 DEFAULT NULL,
                            p_template_language    VARCHAR2 DEFAULT NULL,
                            p_template_territory   VARCHAR2 DEFAULT NULL,
                            l_template_output_type VARCHAR2 DEFAULT NULL,
                            p_printer_name         VARCHAR2 DEFAULT NULL,
                            p_num_of_copies        NUMBER DEFAULT NULL,
                            p_description          VARCHAR2 DEFAULT NULL,
                            p_wait_for_request     VARCHAR2 DEFAULT 'N', -- Y/N
                            p_argument1            VARCHAR2 DEFAULT NULL,
                            p_argument2            VARCHAR2 DEFAULT NULL,
                            p_argument3            VARCHAR2 DEFAULT NULL,
                            p_argument4            VARCHAR2 DEFAULT NULL,
                            p_argument5            VARCHAR2 DEFAULT NULL,
                            p_argument6            VARCHAR2 DEFAULT NULL,
                            p_argument7            VARCHAR2 DEFAULT NULL,
                            p_argument8            VARCHAR2 DEFAULT NULL,
                            p_argument9            VARCHAR2 DEFAULT NULL,
                            p_argument10           VARCHAR2 DEFAULT NULL,
                            p_argument11           VARCHAR2 DEFAULT NULL,
                            p_argument12           VARCHAR2 DEFAULT NULL,
                            p_argument13           VARCHAR2 DEFAULT NULL,
                            p_argument14           VARCHAR2 DEFAULT NULL,
                            p_argument15           VARCHAR2 DEFAULT NULL,
                            p_argument16           VARCHAR2 DEFAULT NULL,
                            p_argument17           VARCHAR2 DEFAULT NULL,
                            p_argument18           VARCHAR2 DEFAULT NULL,
                            p_argument19           VARCHAR2 DEFAULT NULL,
                            p_argument20           VARCHAR2 DEFAULT NULL,
                            x_err_msg              OUT VARCHAR2);
END xxau_utils_pkg;
/

