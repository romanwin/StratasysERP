CREATE OR REPLACE PACKAGE xxcs_vpd_security_pkg IS
  FUNCTION party_org_security(obj_schema VARCHAR2, obj_name VARCHAR2)
    RETURN VARCHAR2;
  FUNCTION party_sec(obj_schema VARCHAR2, obj_name VARCHAR2) RETURN VARCHAR2;
  FUNCTION service_request_sec(obj_schema VARCHAR2, obj_name VARCHAR2)
    RETURN VARCHAR2;
  PROCEDURE update_hz_parties_vpd_attr3(errbuf    OUT VARCHAR2,
                                        errcode   OUT VARCHAR2,
                                        p_org_id  IN NUMBER,
                                        p_country IN VARCHAR2);
END xxcs_vpd_security_pkg;
/
