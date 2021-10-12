CREATE OR REPLACE FUNCTION XXCN_NEW_LOGO_COMM_ELIGIBLE(P_LINE_ID NUMBER)
 RETURN number IS
  l_is_eligible number := 0;  -- return 0 = not eligible , 1 = Eligible for New Logo commission
  l_dyn_query  varchar2(2000);
BEGIN
  fnd_message.clear;
  fnd_message.SET_NAME('XXOBJT','XXCN_NEW_LOGO_IDENTIFY_QUERY');

  l_dyn_query := fnd_message.GET;

  execute immediate l_dyn_query into l_is_eligible using p_line_id;

  if l_is_eligible >= 1 then
    l_is_eligible := 1;
  end if;

  RETURN l_is_eligible;
EXCEPTION
  WHEN OTHERS THEN
    RETURN 0;
END XXCN_NEW_LOGO_COMM_ELIGIBLE;
/
