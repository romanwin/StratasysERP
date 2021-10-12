CREATE OR REPLACE PACKAGE xxs3_ptp_suppliers_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            xxs3_ptp_suppliers_pkg
  --  create by:       Debarati Banerjee
  --  Revision:        1.0
  --  creation date:   28/04/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Suppliers template fields
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  28/04/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required supplier fields and insert into
  --           staging table XXS3_PTP_SUPPLIERS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  28/04/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE suppliers_extract_data(x_errbuf  OUT VARCHAR2,
                                   x_retcode OUT NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  p_only_dq IN VARCHAR2 DEFAULT 'N'*/
                                   /*p_email_id IN VARCHAR2,*/);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required supplier fields and insert into
  --           staging table XXS3_PTP_SUPPLIERS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  28/04/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE supplier_site_extract_data(x_errbuf  OUT VARCHAR2,
                                       x_retcode OUT NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_only_dq IN VARCHAR2 DEFAULT 'N'*/
                                       /*p_email_id IN VARCHAR2,*/);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  05/05/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE suppliers_cont_extract_data(x_errbuf  OUT VARCHAR2,
                                        x_retcode OUT NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_only_dq IN VARCHAR2 DEFAULT 'N'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        p_email_id IN VARCHAR2,*/);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  05/05/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE suppliers_bank_extract_data(x_errbuf  OUT VARCHAR2,
                                        x_retcode OUT NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_only_dq IN VARCHAR2 DEFAULT 'N'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        p_email_id IN VARCHAR2,*/);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  05/05/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bank_details_extract_data(x_errbuf  OUT VARCHAR2,
                                      x_retcode OUT NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        p_only_dq IN VARCHAR2 DEFAULT 'N'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    p_email_id IN VARCHAR2,*/);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  05/05/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bank_branches_extract_data(x_errbuf  OUT VARCHAR2,
                                       x_retcode OUT NUMBER /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_only_dq IN VARCHAR2 DEFAULT 'N'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      p_email_id IN VARCHAR2,*/);

  --------------------------------------------------------------------
  --  name:              dq_report_supplier
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write dq report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report DQ errors
  --------------------------------------------------------------------

  PROCEDURE dq_report_supplier(p_entity VARCHAR2);

  --------------------------------------------------------------------
  --  name:              data_cleanse_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write data cleanse report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data cleanse
  --------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2);

  --------------------------------------------------------------------
  --  name:              data_transform_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write data transform report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data cleanse
  --------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2);

  --------------------------------------------------------------------
  --  name:              extract_report_supplier
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write extract report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     extract report
  --------------------------------------------------------------------

  PROCEDURE extract_report_supplier(p_entity VARCHAR2);

  ----------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  09/06/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------------------------

  PROCEDURE quotation_header_extract_data(x_errbuf  OUT VARCHAR2,
                                          x_retcode OUT NUMBER

                                          );

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  09/06/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------------------------

  PROCEDURE quotation_line_extract_data(x_errbuf  OUT VARCHAR2,
                                        x_retcode OUT NUMBER

                                        );

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  09/06/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------------------------

  PROCEDURE price_break_extract_data(x_errbuf  OUT VARCHAR2,
                                     x_retcode OUT NUMBER

                                     );

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  09/06/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------------------------

  PROCEDURE sourcing_rules_extract_data(x_errbuf  OUT VARCHAR2,
                                        x_retcode OUT NUMBER

                                        );

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  09/06/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------------------------

  PROCEDURE src_rules_assign_extract_data(x_errbuf  OUT VARCHAR2,
                                          x_retcode OUT NUMBER

                                          );

END xxs3_ptp_suppliers_pkg;
/
