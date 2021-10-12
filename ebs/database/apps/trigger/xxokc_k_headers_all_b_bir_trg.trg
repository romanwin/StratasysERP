CREATE OR REPLACE TRIGGER XXOKC_K_HEADERS_ALL_B_BIR_TRG
   ---------------------------------------------------------------------------
   -- $Header: xxokc_k_headers_all_b_bir_trg 120.0 2009/12/13  $
   ---------------------------------------------------------------------------
   -- Trigger: xxokc_k_headers_all_b_bir_trg
   -- Created: Vitaly
   -- Author  : 13/12/2009
   --------------------------------------------------------------------------
   -- Perpose: update conversion_rate and conversion_rate_date (CS Contracts creation...)
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  13/12/09                  Initial Build
   ---------------------------------------------------------------------------
  BEFORE INSERT ON okc_k_headers_all_b
  FOR EACH ROW
when (NEW.conversion_rate IS NOT NULL)
DECLARE
   v_gl_ledger_currency_code VARCHAR2(100);
   v_conversion_rate         NUMBER;
   ----v_conversion_date          DATE;

BEGIN

   ------Get gl_ledger_currency_code----
   BEGIN
      SELECT glg.currency_code to_currency
        INTO v_gl_ledger_currency_code
        FROM hr_operating_units ou, gl_ledgers glg
       WHERE ou.organization_id = :NEW.org_id AND
             ou.set_of_books_id = glg.ledger_id;
   EXCEPTION
      WHEN OTHERS THEN
         v_gl_ledger_currency_code := NULL;
   END;

   IF v_gl_ledger_currency_code IS NOT NULL AND
      :NEW.currency_code <> v_gl_ledger_currency_code THEN
      --------Get last Daily Rates ---------------
      v_conversion_rate := gl_currency_api.get_closest_rate_sql(x_from_currency   => :NEW.currency_code,
                                                                x_to_currency     => v_gl_ledger_currency_code,
                                                                x_conversion_date => SYSDATE,
                                                                x_conversion_type => 'Corporate',
                                                                x_max_roll_days   => 7);
   
      /*BEGIN
      SELECT gldr.conversion_rate , gldr.conversion_date
      INTO   v_conversion_rate,    v_conversion_date
      from   GL_DAILY_RATES    gldr
      WHERE  gldr.from_currency=:new.currency_code ---contract currency
      AND    gldr.conversion_type='Corporate'---added 15-Dec-2009
      AND    gldr.to_currency=v_gl_ledger_currency_code
      AND    gldr.conversion_date<=SYSDATE
      AND NOT EXISTS (SELECT 1
                      FROM   GL_DAILY_RATES    gldr2
                      WHERE  gldr2.from_currency=gldr.from_currency
                      AND    gldr2.to_currency  =gldr.to_currency
                      AND    gldr2.conversion_date<=SYSDATE
                      AND    gldr2.conversion_date > gldr.conversion_date);
      
      :new.conversion_rate_date:=trunc(SYSDATE);                
      :new.conversion_rate     :=v_conversion_rate;
      
      EXCEPTION
        WHEN OTHERS THEN 
           NULL;
      END;*/
      :NEW.conversion_rate_date := trunc(SYSDATE);
      :NEW.conversion_rate      := v_conversion_rate;
      ------
   END IF; ---IF :new.currency_code<>v_gl_ledger_currency_code ...  
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END xxokc_k_headers_all_b_bir_trg;
/

