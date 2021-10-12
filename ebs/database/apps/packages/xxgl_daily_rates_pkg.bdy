CREATE OR REPLACE PACKAGE BODY xxgl_daily_rates_pkg IS
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build
  --     1.1  18/02/13  yuval tal       remove proc load_hist_gl_rates
  ---------------------------------------------------------------------------
  PROCEDURE daily_rates(p_from_currency        IN VARCHAR2,
                        p_to_currency          IN VARCHAR2,
                        p_from_conversion_date IN VARCHAR2,
                        p_to_conversion_date   IN VARCHAR2,
                        p_user_conversion_type IN VARCHAR2,
                        p_conversion_rate      IN NUMBER,
                        p_mode_flag            IN VARCHAR2,
                        p_error                OUT VARCHAR2) IS
    v_exist      NUMBER;
    v_request_id NUMBER;
    v_enabled    VARCHAR2(1);
    l_mode_flag  VARCHAR2(1) := p_mode_flag;
  
  BEGIN
    p_error := NULL;
  
    -- Validate that currencies are enabled
    BEGIN
      SELECT curr.enabled_flag
        INTO v_enabled
        FROM fnd_currencies curr
       WHERE curr.currency_code = p_from_currency;
    EXCEPTION
      WHEN OTHERS THEN
        v_enabled := 'Y'; -- do nothing
    END;
    IF nvl(v_enabled, 'X') = 'X' THEN
      UPDATE fnd_currencies curr
         SET curr.enabled_flag = 'Y'
       WHERE curr.currency_code = p_from_currency;
      COMMIT;
    END IF;
    v_enabled := '';
    BEGIN
      SELECT curr.enabled_flag
        INTO v_enabled
        FROM fnd_currencies curr
       WHERE curr.currency_code = p_to_currency;
    EXCEPTION
      WHEN OTHERS THEN
        v_enabled := 'Y'; -- do nothing
    END;
    IF nvl(v_enabled, 'X') = 'X' THEN
      UPDATE fnd_currencies curr
         SET curr.enabled_flag = 'Y'
       WHERE curr.currency_code = p_to_currency;
      COMMIT;
    END IF;
  
    v_exist := 0;
  
    BEGIN
      SELECT 1
        INTO v_exist
        FROM gl_daily_rates_interface p
       WHERE p.from_currency = p_from_currency
         AND p.to_currency = p_to_currency
         AND trunc(p.from_conversion_date) =
             trunc(to_date(p_from_conversion_date, 'DD/MM/YYYY'))
         AND p.user_conversion_type = p_user_conversion_type;
    
      RETURN;
    EXCEPTION
      WHEN OTHERS THEN
        v_exist := 0;
    END;
  
    BEGIN
      SELECT 1
        INTO v_exist
        FROM gl_daily_rates gdr
       WHERE gdr.from_currency = p_from_currency
         AND gdr.to_currency = p_to_currency
         AND trunc(gdr.conversion_date) BETWEEN
             trunc(to_date(p_from_conversion_date, 'DD/MM/YYYY')) AND
             trunc(to_date(p_to_conversion_date, 'DD/MM/YYYY'))
         AND gdr.conversion_type = p_user_conversion_type
         AND rownum < 1;
    
      l_mode_flag := 'U';
    
      RETURN;
    EXCEPTION
      WHEN OTHERS THEN
        v_exist := 0;
    END;
  
    IF v_exist = 0 THEN
      INSERT INTO gl_daily_rates_interface
        (from_currency,
         to_currency,
         from_conversion_date,
         to_conversion_date,
         user_conversion_type,
         conversion_rate,
         mode_flag)
      VALUES
        (p_from_currency,
         p_to_currency,
         to_date(p_from_conversion_date, 'DD/MM/YYYY'),
         to_date(p_to_conversion_date, 'DD/MM/YYYY'),
         p_user_conversion_type,
         p_conversion_rate,
         l_mode_flag);
    
      COMMIT;
    
    END IF;
  
  END daily_rates;

  PROCEDURE call_request(errbuf  OUT VARCHAR2,
                         retcode OUT NUMBER,
                         p_error OUT VARCHAR2) IS
    v_exist         NUMBER;
    v_request_id    NUMBER;
    v_printer       VARCHAR2(30);
    b_print_options BOOLEAN;
  
    -- Shai 17.11.08 - begin
    l_ret_val           BOOLEAN;
    l_phase             VARCHAR2(100);
    l_status            VARCHAR2(100);
    l_dev_phase         VARCHAR2(100);
    l_dev_status        VARCHAR2(100);
    l_message           VARCHAR2(500);
    j                   NUMBER := 0;
    l_user_id           NUMBER;
    l_responsibility_id NUMBER;
    l_application_id    NUMBER;
    -- Shai 17.11.08 - End
  BEGIN
  
    SELECT user_id
      INTO l_user_id
      FROM fnd_user
     WHERE user_name = 'SCHEDULER';
  
    SELECT t.responsibility_id, t.application_id
      INTO l_responsibility_id, l_application_id
      FROM fnd_responsibility_vl t
     WHERE t.responsibility_key = 'XXGL_SUPER_USER_IL';
  
    fnd_global.apps_initialize(l_user_id,
                               l_responsibility_id,
                               l_application_id);
  
    -- fnd_profile.get(NAME => 'PRINTER', val => v_printer);
  
    -- b_print_options := fnd_request.set_print_options(printer        => v_printer,
    --                                                  style          => NULL,
    --                                                  copies         => 0,
    --                                                  save_output    => TRUE,
    --                                                 print_together => NULL);
  
    v_request_id := fnd_request.submit_request(application => 'SQLGL',
                                               program     => 'GLDRICCP',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE);
  
    IF v_request_id = 0 THEN
      p_error := ' The Cncurrent: Program - Daily Rates Import and Calculation, Got Error.';
    END IF;
  
    COMMIT;
  
    -- Shai 17.11.08 - begin
    -- Wait for the concurrent to complete
  
    -- WHILE nvl(l_dev_phase, 'zzz') != 'COMPLETE' LOOP
    l_ret_val := fnd_concurrent.wait_for_request(request_id => v_request_id,
                                                 INTERVAL   => 10,
                                                 phase      => l_phase,
                                                 status     => l_status,
                                                 dev_phase  => l_dev_phase,
                                                 dev_status => l_dev_status,
                                                 message    => l_message);
    --  IF l_dev_phase = 'PENDING' THEN
    -- Not Yet Started
    --     j := 0;
    -- ELSIF l_dev_phase = 'COMPLETE' THEN
    --Done.
    --     EXIT;
    --  ELSIF j > 5 THEN
    --Waited for over 3 minute of running
    --   p_error := ' Concurrent was not completed running';
    --   RETURN;
    -- END IF;
    -- j := j + 1;
    -- END LOOP;
  
    IF l_dev_phase = 'COMPLETE' THEN
      IF l_dev_status = 'NORMAL' THEN
        --Completed succsessfuly
        RETURN;
      ELSE
        p_error := 'Concurrent was completed with status ' || l_dev_status ||
                   ' - ' || l_message;
        RETURN;
      END IF;
    END IF;
    -- Shai 17.11.08 - End
  
  END call_request;

END xxgl_daily_rates_pkg;
/
