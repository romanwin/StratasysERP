CREATE OR REPLACE PACKAGE xxforecast_pkg IS

  --------------------------------------------------------------------
  --  name:            XXFORECAST_PKG
  --  create by:       Avi Hamoy
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :        CUST021 - Handle Forecast Uploads
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2009  Avi Hamoy         initial build
  --  1.2  10.7.12     yuval tal         CR444 : add get_first_day_work + modify forcast date according to bucket
  --  1.3  27/5/14     yuval tal         chg32149 :Update Forecast upload program to work with weeks+month simultaneity
  --                                     add function get_no_of_weeks4month
  --  1.4  03/02/15    Gubendran K       CHG0034269 - Added the comments in ascii_forecaseinterface_resin procedure for p_month_count parameter

  --------------------------------------------------------------------
  FUNCTION get_no_of_weeks4month(p_date DATE, p_organization_id NUMBER)
    RETURN NUMBER;
  --------------------------------------------------------------------
  --  name:            get_designator_period
  --  create by:       Avi Hamoy
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2009  Avi Hamoy         initial build
  --------------------------------------------------------------------
  FUNCTION get_designator_period(pf_calendarname IN VARCHAR2,
                                 pf_date         IN DATE) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            ascii_forecaseinterface
  --  create by:       Avi Hamoy
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2009  Avi Hamoy         initial build
  --------------------------------------------------------------------
  PROCEDURE ascii_forecaseinterface(errbuf            OUT VARCHAR2,
                                    retcode           OUT VARCHAR2,
                                    p_location        IN VARCHAR2,
                                    p_filename        IN VARCHAR2,
                                    p_organization_id IN NUMBER,
                                    p_month_count     IN NUMBER,
                                    --    p_divide_type          IN VARCHAR2,
                                    p_fore_month           IN VARCHAR2,
                                    p_split2weeks_up2month NUMBER DEFAULT -1,
                                    p_min_qty              VARCHAR2);

  --------------------------------------------------------------------
  --  name:            reduce_fieldservice_usage
  --  create by:       Avi Hamoy
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2009  Avi Hamoy         initial build
  --------------------------------------------------------------------
  PROCEDURE reduce_fieldservice_usage(errbuf                OUT VARCHAR2,
                                      retcode               OUT VARCHAR2,
                                      p_organization_id     IN NUMBER,
                                      p_forecast_designator IN VARCHAR2,
                                      p_item_id             IN NUMBER);
  --------------------------------------------------------------------
  --  name:            get_first_day_work
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:
  --------------------------------------------------------------------

  FUNCTION get_first_day_work(p_date DATE, p_organization_id NUMBER)
    RETURN DATE;

  --------------------------------------------------------------------
  --  name:            ascii_forecaseinterface
  --  create by:       Avi Hamoy
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2009  Avi Hamoy         initial build
  --  1.1  05/07/2012  Dalit A. Raviv    correct calculate of v_dateofforecast(Get The Period Start Date)
  --  1.2  03/02/2015  Gubendran K       Added comments in the p_month_count value as 24 from 12 --CHG0034269
  --------------------------------------------------------------------
  PROCEDURE ascii_forecaseinterface_resin(errbuf            OUT VARCHAR2,
                                          retcode           OUT VARCHAR2,
                                          p_location        IN VARCHAR2, -- /UtlFiles/Forecast
                                          p_filename        IN VARCHAR2,
                                          p_organization_id IN NUMBER, -- MFG_ORGANIZATION_ID
                                          p_month_count     IN NUMBER, -- default 12 --CHG0034269:Changed the default value from 12 to 24
                                          p_divide_type     IN VARCHAR2, -- Month
                                          p_fore_month      IN VARCHAR2);

END xxforecast_pkg;
/
