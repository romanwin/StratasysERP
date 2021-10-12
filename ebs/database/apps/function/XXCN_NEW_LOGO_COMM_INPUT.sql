CREATE OR REPLACE FUNCTION XXCN_NEW_LOGO_COMM_INPUT(P_LINE_ID NUMBER)
 RETURN number IS
  l_cn_amount number := 0;  -- return 0 = not eligible , 1 = Eligible for New Logo commission
  l_dyn_query  varchar2(2000);
BEGIN
  fnd_message.clear;
  fnd_message.SET_NAME('XXOBJT','XXCN_NEW_LOGO_INPUT_AMOUNT');

  l_dyn_query := fnd_message.GET;

  execute immediate l_dyn_query into l_cn_amount using p_line_id;
  
  RETURN nvl(l_cn_amount,0);
EXCEPTION
  WHEN OTHERS THEN
    RETURN 0;
END XXCN_NEW_LOGO_COMM_INPUT;
/
