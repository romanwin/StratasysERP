create or replace package XXPUR_RFQ_REP_PKG is

  Procedure PRINT_RFQ(errbuf           out varchar2,
                      retcode          out number,
                      P_report_type    in varchar2,
                      P_agent_name_num in number,
                      P_rfq_num_from   in number,
                      P_rfq_num_to     in number,
                      P_test_flag      in varchar2,
                      P_sortby         in varchar2,
                      P_user_id        in number,
                      P_supplier       in varchar2);

End XXPUR_RFQ_REP_PKG;
/

