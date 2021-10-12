CREATE OR REPLACE PACKAGE xxom_auto_book_order_pkg AUTHID CURRENT_USER AS
  --------------------------------------------------------------------
  --  Name         :     xxom_auto_book_order_pkg
  --  Created by   :     Gubendran K
  --  Revision     :     1.0
  --  Creation Date:     04/23/2015
  --------------------------------------------------------------------
  --  Purpose      :    Auto book the sales order, Once the hold is released
  --------------------------------------------------------------------
  --  Version  Date        Name           Description
  --  1.0      04/23/2015  Gubendran K    Initial Build - CHG0031592
  --  1.1      11.10.2018  yuval tal      CHG0044178 add book order 
  --------------------------------------------------------------------
  --  Name:            auto_book_order
  --  Create by:       Gubendran K
  --  Revision:        1.0
  --  Creation Date:   04/23/2015
  --------------------------------------------------------------------
  --  purpose :        Auto book the sales order, Once the hold is released
  --------------------------------------------------------------------
  --  Version  Date        Name           Description
  --  1.0      04/23/2015  Gubendran K    Initial Build - CHG0031592
  --------------------------------------------------------------------
  PROCEDURE auto_book_order(errbuf               OUT VARCHAR2,
		    retcode              OUT NUMBER,
		    p_order_source_id    IN NUMBER,
		    p_created_by_user_id IN NUMBER,
		    p_send_mail          IN VARCHAR2,
		    p_org_id             IN NUMBER);

  --------------------------------------------------------------------
  --  purpose :        Auto book the sales order without holds
  --------------------------------------------------------------------
  --  Version  Date        Name           Description
  --  1.0      11.10.2018  yuval tal      CHG0044178 book order in enter status without hold 
  --------------------------------------------------------------------            

  PROCEDURE book_order(errbuf               OUT VARCHAR2,
	           retcode              OUT NUMBER,
	           p_order_source_id    IN NUMBER,
	           p_created_by_user_id IN NUMBER,
	           p_send_mail          IN VARCHAR2,
	           p_org_id             IN NUMBER);

END xxom_auto_book_order_pkg;
/
