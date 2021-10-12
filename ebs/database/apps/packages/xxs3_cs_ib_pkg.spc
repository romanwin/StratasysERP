CREATE OR REPLACE PACKAGE xxs3_cs_ib_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            XXS3_CS_IB_PKG
  --  create by:       Debarati Banerjee
  --  Revision:        1.0
  --  creation date:   18/04/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Install Base template fields
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  18/04/2016  TCS            Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required install base fields and insert into
  --           staging table XXS3_CS_INSTANCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  18/04/2016  TCS            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE ib_extract_data(x_errbuf  OUT VARCHAR2
                           ,x_retcode OUT NUMBER);

  PROCEDURE dq_report_ib(p_entity VARCHAR2);
END xxs3_cs_ib_pkg;
/