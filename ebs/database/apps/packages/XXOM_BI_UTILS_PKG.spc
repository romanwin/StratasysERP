create or replace package xxom_bi_utils_pkg authid current_user as
  --------------------------------------------------------------------
  --  name:            XXOM_BI_UTILS_PKG
  --  Cust:            CHG0043884 - Package to be called for program XXOM: populate XXBI_OE_ORDER_LINES_ALL
  --  create by:       Bellona Banerjee
  --  Revision:        1.0
  --  creation date:   07/09/2018
  --------------------------------------------------------------------
  --  purpose :        Package created to populate XXBI_OE_ORDER_LINES_ALL table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/09/2018  Bellona(TCS)   initial build
  --------------------------------------------------------------------
  C_DEFAULT_PERIOD CONSTANT NUMBER := 0.003472222222222222222222222222222222222225;

  --------------------------------------------------------------------
  --  ver  date        name           desc
  -- ----  ----------  -------------  --------------------------------
  --  1.0  12/09/2018  Roman W.       CHG0043884-initial build
  --------------------------------------------------------------------
  procedure calculate_period(p_in_date_from  in date,
                             p_in_date_to    in date,
                             p_out_date_from out date,
                             p_out_date_to   out date,
                             p_error_code    out varchar2,
                             p_error_desc    out varchar2);

  --Declaring PL/SQL table type
  --  TYPE t_xxoe_tab IS TABLE OF XXBI_OE_ORDER_LINES_ALL%ROWTYPE INDEX BY PLS_INTEGER;
  --------------------------------------------------------------------
  --  name:            pop_XXBI_OE_ORDER_LINES_ALL
  --  create by:       Bellona(TCS)
  --  creation date:   12/09/2018
  --------------------------------------------------------------------
  --  purpose :        main procedure to populate XXBI_OE_ORDER_LINES_ALL
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/09/2018  Bellona(TCS)    initial build
  --                                     concurrent : XXOM: populate XXBI_OE_ORDER_LINES_ALL
  --------------------------------------------------------------------
  procedure pop_xxbi_oe_order_lines_all(errbuf      out varchar2,
                                        retcode     out varchar2,
                                        p_date_from in varchar2,
                                        p_date_to   in varchar2);

  --------------------------------------------------------------------
  --  ver  date        name           desc
  -- ----  ----------  -------------  --------------------------------
  --  1.0  12/09/2018  Roman W.       CHG0043884-initial build
  --------------------------------------------------------------------                                    
  procedure delete_old_rows_oe_order_lines(errbuf  out varchar2,
                                           retcode out varchar2);

end xxom_bi_utils_pkg;
/