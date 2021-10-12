create or replace function xxconvert_rate_from_USD(p_to_currency     varchar2,
                                                   P_FROM_CURRENCY   VARCHAR2,
                                                   P_CONVERSION_DATE DATE,
                                                   p_price_amount    number)
  RETURN NUMBER IS
  result NUMBER;
  -----------------------------------------------------------------------------
  --  ver   Date    Creator    Description
  --  1.0  XX/XX/XX  XXXXX     	XXXXXXXXX
  --  1.1  02/09/19  Bellona B. CHG0046386-	Add new conversion rate type - AOP
  -----------------------------------------------------------------------------
BEGIN
  SELECT (GDR.CONVERSION_RATE * p_price_amount)
    INTO result
    FROM gl_daily_rates gdr
   WHERE gdr.from_currency = NVL(P_FROM_CURRENCY, 'USD')
     AND GDR.TO_CURRENCY = NVL(p_to_currency, 'USD')
	 AND gdr.conversion_type='Corporate' -- added as part of CHG0046386
     AND TRUNC(GDR.CONVERSION_DATE) =
         NVL(P_CONVERSION_DATE, TRUNC(SYSDATE));
  RETURN(result);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN(null);
  when others then
    return(null);
END;
/
