CREATE OR REPLACE PACKAGE xxs3_ptm_item_relationship_pkg AUTHID CURRENT_USER AS

  ----------------------------------------------------------------------------
  --  name:            xxs3_ptm_item_cross_relationship_pkg
  --  create by:       Mishal Kumar
  --  Revision:        1.0
  --  creation date:   24/06/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract Item Cross Relationship fields
  --                   from Legacy system
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  24/06/2016  Mishal Kumar                 Initial build
  ----------------------------------------------------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Item Cross Relationship Fields fields and insert into
  --           staging table xxs3_ptm_item_cross_ref
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE item_relationship_extract(x_errbuf  OUT VARCHAR2,
                               x_retcode OUT NUMBER
                               /*p_email_id IN VARCHAR2,*/);
  END xxs3_ptm_item_relationship_pkg;
/