CREATE OR REPLACE PACKAGE BODY XXCS_MTB_REPORT_PKG IS
  -------------------------------------------------------------------------------
  FUNCTION GET_FACTOR_FOR_SR_STATISTICS(P_REPORT_DATE_FROM          IN DATE,
                                        P_REPORT_DATE_TO            IN DATE,
                                        P_PRINTER_INSTALL_DATE      IN DATE,
                                        P_PRINTER_ACTIVITY_END_DATE IN DATE)
    RETURN NUMBER IS
    V_PRINTER_START_DATE DATE;
    V_PRINTER_END_DATE   DATE;
    V_FACTOR             NUMBER := 0;
    MISSING_PARAMETER EXCEPTION;
    WRONG_PARAMETER EXCEPTION;
  BEGIN

    IF P_REPORT_DATE_FROM IS NULL OR P_REPORT_DATE_TO IS NULL OR
       P_PRINTER_INSTALL_DATE IS NULL OR
       P_PRINTER_ACTIVITY_END_DATE IS NULL THEN
      RAISE MISSING_PARAMETER;
    END IF;
    IF P_REPORT_DATE_FROM > P_REPORT_DATE_TO OR
       P_PRINTER_INSTALL_DATE > P_PRINTER_ACTIVITY_END_DATE THEN
      RAISE WRONG_PARAMETER;
    END IF;
    ------------------
    IF P_PRINTER_INSTALL_DATE >= P_REPORT_DATE_TO OR
       P_PRINTER_ACTIVITY_END_DATE <= P_REPORT_DATE_FROM THEN
      RETURN 0;
    END IF;
    ------------------
    IF P_REPORT_DATE_FROM >= P_PRINTER_INSTALL_DATE THEN
      V_PRINTER_START_DATE := P_REPORT_DATE_FROM;
    ELSE
      V_PRINTER_START_DATE := P_PRINTER_INSTALL_DATE;
    END IF;
    ------------------
    IF P_REPORT_DATE_TO <= P_PRINTER_ACTIVITY_END_DATE THEN
      V_PRINTER_END_DATE := P_REPORT_DATE_TO;
    ELSE
      V_PRINTER_END_DATE := P_PRINTER_ACTIVITY_END_DATE;
    END IF;
    ----get factor---------------
    IF P_REPORT_DATE_TO  - P_REPORT_DATE_FROM != 0 THEN
      V_FACTOR := (V_PRINTER_END_DATE - V_PRINTER_START_DATE) ------ Machine days / Report days
                  / (P_REPORT_DATE_TO - P_REPORT_DATE_FROM);
    END IF;

    RETURN(V_FACTOR);

  EXCEPTION
    WHEN WRONG_PARAMETER THEN
      RETURN 0;
    WHEN MISSING_PARAMETER THEN
      RETURN 0;
    WHEN OTHERS THEN
      RETURN 0;
  END GET_FACTOR_FOR_SR_STATISTICS;
  -------------------------------------------------------------------------------------
  FUNCTION GET_COUNTER_READING(P_DATE                  IN DATE,
                               P_PRINTER_SERIAL_NUMBER IN VARCHAR2)
    RETURN NUMBER IS
    CURSOR GET_COUNTER_READING IS
      SELECT T.COUNTER_READING, ABS(T.VALUE_TIMESTAMP - P_DATE) DIFFERENCE
        FROM XXCS_COUNTER_READING_V T
       WHERE T.SERIAL_NUMBER = P_PRINTER_SERIAL_NUMBER ---param
       ORDER BY 2;
    V_COUNTER_READING NUMBER := 0;
    V_NUMERIC_DUMMY   NUMBER;
    MISSING_PARAMETER EXCEPTION;
    ---wrong_parameter        exception;
  BEGIN

    IF P_DATE IS NULL OR P_PRINTER_SERIAL_NUMBER IS NULL THEN
      RAISE MISSING_PARAMETER;
    END IF;

    IF GET_COUNTER_READING%ISOPEN THEN
      CLOSE GET_COUNTER_READING;
    END IF;
    ---fetch first record only (with min difference)
    OPEN GET_COUNTER_READING;
    FETCH GET_COUNTER_READING
      INTO V_COUNTER_READING, V_NUMERIC_DUMMY;
    CLOSE GET_COUNTER_READING;

    RETURN V_COUNTER_READING;

  EXCEPTION
    ---when wrong_parameter then
    ---  return null;
    WHEN MISSING_PARAMETER THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END GET_COUNTER_READING;
  -------------------------------------------------------------------------------------
  -------------------------------------------------------------------------------------
  FUNCTION GET_LAST_COUNTER_READING(P_PRINTER_SERIAL_NUMBER IN VARCHAR2)
    RETURN NUMBER IS
    CURSOR GET_LAST_COUNTER_READING IS
      SELECT T.COUNTER_READING, T.VALUE_TIMESTAMP
        FROM XXCS_COUNTER_READING_V T
       WHERE T.SERIAL_NUMBER = P_PRINTER_SERIAL_NUMBER ---param
       ORDER BY 2 DESC;
    V_LAST_COUNTER_READING NUMBER := 0;
    V_DATE_DUMMY           DATE;
    MISSING_PARAMETER EXCEPTION;
    ---wrong_parameter        exception;
  BEGIN

    IF P_PRINTER_SERIAL_NUMBER IS NULL THEN
      RAISE MISSING_PARAMETER;
    END IF;

    IF GET_LAST_COUNTER_READING%ISOPEN THEN
      CLOSE GET_LAST_COUNTER_READING;
    END IF;
    ---fetch first record only (with min difference)
    OPEN GET_LAST_COUNTER_READING;
    FETCH GET_LAST_COUNTER_READING
      INTO V_LAST_COUNTER_READING, V_DATE_DUMMY;
    CLOSE GET_LAST_COUNTER_READING;

    RETURN V_LAST_COUNTER_READING;

  EXCEPTION
    ---when wrong_parameter then
    ---  return null;
    WHEN MISSING_PARAMETER THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END GET_LAST_COUNTER_READING;
  -------------------------------------------------------------------------------------
  FUNCTION CONVERT_DURATION_UOM(P_FROM_UOM IN VARCHAR2,
                                P_TO_UOM   IN VARCHAR2,
                                P_DURATION IN NUMBER) RETURN NUMBER IS
    V_MINUTES_FACTOR  NUMBER := 60;
    V_HOURS_FACTOR    NUMBER := 1;
    V_DAYS_FACTOR     NUMBER := 1 / 24;
    V_WEEKS_FACTOR    NUMBER := 1 / (7 * 24);
    V_BI_WEEKS_FACTOR NUMBER := 1 / (2 * 7 * 24);
    V_MONTH_FACTOR    NUMBER := 1 / (30 * 24); ---30 days
    V_QUATERS_FACTOR  NUMBER := 1 / (3 * 30 * 24); ---90 days
    V_YEARS_FACTOR    NUMBER := 1 / (365 * 24); ---365 days

    V_DURATION_IN_HOURS NUMBER;
    V_RETURN_DURATION   NUMBER;
    MISSING_PARAMETER EXCEPTION;
    WRONG_PARAMETER EXCEPTION;
  BEGIN

    IF P_FROM_UOM IS NULL OR P_TO_UOM IS NULL OR P_DURATION IS NULL THEN
      RAISE MISSING_PARAMETER;
    END IF;

    IF P_FROM_UOM NOT IN
       ('HR', 'MIN', 'DAY', 'WK', 'BWK', 'MTH', 'QTR', 'YR') OR
       P_TO_UOM NOT IN
       ('HR', 'MIN', 'DAY', 'WK', 'BWK', 'MTH', 'QTR', 'YR') OR
       P_DURATION < 0 THEN
      RAISE WRONG_PARAMETER;
    END IF;

    IF P_FROM_UOM = 'MIN' THEN
      V_DURATION_IN_HOURS := P_DURATION / V_MINUTES_FACTOR;
    ELSIF P_FROM_UOM = 'HR' THEN
      V_DURATION_IN_HOURS := P_DURATION / V_HOURS_FACTOR;
    ELSIF P_FROM_UOM = 'DAY' THEN
      V_DURATION_IN_HOURS := P_DURATION / V_DAYS_FACTOR;
    ELSIF P_FROM_UOM = 'WK' THEN
      V_DURATION_IN_HOURS := P_DURATION / V_WEEKS_FACTOR;
    ELSIF P_FROM_UOM = 'BWK' THEN
      V_DURATION_IN_HOURS := P_DURATION / V_BI_WEEKS_FACTOR;
    ELSIF P_FROM_UOM = 'MTH' THEN
      V_DURATION_IN_HOURS := P_DURATION / V_MONTH_FACTOR;
    ELSIF P_FROM_UOM = 'QTR' THEN
      V_DURATION_IN_HOURS := P_DURATION / V_QUATERS_FACTOR;
    ELSIF P_FROM_UOM = 'YR' THEN
      V_DURATION_IN_HOURS := P_DURATION / V_YEARS_FACTOR;
    ELSE
      RETURN NULL;
    END IF;

    IF P_TO_UOM = 'MIN' THEN
      V_RETURN_DURATION := V_DURATION_IN_HOURS * V_MINUTES_FACTOR;
    ELSIF P_TO_UOM = 'HR' THEN
      V_RETURN_DURATION := V_DURATION_IN_HOURS * V_HOURS_FACTOR;
    ELSIF P_TO_UOM = 'DAY' THEN
      V_RETURN_DURATION := V_DURATION_IN_HOURS * V_DAYS_FACTOR;
    ELSIF P_TO_UOM = 'WK' THEN
      V_RETURN_DURATION := V_DURATION_IN_HOURS * V_WEEKS_FACTOR;
    ELSIF P_TO_UOM = 'BWK' THEN
      V_RETURN_DURATION := V_DURATION_IN_HOURS * V_BI_WEEKS_FACTOR;
    ELSIF P_TO_UOM = 'MTH' THEN
      V_RETURN_DURATION := V_DURATION_IN_HOURS * V_MONTH_FACTOR;
    ELSIF P_TO_UOM = 'QTR' THEN
      V_RETURN_DURATION := V_DURATION_IN_HOURS * V_QUATERS_FACTOR;
    ELSIF P_TO_UOM = 'YR' THEN
      V_RETURN_DURATION := V_DURATION_IN_HOURS * V_YEARS_FACTOR;
    ELSE
      RETURN NULL;
    END IF;

    RETURN(V_RETURN_DURATION);

  EXCEPTION
    WHEN WRONG_PARAMETER THEN
      RETURN NULL;
    WHEN MISSING_PARAMETER THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END CONVERT_DURATION_UOM;
  -------------------------------------------------------------------------------------
  FUNCTION GET_ITEM_COST( p_inventory_organization_id  IN NUMBER,
                          p_inventory_item_id          IN NUMBER,
                          p_precision                  IN NUMBER,
                          p_from_quantity              IN NUMBER,
                          p_from_uom                   IN VARCHAR2) return NUMBER IS
     v_converted_qty      NUMBER;
     v_item_unit_cost     NUMBER;
     v_primary_uom        VARCHAR2(100);
     MISSING_PARAMETER    EXCEPTION;
  BEGIN
  ---- Check parameters
  IF p_inventory_organization_id IS NULL OR
     p_inventory_item_id         IS NULL OR
     p_precision                 IS NULL OR
     p_from_quantity             IS NULL OR
     p_from_uom                  IS NULL THEN
      RAISE MISSING_PARAMETER;
  END IF;
  --- Get primary UOM for this item
  BEGIN
     SELECT msi.primary_uom_code
     INTO   v_primary_uom
     FROM   MTL_SYSTEM_ITEMS_B  msi
     WHERE  msi.organization_id  =p_inventory_organization_id  ---parameter
     AND    msi.inventory_item_id=p_inventory_item_id;         ---parameter
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  --- Convert Quantity From UOM To UOM
  BEGIN
      v_converted_qty:=INV_CONVERT.INV_UM_CONVERT(p_inventory_item_id,
                                                  p_precision,
                                                  p_from_quantity,
                                                  p_from_uom,
                                                  v_primary_uom, ----to_uom,
                                                  NULL,
                                                  NULL);
  EXCEPTION
    WHEN OTHERS THEN
       RETURN NULL;
  END;
  --- Get item cost
  BEGIN
       SELECT c.ITEM_COST
       INTO   v_item_unit_cost
       FROM   XXCS_ITEM_COGS_V  c
       WHERE  c.inventory_item_id=p_inventory_item_id ---param
       AND    c.inventory_organization_id=p_inventory_organization_id  ---parameter
       AND    c.UOM=v_primary_uom;               ---selected value
  EXCEPTION
    WHEN OTHERS THEN
       RETURN NULL;
  END;
  RETURN v_item_unit_cost*v_converted_qty;
  EXCEPTION
    WHEN MISSING_PARAMETER THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END GET_ITEM_COST;
  -------------------------------------------------------------------------------------
  FUNCTION get_workdays(p_org_id     IN NUMBER,
                        p_date_from  IN DATE,
                        p_date_to    IN DATE) return NUMBER IS
  CURSOR get_dates (p_org_id     IN NUMBER,
                    p_date_from  IN DATE,
                    p_date_to    IN DATE)  IS
  SELECT DATES_TAB.calendar_date,
             CASE
                 WHEN DATES_TAB.next_calendar_date IS NULL AND
                      DATES_TAB.prev_calendar_date IS NULL THEN
                        'ONE DATE ONLY'
                 WHEN DATES_TAB.prev_calendar_date IS NULL THEN
                        'FIRST DATE'
                 WHEN DATES_TAB.next_calendar_date IS NULL THEN
                        'LAST DATE'
                 ELSE
                        'REGULAR DATE'
                 END    date_type,
             DATES_TAB.weekend_flag
      FROM ( SELECT a.calendar_date,
             CASE
                 WHEN p_org_id =81 AND to_char(a.calendar_date,'D')  IN ('6','7') THEN 'Y'
                 WHEN p_org_id!=81 AND to_char(a.calendar_date,'D')  IN ('7','1') THEN 'Y'
                 ELSE 'N'
                 END        weekend_flag,
             LEAD(a.calendar_date)    OVER (ORDER BY a.calendar_date)     next_calendar_date,
             LAG(a.calendar_date)    OVER (ORDER BY a.calendar_date)      prev_calendar_date
      FROM   (SELECT calendar_date FROM MSC_CALENDAR_DATES WHERE calendar_code='OBJ:OB_MON_FRI')  a
      WHERE  a.calendar_date BETWEEN trunc(p_date_from) AND trunc(p_date_to)
                         ) DATES_TAB
      ORDER BY DATES_TAB.calendar_date;

     MISSING_PARAMETER       EXCEPTION;
     WRONG_PARAMETER         EXCEPTION;
     v_workdays              NUMBER:=0;
     v_calendar_date         DATE;
     v_date_type             VARCHAR2(100);
     v_weekend_flag          VARCHAR2(1);

  BEGIN

  IF p_org_id IS NULL OR p_date_from IS NULL OR p_date_to IS NULL THEN
      RAISE MISSING_PARAMETER;
  END IF;
  IF p_date_from>p_date_to THEN
     RETURN 0; ----RAISE WRONG_PARAMETER;
  END IF;
  IF get_dates%ISOPEN THEN
       CLOSE get_dates;
  END IF;
  OPEN get_dates(p_org_id,p_date_from,p_date_to);
  LOOP
      FETCH get_dates INTO v_calendar_date,v_date_type,v_weekend_flag;
      EXIT WHEN get_dates%NOTFOUND;
      IF    v_date_type ='ONE DATE ONLY' AND
            v_weekend_flag='N' THEN
           v_workdays:=v_workdays+ (p_date_to-p_date_from);
      ELSIF v_date_type='FIRST DATE' AND
            v_weekend_flag='N' THEN
           v_workdays:=v_workdays+ (trunc(p_date_from) +1 -p_date_from);
      ELSIF v_date_type ='REGULAR DATE' AND
            v_weekend_flag='N' THEN
           v_workdays:=v_workdays+ 1;
      ELSIF v_date_type='LAST DATE' AND
            v_weekend_flag='N' THEN
           v_workdays:=v_workdays+ (p_date_to-trunc(p_date_to));
      END IF;
  END LOOP;
  CLOSE get_dates;

  RETURN v_workdays;

  EXCEPTION
    WHEN MISSING_PARAMETER THEN
      RETURN NULL;
    WHEN WRONG_PARAMETER THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END get_workdays;
  --------------------------------------------------------------------------------------
END XXCS_MTB_REPORT_PKG;
/

