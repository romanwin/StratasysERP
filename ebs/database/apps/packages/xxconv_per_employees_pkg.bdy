CREATE OR REPLACE PACKAGE BODY xxconv_per_employees_pkg IS

   PROCEDURE load_employee IS
   
      CURSOR load_emp IS
         SELECT *
           FROM xxobjt_conv_emp e
          WHERE e.error_code_flag = 'N'
          ORDER BY emp_rank;
   
      x_emp_num                      VARCHAR2(200) /* := '90909090'*/
      ;
      l_business_group_id            NUMBER;
      l_person_type_id               NUMBER;
      x_validate_mode                BOOLEAN := FALSE;
      x_person_id                    NUMBER;
      x_assignment_id                NUMBER;
      x_per_object_version_number    NUMBER;
      x_asg_object_version_number    NUMBER;
      x_effective_start_date         DATE;
      x_effective_end_date           DATE;
      x_per_effective_start_date     DATE;
      x_per_effective_end_date       DATE;
      x_full_name                    VARCHAR2(240);
      x_per_comment_id               NUMBER;
      x_assignment_sequence          NUMBER;
      x_assignment_number            VARCHAR2(30);
      x_name_combination_warning     BOOLEAN := FALSE;
      x_assign_payroll_warning       BOOLEAN := FALSE;
      x_orig_hire_warning            BOOLEAN := FALSE;
      l_return_status                VARCHAR2(1);
      l_people_group_id              NUMBER := 61;
      x_object_version_number        NUMBER;
      x_special_ceiling_step_id      NUMBER;
      x_group_name                   VARCHAR2(240);
      x_org_now_no_manager_warning   BOOLEAN;
      x_other_manager_warning        BOOLEAN;
      x_no_manag_warn                BOOLEAN;
      x_spp_delete_warning           BOOLEAN;
      x_entries_changed_warning      VARCHAR2(2);
      x_tax_district_changed_warning BOOLEAN;
      x_soft_coding_key              NUMBER;
      x_comment_id                   NUMBER;
      x_con_segs                     VARCHAR2(100);
      l_coa_id                       NUMBER;
      v_error                        VARCHAR2(2000);
      v_error_ass                    VARCHAR2(2000);
   
      l_concatenated_segments  VARCHAR2(80);
      l_soft_coding_keyflex_id NUMBER;
      l_comment_id             NUMBER;
      l_pos_id                 NUMBER;
      l_job_id                 NUMBER;
      l_loc_id                 NUMBER;
      l_organization_id        NUMBER;
      l_ass_supervisor         NUMBER;
      l_ledger_id              NUMBER;
      l_comb_id                NUMBER;
   
      v_check   NUMBER;
      l_stage   VARCHAR2(500);
      l_user_id NUMBER;
   
      invalid_employee EXCEPTION;
   
      l_action_date             DATE;
      l_supervisor_ass_eff_date DATE;
      l_action_type             VARCHAR2(20);
   
   BEGIN
   
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      fnd_global.apps_initialize(user_id      => l_user_id,
                                 resp_id      => 21514,
                                 resp_appl_id => 800);
      FOR emp_rec IN load_emp LOOP
      
         BEGIN
            x_validate_mode             := NULL;
            l_business_group_id         := NULL;
            l_person_type_id            := NULL;
            x_emp_num                   := NULL;
            x_person_id                 := NULL;
            x_assignment_id             := NULL;
            x_per_object_version_number := NULL;
            x_asg_object_version_number := NULL;
            x_per_effective_start_date  := NULL;
            x_per_effective_end_date    := NULL;
            x_full_name                 := NULL;
            x_per_comment_id            := NULL;
            x_assignment_sequence       := NULL;
            x_assignment_number         := NULL;
            x_name_combination_warning  := NULL;
            x_assign_payroll_warning    := NULL;
            x_orig_hire_warning         := NULL;
         
            l_pos_id                       := NULL;
            l_job_id                       := NULL;
            l_loc_id                       := NULL;
            l_organization_id              := NULL;
            l_people_group_id              := NULL;
            x_object_version_number        := NULL;
            x_special_ceiling_step_id      := NULL;
            x_group_name                   := NULL;
            x_effective_start_date         := NULL;
            x_effective_end_date           := NULL;
            x_org_now_no_manager_warning   := NULL;
            x_other_manager_warning        := NULL;
            x_spp_delete_warning           := NULL;
            x_entries_changed_warning      := NULL;
            x_tax_district_changed_warning := NULL;
         
            l_coa_id                := NULL;
            x_assignment_id         := NULL;
            l_ass_supervisor        := NULL;
            l_ledger_id             := NULL;
            l_comb_id               := NULL;
            x_con_segs              := NULL;
            x_soft_coding_key       := NULL;
            x_comment_id            := NULL;
            x_no_manag_warn         := NULL;
            x_other_manager_warning := NULL;
         
            l_stage := 'Business Group';
         
            BEGIN
               SELECT business_group_id
                 INTO l_business_group_id
                 FROM per_business_groups;
            EXCEPTION
               WHEN too_many_rows THEN
                  SELECT business_group_id
                    INTO l_business_group_id
                    FROM per_business_groups
                   WHERE NAME = 'Objet Main Business Group';
            END;
         
            l_stage := 'Person Type';
         
            SELECT ppt.person_type_id
              INTO l_person_type_id
              FROM per_person_types ppt
             WHERE ppt.business_group_id = l_business_group_id AND
                   ppt.user_person_type = emp_rec.person_type;
         
            SELECT COUNT(1)
              INTO v_check
              FROM per_all_people_f pap
             WHERE pap.national_identifier = emp_rec.empsocial_security;
         
            IF v_check = 0 THEN
            
               l_stage := 'create_employee';
            
               SELECT nvl(emp_rec.employee_id,
                          xxobjt_per_employees_numbers_s.NEXTVAL)
                 INTO x_emp_num
                 FROM dual;
            
               hr_employee_api.create_employee(p_validate                  => x_validate_mode,
                                               p_hire_date                 => nvl(to_date(emp_rec.effective_start_date),
                                                                                  SYSDATE), -- In this case
                                               p_business_group_id         => l_business_group_id,
                                               p_last_name                 => emp_rec.last_name,
                                               p_sex                       => substr(emp_rec.gender,
                                                                                     1,
                                                                                     1),
                                               p_person_type_id            => l_person_type_id,
                                               p_date_of_birth             => emp_rec.date_of_birth, --'12-JAN-1982',
                                               p_email_address             => emp_rec.email_address,
                                               p_employee_number           => x_emp_num,
                                               p_first_name                => emp_rec.first_name,
                                               p_national_identifier       => emp_rec.empsocial_security,
                                               p_title                     => upper(emp_rec.title),
                                               p_office_number             => emp_rec.office_number,
                                               p_resume_exists             => emp_rec.resume_flag,
                                               p_person_id                 => x_person_id,
                                               p_assignment_id             => x_assignment_id,
                                               p_per_object_version_number => x_per_object_version_number,
                                               p_asg_object_version_number => x_asg_object_version_number,
                                               p_per_effective_start_date  => x_per_effective_start_date,
                                               p_per_effective_end_date    => x_per_effective_end_date,
                                               p_full_name                 => x_full_name,
                                               p_per_comment_id            => x_per_comment_id,
                                               p_assignment_sequence       => x_assignment_sequence,
                                               p_assignment_number         => x_assignment_number,
                                               p_name_combination_warning  => x_name_combination_warning,
                                               p_assign_payroll_warning    => x_assign_payroll_warning,
                                               p_orig_hire_warning         => x_orig_hire_warning);
            
            ELSE
            
               UPDATE xxobjt_conv_emp em
                  SET em.error_code_flag = 'W',
                      em.error_message   = 'Employee already exist'
                WHERE em.first_name = emp_rec.first_name AND
                      em.last_name = emp_rec.last_name AND
                      empsocial_security = emp_rec.empsocial_security;
            
            END IF;
         
            l_stage := 'assignment';
         
            BEGIN
            
               SELECT a.assignment_id, a.object_version_number
                 INTO x_assignment_id, x_object_version_number
                 FROM per_all_people_f p, per_all_assignments_f a
                WHERE p.person_id = a.person_id AND
                      p.national_identifier = emp_rec.empsocial_security AND
                      p.current_employee_flag = 'Y' AND
                      SYSDATE BETWEEN p.effective_start_date AND
                      p.effective_end_date AND
                      SYSDATE BETWEEN a.effective_start_date AND
                      a.effective_end_date;
            
            EXCEPTION
               WHEN no_data_found THEN
               
                  SELECT a.assignment_id, a.object_version_number
                    INTO x_assignment_id, x_object_version_number
                    FROM per_all_people_f p, per_all_assignments_f a
                   WHERE p.person_id = a.person_id AND
                         p.national_identifier = emp_rec.empsocial_security;
            END;
         
            l_stage := 'position';
         
            BEGIN
            
               SELECT pap.position_id, pap.job_id /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       pap.location_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       pap.organization_id*/
                 INTO l_pos_id, l_job_id /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       l_loc_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       l_organization_id*/
                 FROM per_all_positions pap
                WHERE pap.NAME = ltrim(rtrim(emp_rec.position));
            EXCEPTION
               WHEN OTHERS THEN
                  l_pos_id := NULL;
                  l_job_id := NULL;
                  v_error  := 'invalid position: ' || emp_rec.position;
                  RAISE invalid_employee;
            END;
         
            l_stage := 'organization';
         
            BEGIN
               SELECT a.organization_id
                 INTO l_organization_id
                 FROM hr_all_organization_units a
                WHERE a.NAME = emp_rec.organization;
            EXCEPTION
               WHEN OTHERS THEN
                  l_organization_id := NULL;
                  v_error           := 'invalid organization: ' ||
                                       emp_rec.organization;
                  RAISE invalid_employee;
            END;
         
            l_stage := 'supervisor';
            IF emp_rec.supervisor IS NOT NULL THEN
            
               BEGIN
                  SELECT pap.person_id, pap.effective_start_date
                    INTO l_ass_supervisor, l_supervisor_ass_eff_date
                    FROM per_all_people_f pap
                   WHERE pap.full_name = emp_rec.supervisor;
               EXCEPTION
                  WHEN OTHERS THEN
                     l_ass_supervisor := NULL;
                     v_error          := 'invalid supervisor: ' ||
                                         emp_rec.supervisor;
                     RAISE invalid_employee;
               END;
            ELSE
               l_ass_supervisor := NULL;
            END IF;
         
            l_stage := 'location';
         
            BEGIN
               SELECT hl.location_id
                 INTO l_loc_id
                 FROM hr_locations hl
                WHERE hl.location_code = emp_rec.internal_location;
            EXCEPTION
               WHEN OTHERS THEN
                  l_loc_id := NULL;
                  v_error  := 'invalid location: ' ||
                              emp_rec.internal_location;
                  RAISE invalid_employee;
            END;
         
            l_stage := 'update_emp_asg_criteria';
         
            l_action_date := emp_rec.effective_start_date;
         
            IF nvl(l_supervisor_ass_eff_date, l_action_date) >
               l_action_date THEN
               l_action_date := l_supervisor_ass_eff_date;
            END IF;
         
            IF l_action_date > emp_rec.effective_start_date THEN
               l_action_type := 'UPDATE';
            ELSE
            
               l_action_date := emp_rec.effective_start_date;
               l_action_type := 'CORRECTION';
            END IF;
         
            hr_assignment_api.update_emp_asg_criteria(p_effective_date               => l_action_date,
                                                      p_datetrack_update_mode        => l_action_type,
                                                      p_assignment_id                => x_assignment_id,
                                                      p_position_id                  => l_pos_id,
                                                      p_job_id                       => l_job_id,
                                                      p_location_id                  => l_loc_id,
                                                      p_organization_id              => l_organization_id,
                                                      p_people_group_id              => l_people_group_id,
                                                      p_object_version_number        => x_object_version_number,
                                                      p_special_ceiling_step_id      => x_special_ceiling_step_id,
                                                      p_group_name                   => x_group_name,
                                                      p_effective_start_date         => x_effective_start_date,
                                                      p_effective_end_date           => x_effective_end_date,
                                                      p_org_now_no_manager_warning   => x_org_now_no_manager_warning,
                                                      p_other_manager_warning        => x_other_manager_warning,
                                                      p_spp_delete_warning           => x_spp_delete_warning,
                                                      p_entries_changed_warning      => x_entries_changed_warning,
                                                      p_tax_district_changed_warning => x_tax_district_changed_warning);
         
            l_stage := 'ledger';
         
            BEGIN
               SELECT l.ledger_id, chart_of_accounts_id
                 INTO l_ledger_id, l_coa_id
                 FROM gl_ledgers l
                WHERE l.NAME = emp_rec.ledger;
            EXCEPTION
               WHEN OTHERS THEN
                  l_ledger_id := NULL;
                  v_error     := 'invalid ledger: ' || emp_rec.ledger;
                  RAISE invalid_employee;
            END;
         
            l_stage := 'Expense account';
         
            BEGIN
            
               SELECT gcc.code_combination_id
                 INTO l_comb_id
                 FROM gl_code_combinations_kfv gcc
                WHERE gcc.concatenated_segments = emp_rec.expense_account;
            
            EXCEPTION
               WHEN OTHERS THEN
               
                  l_stage := 'get and create account';
                  xxgl_utils_pkg.get_and_create_account(p_concat_segment      => emp_rec.expense_account,
                                                        p_coa_id              => l_coa_id,
                                                        x_code_combination_id => l_comb_id,
                                                        x_return_code         => l_return_status,
                                                        x_err_msg             => v_error_ass);
               
                  IF l_return_status != 'S' THEN
                     v_error := v_error_ass;
                     RAISE invalid_employee;
                  
                  END IF;
               
            END;
         
            l_stage := 'update_emp_asg';
         
            hr_assignment_api.update_emp_asg(p_effective_date         => l_action_date,
                                             p_datetrack_update_mode  => 'CORRECTION',
                                             p_assignment_id          => x_assignment_id,
                                             p_object_version_number  => x_object_version_number,
                                             p_supervisor_id          => l_ass_supervisor,
                                             p_set_of_books_id        => l_ledger_id,
                                             p_default_code_comb_id   => l_comb_id,
                                             p_concatenated_segments  => x_con_segs,
                                             p_soft_coding_keyflex_id => x_soft_coding_key,
                                             p_comment_id             => x_comment_id,
                                             p_effective_start_date   => x_effective_start_date,
                                             p_effective_end_date     => x_effective_end_date,
                                             p_no_managers_warning    => x_no_manag_warn,
                                             p_other_manager_warning  => x_other_manager_warning);
         
            UPDATE xxobjt_conv_emp em
               SET em.error_code_flag = 'Y', em.error_message = NULL
             WHERE em.first_name = emp_rec.first_name AND
                   em.last_name = emp_rec.last_name AND
                   empsocial_security = emp_rec.empsocial_security;
         
            COMMIT;
         
         EXCEPTION
            WHEN invalid_employee THEN
               UPDATE xxobjt_conv_emp em
                  SET em.error_code_flag = 'E', em.error_message = v_error
                WHERE em.first_name = emp_rec.first_name AND
                      em.last_name = emp_rec.last_name AND
                      empsocial_security = emp_rec.empsocial_security;
            
            WHEN OTHERS THEN
               v_error := SQLERRM;
               UPDATE xxobjt_conv_emp em
                  SET em.error_code_flag = 'E',
                      em.error_message   = l_stage || ': ' || v_error
                WHERE em.first_name = emp_rec.first_name AND
                      em.last_name = emp_rec.last_name AND
                      empsocial_security = emp_rec.empsocial_security;
         END;
      
      END LOOP;
   
      COMMIT;
   
   END load_employee;

   PROCEDURE create_user IS
   
      CURSOR csr_users IS
         SELECT * FROM xxobjt_conv_fnd_users WHERE return_status = 'N';
   
      cur_user csr_users%ROWTYPE;
   
      invalid_user EXCEPTION;
      l_user_id        NUMBER;
      v_error          VARCHAR2(500);
      l_employee_name  VARCHAR2(80);
      l_employee_id    NUMBER;
      l_employee_email VARCHAR2(80);
   
   BEGIN
   
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
   
      FOR cur_user IN csr_users LOOP
      
         l_employee_id    := NULL;
         l_employee_name  := NULL;
         l_employee_email := NULL;
      
         BEGIN
         
            IF cur_user.is_employee = 'Y' THEN
               SELECT p.person_id, p.full_name, p.email_address
                 INTO l_employee_id, l_employee_name, l_employee_email
                 FROM per_all_people_f p
                WHERE upper(first_name || '.' || last_name) =
                      upper(cur_user.user_name);
            END IF;
         
            fnd_user_pkg.createuser(x_user_name              => upper(cur_user.user_name),
                                    x_owner                  => 'CONVERSION',
                                    x_unencrypted_password   => 'objet123',
                                    x_start_date             => SYSDATE,
                                    x_description            => l_employee_name,
                                    x_password_lifespan_days => 90,
                                    x_employee_id            => l_employee_id,
                                    x_email_address          => l_employee_email);
         
            UPDATE xxobjt_conv_fnd_users em
               SET em.return_status = 'S', em.error_message = NULL
             WHERE em.user_name = cur_user.user_name;
         
            COMMIT;
         
         EXCEPTION
            WHEN invalid_user THEN
               UPDATE xxobjt_conv_fnd_users em
                  SET em.return_status = 'E', em.error_message = v_error
                WHERE em.user_name = cur_user.user_name;
            
            WHEN OTHERS THEN
               v_error := SQLERRM;
               UPDATE xxobjt_conv_fnd_users em
                  SET em.return_status = 'E', em.error_message = v_error
                WHERE em.user_name = cur_user.user_name;
         END;
      
      END LOOP;
   
      COMMIT;
   END create_user;

END xxconv_per_employees_pkg;
/

