create or replace package xxpo_req_interfaces_pkg IS

  --------------------------------------------------------------------
  --  name:       xxpo_req_interfaces_pkg
  --  create by:
  --  Revision:
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :        CUST607 - support supplier approval process
  --------------------------------------------------------------------
  --  ver  date          name            desc
  --  1.x  31.12.12      yuval tal      cr644 po requisitions interface group by Sales Order
  --                                     add procedure manipulate_ssys_drop_ship
  --  1.1  8.Nov.18      Lingaraj        CHG0044329 - XX: Upload Purchase Requisitions - Bug fix
  --  1.2  06/01/2020    Bellona(TCS)    CHG0047106 - added new parameter
  --------------------------------------------------------------------
  TYPE  t_string_arr  IS TABLE OF VARCHAR2(240) INDEX BY SIMPLE_INTEGER;--CHG0044329

  PROCEDURE manipulate_ssys_drop_ship(err_buff OUT VARCHAR2,
			  err_code OUT VARCHAR2,
			  p_org_id NUMBER);
  PROCEDURE upload_internal_requisitions(errbuf                      OUT VARCHAR2,
			     errcode                     OUT VARCHAR2,
			     p_location                  IN VARCHAR2,
			     p_filename                  IN VARCHAR2,
			     p_ignore_first_headers_line IN VARCHAR2 DEFAULT 'N',
			     p_mode                      IN VARCHAR2,
			     p_launch_import_requisition IN VARCHAR2,
                 p_submit_approval           IN VARCHAR2);       --CHG0047106

  PROCEDURE upload_purchase_requisitions(errbuf                      OUT VARCHAR2,
			     errcode                     OUT VARCHAR2,
			     p_location                  IN VARCHAR2,
			     p_filename                  IN VARCHAR2,
			     p_ignore_first_headers_line IN VARCHAR2 DEFAULT 'N',
			     p_mode                      IN VARCHAR2,
			     p_launch_import_requisition IN VARCHAR2);

  PROCEDURE create_njrc_requisition(itemtype  IN VARCHAR2,
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2);

  PROCEDURE check_is_njrc_req_needed(itemtype  IN VARCHAR2,
			 itemkey   IN VARCHAR2,
			 actid     IN NUMBER,
			 funcmode  IN VARCHAR2,
			 resultout OUT NOCOPY VARCHAR2);

END xxpo_req_interfaces_pkg;
/
