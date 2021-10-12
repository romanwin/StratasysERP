create or replace package xxoks_wf_util_pkg is

--------------------------------------------------------------------
--  name:            XXOKS_WF_UTIL_PKG 
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   12/12/2010 12:07:00
--------------------------------------------------------------------
--  purpose :        OKS WF Needs - Objet customizations
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  12/12/2010  Dalit A. Raviv    initial build
--  1.1  02/01/2011  Dalit A. raviv    XXINITIALIZE - add system details to notification
-------------------------------------------------------------------- 
  
  --------------------------------------------------------------------
  --  name:            upd_mtl_safety_stocks 
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   12/12/2010
  --  cust:            CUSt368 - Modifications at Contract Approval work flow
  --                   add contract price information in the notification.
  --------------------------------------------------------------------
  --  purpose :        Contract approval WF - initialize new attributes
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/12/2010  Dalit A. Raviv    initial build
  --  1.1  02/01/2011  Dalit A. raviv    add system details to notification-------------
  procedure XXINITIALIZE (itemtype  in varchar2,
                          itemkey   in varchar2,
                          actid     in number,
                          funcmode  in varchar2,
                          resultout out nocopy varchar2 );

end XXOKS_WF_UTIL_PKG;
/
