CREATE OR REPLACE PACKAGE xxs3_ptm_bom_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxs3_ptm_bom_pkg
  --  create by:       Debarati Banerjee
  --  Revision:        1.0
  --  creation date:   01/07/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Bom Routings template fields
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  01/07/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Bom Routings fields and insert into
  --           staging table XXS3_PTM_BOM_DEPT
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  01/07/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bom_dept_extract_data(x_errbuf  OUT VARCHAR2,
                                  x_retcode OUT NUMBER /*,
                                                                                                                                                                                                      p_only_dq IN VARCHAR2 DEFAULT 'N'*/
                                  /*p_email_id IN VARCHAR2,*/);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Bom Resource fields and insert into
  --           staging table XXS3_PTM_BOM_RESOURCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  01/07/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bom_resource_extract_data(x_errbuf  OUT VARCHAR2,
                                      x_retcode OUT NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Bom Routing fields and insert into
  --           staging table XXS3_PTM_BOM_ROUTING
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  012/07/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bom_routing_extract_data(x_errbuf  OUT VARCHAR2,
                                     x_retcode OUT NUMBER);

  --------------------------------------------------------------------
  --  name:              data_cleanse_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/07/2016
  --------------------------------------------------------------------
  --  purpose :          write data cleanse report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data cleanse
  --------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2);

  --------------------------------------------------------------------
  --  name:              dq_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/07/2016
  --------------------------------------------------------------------
  --  purpose :          write dq report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/07/2016    Debarati banerjee     report DQ errors
  --------------------------------------------------------------------

  PROCEDURE dq_report(p_entity VARCHAR2);

  --------------------------------------------------------------------
  --  name:              data_transform_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     11/07/2016
  --------------------------------------------------------------------
  --  purpose :          write data transform report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data transform
  --------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2);

END xxs3_ptm_bom_pkg;
/
