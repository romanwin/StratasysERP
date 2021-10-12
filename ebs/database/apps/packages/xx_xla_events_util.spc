create or replace package xx_xla_events_util is

  Procedure Clear_Event_Of_Deleted_Dist(x_return_code        OUT VARCHAR2,
                                        x_err_msg            OUT VARCHAR2,
                                        p_transaction_number varchar2,
                                        p_org_id             number);
  Procedure clear_Invalid_Events_PO(x_return_code        OUT VARCHAR2,
                                    x_err_msg            OUT VARCHAR2,
                                    p_transaction_number varchar2,
                                    p_org_id             number);
  Procedure clear_Invalid_Events_REQ(x_return_code        OUT VARCHAR2,
                                     x_err_msg            OUT VARCHAR2,
                                     p_transaction_number varchar2,
                                     p_org_id             number);

end xx_xla_events_util;
/

