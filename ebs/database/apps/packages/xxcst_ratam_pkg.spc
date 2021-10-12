CREATE OR REPLACE PACKAGE xxcst_ratam_pkg IS

  -- Author  : AVIH
  -- Created : 02/07/2009 15:30:25
  -- Purpose : Handle Unrealized Profit Customization
  --       26/03/2014    Ofer Suad   CHG0031726 - satndard cost changes
  --       01-Sep-2014   Ofer Suad   CHG0033161 - Add org standard cost
  --       08-Mar-2016   Ofer Suad   CHG0037762 - FDM Items with Country Of Origin
  --       06-Nov-2016              CHG0039638 - bug fix and support BI logic

  TYPE org_qrty IS RECORD(
    org_id   NUMBER,
    quantity NUMBER);
  TYPE org_qty_tbl IS TABLE OF org_qrty INDEX BY PLS_INTEGER;
  TYPE org_ids IS TABLE OF NUMBER INDEX BY VARCHAR2(25); --    CHG0037762 - FDM Items with Country Of Origin
  g_org_ids_tbl xxcst_ratam_pkg.org_ids; --CHG0037762 - FDM Items with Country Of Origin

  --------------------------------------------------------------------
  --  name:            is_tryandbuy_system_item --CHG0046935
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   20/01/2020
  --------------------------------------------------------------------
  --  purpose :        Check id system tryand Buy
  --------------------------------------------------------------------
  -- ver   date         name         desc
  -- ----  -----------  -----------  ---------------------------------
  -- 1.0   20/01/2020   Ofer Suad    CHG0046935
  --------------------------------------------------------------------
  function is_tryandbuy_system_item(p_item_id number) return varchar2;

  PROCEDURE calculatequantityforinvorg(errbuf           IN OUT VARCHAR2,
                                       retcode          IN OUT VARCHAR2,
                                       p_asofdate       IN VARCHAR2,
                                       p_subs_inv_orgid IN NUMBER,
                                       p_israel_orgid   IN NUMBER,
                                       p_item_id        IN NUMBER);

  PROCEDURE calcrentaletcperop(errbuf       IN OUT VARCHAR2,
                               retcode      IN OUT VARCHAR2,
                               p_asofdate   IN VARCHAR2,
                               p_subs_orgid IN NUMBER,
                               p_item_id    IN NUMBER);

  PROCEDURE calcintercoorders(errbuf           OUT VARCHAR2,
                              retcode          OUT VARCHAR2,
                              p_asofdate       IN VARCHAR2,
                              p_org_id         IN VARCHAR2, --CHG0039638 perfomance - run all OU Simultaneously
                              p_israel_orgid   IN VARCHAR2,
                              p_ic_selling_org IN VARCHAR2,
                              p_item_id        IN NUMBER,
                              p_golivedate     IN VARCHAR2,
                              p_goliveeur_rate IN NUMBER,
                              p_golivehkd_rate IN NUMBER);

  PROCEDURE calcqtyforinvorg_temp(errbuf      IN OUT VARCHAR2,
                                  retcode     IN OUT VARCHAR2,
                                  p_asofdate  IN VARCHAR2,
                                  p_inv_orgid IN NUMBER);

  FUNCTION get_il_avg_cost(pc_isrorgid IN NUMBER,
                           pc_asofdate IN DATE,
                           pc_itemid   IN NUMBER) RETURN NUMBER;
  --       26/03/2014    Ofer Suad   CHG0031726 - satndard cost changes
  FUNCTION get_il_std_cost(pc_isrorgid IN NUMBER,
                           pc_asofdate IN DATE,
                           pc_itemid   IN NUMBER) RETURN NUMBER; --DETERMINISTIC; --       06-Nov-2016 CHG0039638 -add DETERMINISTIC
  --       01-Sep-2014   Ofer Suad   CHG0033161 - Add org standard cost
  FUNCTION get_org_std_cost(pc_orgid    IN NUMBER,
                            pc_asofdate IN DATE,
                            pc_itemid   IN NUMBER,
                            pc_ou_id    IN NUMBER) RETURN NUMBER;

  PROCEDURE calculateinternalorders(errbuf             OUT VARCHAR2,
                                    retcode            OUT VARCHAR2,
                                    p_asofdate         IN DATE,
                                    p_israel_orgid     IN NUMBER,
                                    p_ic_selling_org   IN VARCHAR2,
                                    p_subsidiary_orgid IN NUMBER,
                                    p_item_id          IN NUMBER,
                                    p_golivedate       IN DATE,
                                    p_goliveeur_rate   IN NUMBER,
                                    p_golivehkd_rate   IN NUMBER,
                                    p_masterorganizid  IN NUMBER);
  --------------------------------------------------------------------
  --  name:            get_org_and_qty --CHG0034713
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   10/03/2015
  --------------------------------------------------------------------
  --  purpose :        Get std cost per organization
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/03/2015  Ofer Suad    initial build
  --------------------------------------------------------------------

  PROCEDURE get_org_and_qty(p_item_id          IN NUMBER,
                            p_aggr_qty         IN NUMBER,
                            p_curr_qty         IN NUMBER,
                            p_asofdate         IN DATE,
                            p_subsidiary_orgid IN NUMBER,
                            p_org_qty_tbl      OUT org_qty_tbl);

  PROCEDURE init_org_from_lookup;
  --------------------------------------------------------------------
  --  name:            Get_manufacturing_org --CHG0039638
  --  create by:
  --  Revision:        1.0
  --  creation date:   06/11/2016
  --------------------------------------------------------------------
  --  purpose :        Get std cost per organization
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/11/2016      initial build
  --------------------------------------------------------------------
  FUNCTION get_manufacturing_org(pc_itemid IN number, p_asofdate IN DATE)
    RETURN NUMBER;
  --------------------------------------------------------------------
  --  name:            is_MB_Item --CHG0039638
  --  create by:
  --  Revision:        1.0
  --  creation date:   06/11/2016
  --------------------------------------------------------------------
  --  purpose :        check if item is Makerbot
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/11/2016      initial build
  --------------------------------------------------------------------
  Function is_MB_Item(pc_itemid IN number) RETURN varchar;

END xxcst_ratam_pkg;
/
