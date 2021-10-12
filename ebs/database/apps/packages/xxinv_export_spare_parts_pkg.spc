CREATE OR REPLACE PACKAGE xxinv_export_spare_parts_pkg IS
  --------------------------------------------------------------------
  --  name:            XXINV_EXPORT_SPARE_PARTS_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   06/09/2012
  --------------------------------------------------------------------
  --  purpose :        CHG0035332 - Objet PartnerZone - Spare Parts
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/05/21015  Michal Tzvik    initial build
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            export_family
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   31/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035332 - Objet PartnerZone - Spare Parts
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/05/2015  Michal Tzvik    initial build
  --  1.1  11-Aug-2016 Lingaraj Sarangi CHG0038799 - New fields in SP catalog PZ and Oracle
  --------------------------------------------------------------------
  PROCEDURE export_family(errbuf       OUT VARCHAR2,
                          retcode      OUT VARCHAR2,
                          p_technology IN VARCHAR2,
                          p_family     IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   31/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035332 - Objet PartnerZone - Spare Parts
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/05/2015  Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf       OUT VARCHAR2,
                 retcode      OUT VARCHAR2,
                 p_technology IN VARCHAR2,
                 p_family     IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            Find CS Recommended stock
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   11-Aug-2016
  --------------------------------------------------------------------
  --  purpose :        CHG0038799 - New fields in SP catalog PZ and Oracle
  --                   Added to get the Segement2 value for the 'CS Recommended stock' Category Set
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  11-Aug-2016 Lingaraj Sarangi  initial build
  --------------------------------------------------------------------
  FUNCTION find_cs_recommended_stock(p_printers_perved IN VARCHAR2,
                                     p_categorysetid   IN NUMBER,
                                     p_inv_id          IN NUMBER)
    RETURN VARCHAR2;

END xxinv_export_spare_parts_pkg;
/
