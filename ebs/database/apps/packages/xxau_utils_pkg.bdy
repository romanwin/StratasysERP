CREATE OR REPLACE PACKAGE BODY xxau_utils_pkg IS

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
                            x_err_msg              OUT VARCHAR2) IS
   
      l_default_language    VARCHAR2(20);
      l_default_territory   VARCHAR2(20);
      l_default_output_type VARCHAR2(20);
      l_request_id          NUMBER;
      l_phase               VARCHAR2(20);
      l_status              VARCHAR2(20);
      l_dev_phase           VARCHAR2(20);
      l_dev_status          VARCHAR2(20);
      l_message             VARCHAR2(150);
   
   BEGIN
   
      IF p_template_name IS NOT NULL THEN
         --Create a Layout when running from the Tools Option
         SELECT xt.default_language,
                xt.default_territory,
                nvl(xt.default_output_type, 'PDF')
           INTO l_default_language,
                l_default_territory,
                l_default_output_type
           FROM xdo_templates_b xt
          WHERE xt.application_short_name = p_temp_appl_short_name AND
                xt.template_code = p_template_name;
      
         IF NOT
             fnd_request.add_layout(template_appl_name => p_temp_appl_short_name,
                                    template_code      => p_template_name,
                                    template_language  => nvl(p_template_language,
                                                              l_default_language),
                                    template_territory => nvl(p_template_territory,
                                                              l_default_territory),
                                    output_format      => nvl(l_template_output_type,
                                                              l_default_output_type)) THEN
         
            x_err_msg := 'Error assigning template';
            RETURN;
         
         END IF;
      END IF;
   
      IF p_printer_name IS NOT NULL THEN
      
         IF NOT fnd_request.set_print_options(printer     => p_printer_name,
                                              copies      => p_num_of_copies,
                                              save_output => TRUE) THEN
         
            x_err_msg := 'Error assigning printer';
            RETURN;
         
         END IF;
      
      END IF;
   
      l_request_id := fnd_request.submit_request(application => p_conc_appl_short_name,
                                                 program     => p_conc_program_name,
                                                 description => p_description,
                                                 argument1   => p_argument1,
                                                 argument2   => p_argument2,
                                                 argument3   => p_argument3,
                                                 argument4   => p_argument4,
                                                 argument5   => p_argument5,
                                                 argument6   => p_argument6,
                                                 argument7   => p_argument7,
                                                 argument8   => p_argument8,
                                                 argument9   => p_argument9,
                                                 argument10  => p_argument10,
                                                 argument11  => p_argument11,
                                                 argument12  => p_argument12,
                                                 argument13  => p_argument13,
                                                 argument14  => p_argument14,
                                                 argument15  => p_argument15,
                                                 argument16  => p_argument16,
                                                 argument17  => p_argument17,
                                                 argument18  => p_argument18,
                                                 argument19  => p_argument19,
                                                 argument20  => p_argument20);
   
      COMMIT;
   
      IF l_request_id = 0 THEN
      
         x_err_msg := 'Error submitting request';
         RETURN;
      
      ELSE
      
         x_err_msg := 'Request ' || l_request_id ||
                      ' was submitted successfully';
      
      END IF;
   
      IF p_wait_for_request = 'Y' THEN
      
         IF fnd_concurrent.wait_for_request(request_id => l_request_id,
                                            INTERVAL   => 5,
                                            phase      => l_phase,
                                            status     => l_status,
                                            dev_phase  => l_dev_phase,
                                            dev_status => l_dev_status,
                                            message    => l_message) THEN
         
            NULL;
         
         END IF;
      
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         x_err_msg := 'Error submitting concurrent: ' || SQLERRM;
   END submit_request;

END xxau_utils_pkg;
/

