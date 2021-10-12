CREATE OR REPLACE PACKAGE XXOM_UTIL_PKG IS

--------------------------------------------------------------------
  --  customization code: CUSTxxx
  --  name:               XXOM_UTIL_PKG
  --  create by:          Rimpi
  --  $Revision:          1.0
  --  creation date:       30-Mar-2017
  --  Purpose :           CHG0040391: Package to cancel the Sales Order from Conc prog: XXSSYS Order/Line Cancellation Program
  ----------------------------------------------------------------------
  --  ver   date           name               desc
  --  1.0   30-Mar-2017    Rimpi              CHG0040391: initial build
  --  1.1   30-Aug-2017    Lingaraj           INC0100407 - Line Cancellation Not working When Split Line
  --  2.0   10-Nov-2017    Diptasurjya        CHG0041821: Script to close order header workflow where all lines
  --                                                    are in closed or cancelled state.
  --                                            added procedure : close_order           
  -----------------------------------------------------------------------

    --------------------------------------------------------------------
  --  name:             main
  --  create by:        Rimpi
  --  Revision:         1.0
  --  creation date:    30-Mar-2017
  --------------------------------------------------------------------
  --  purpose :         CHG0040391: Called from Conc prog.: XXSSYS Order/Line Cancellation Program to cancel the Sales Order
  ----------------------------------------------------------------------
  --  ver   date           name                 desc
  --  1.0   30-Mar-2017    Rimpi                CHG0040391: initial build
  --  1.1   30-Aug-2017    Lingaraj         INC0100407 - Line Cancellation Not working When Split Line
  -----------------------------------------------------------------------

PROCEDURE cancel_order  (  errbuf OUT VARCHAR2,
                           retcode OUT VARCHAR2,
                           p_header_id IN NUMBER,
                           p_cancel_header_line IN VARCHAR2,
                           p_dummy              IN VARCHAR2,--not for use
                           p_line_id            IN NUMBER ,
                           p_debug              IN VARCHAR2
                          );
                          
  --------------------------------------------------------------------
  --  name:             close_order
  --  create by:        Diptasurjya
  --  Revision:         1.0
  --  creation date:    10-Nov-2017
  --------------------------------------------------------------------
  --  purpose :         CHG0041821: Script to close order header workflow where all lines
  --                    are in closed or cancelled state
  ----------------------------------------------------------------------
  --  ver   date           name             desc
  --  1.0   10-Nov-2017    Diptasurjya      CHG0041821: initial build
  -----------------------------------------------------------------------
  PROCEDURE close_order( errbuf OUT VARCHAR2,
                         retcode OUT VARCHAR2,
                         p_header_id IN NUMBER,
                         p_report_only     IN VARCHAR2,
                         p_debug IN varchar2 default 'N'
                         );
END XXOM_UTIL_PKG;
/
