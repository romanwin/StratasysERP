CREATE OR REPLACE PACKAGE xxconv_routing_pkg IS

  --------------------------------------------------------------------
  --  customization code: CUSTXXX
  --  name:               Insert_Interface_routing - conversion
  --  create by:          Ella Malchi
  --  $Revision:          1.0 
  --  creation date:      xx/xx/2009
  --------------------------------------------------------------------
  PROCEDURE insert_interface_routing(errbuf           OUT VARCHAR2,
                                     retcode          OUT VARCHAR2,
                                     p_reference_flag IN VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CUST215
  --  name:               ins_LTF_operation_resource - convertion tead time
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      20/12/2009
  --------------------------------------------------------------------
  PROCEDURE ins_ltf_operation_resource(errbuf  OUT VARCHAR2,
                                       retcode OUT VARCHAR2);

END xxconv_routing_pkg;
/
