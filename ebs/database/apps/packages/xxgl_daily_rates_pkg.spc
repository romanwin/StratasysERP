CREATE OR REPLACE PACKAGE xxgl_daily_rates_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxgl_daily_rates_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxgl_daily_rates_pkg
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: Daily rates loading
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
                        p_error                OUT VARCHAR2);

  PROCEDURE call_request(errbuf  OUT VARCHAR2,
                         retcode OUT NUMBER,
                         p_error OUT VARCHAR2);

END xxgl_daily_rates_pkg;
/
