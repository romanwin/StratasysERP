CREATE OR REPLACE PACKAGE xxcust_convert_xref_pkg IS

  ----------------------------------------------------------------------------
  --  name:            XXCUST_CONVERT_XREF_PKG
  --  create by:       TCS
  --  Revision:        1.0
  --  creation date:   11/07/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package containing Functions to map legacy,S3 and sfdc Ids

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  11/07/2016  TCS           Initial build
  ----------------------------------------------------------------------------

  --- Function to get s3 id  for  allied system id  from xref tables

  FUNCTION convert_allied_to_s3(p_entity_name IN VARCHAR2,
		        p_allied_id   IN VARCHAR2) RETURN VARCHAR2;

  --- Function to get Allied id  for  S3 id  from xref tables

  FUNCTION convert_s3_to_allied(p_entity_name IN VARCHAR2,
		        p_s3_id       IN VARCHAR2) RETURN VARCHAR2;

  --- Function to get Legacy id  for  allied id  from xref tables

  FUNCTION convert_allied_to_legacy(p_entity_name IN VARCHAR2,
			p_allied_id   IN VARCHAR2)
    RETURN VARCHAR2;

  PROCEDURE upsert_legacy_cross_ref_table(p_entity_name IN VARCHAR2,
			      p_legacy_id   VARCHAR,
			      p_s3_id       IN VARCHAR2,
			      p_org_id      IN NUMBER,
			      p_attribute1  IN VARCHAR2,
			      p_attribute2  IN VARCHAR2,
			      p_attribute3  IN VARCHAR2,
			      p_attribute4  IN VARCHAR2,
			      p_attribute5  IN VARCHAR2,
			      p_err_code    OUT NUMBER,
			      p_err_message OUT VARCHAR2);

  FUNCTION get_legacy_id_by_s3_id(p_entity_name IN VARCHAR2,
		          p_s3_id       IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION convert_legacy_to_allied(p_entity_name IN VARCHAR2,
			p_legacy_id   IN VARCHAR2)
    RETURN VARCHAR2;
END xxcust_convert_xref_pkg;
/
