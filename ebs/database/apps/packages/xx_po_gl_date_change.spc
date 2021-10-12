create or replace package xx_po_gl_date_change IS

  --------------------------------------------------------------------
  --  name:            xx_po_gl_date_change
  --  create by:       OFER.SUAD
  --  Revision:        1.11
  --  creation date:   15/08/2011
  --------------------------------------------------------------------
  --  purpose :        PP's GL date carry forward
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0    15/08/2011  Ofer Suad      initial build
  --  1.1    15/01/2017  Ofer Suad   CHG0041827 bug fix changes
  --  1.2    11/06/2019  Bellona.B   CHG0046530 create new procedure to 
  --                                 process all the PO’s that were received but not invoiced 
  --------------------------------------------------------------------

  PROCEDURE main(errbuf OUT VARCHAR2, retcode OUT NUMBER);
  PROCEDURE do_unresrve(p_doc_level_id_tbl IN po_tbl_number,
                        p_status           OUT VARCHAR2);
  PROCEDURE do_reserve(p_doc_level_id_tbl IN po_tbl_number,
                       p_detailed_results OUT po_fcout_type,
                       p_status           OUT VARCHAR2);
  PROCEDURE chage_dist_gl_date(p_doc_level_id_tbl IN po_tbl_number,
                               p_new_gl_date      IN DATE);
  PROCEDURE populate_encum_table(doc_seq_num    NUMBER,
                                 p_po_dist_id   NUMBER,
                                 p_po_num       VARCHAR2,
                                 p_po_line_num  NUMBER,
                                 p_orig_gl_date DATE,
                                 p_req_dist_id  NUMBER);
  PROCEDURE pupulate_gl_interface;

  PROCEDURE load_file(errbuf     OUT VARCHAR2,
                      retcode    OUT VARCHAR2,
                      p_location IN VARCHAR2,
                      p_filename IN VARCHAR2);
  FUNCTION get_value_from_line(p_line_string IN OUT VARCHAR2,
                               p_err_msg     IN OUT VARCHAR2,
                               p_counter     IN NUMBER,
                               c_delimiter   IN VARCHAR2) RETURN VARCHAR2;
  PROCEDURE approve_docs;
  -----------------------------------------------------
  --  ver   date        name           desc
  --  1.0   15/08/2011  Bellona.B      CHG0046530 - initial build
  -----------------------------------------------------
  PROCEDURE po_received_not_invoice_je(errbuf     OUT VARCHAR2,
                                       retcode    OUT VARCHAR2,
                                       p_period   IN VARCHAR2);  
  --------------------------------------
  --1.1  15/01/2018  Ofer Suad CHG0041827  error log
  -------------------------------
  PROCEDURE write_log_message(p_po_number VARCHAR2,
                              p_po_line   Number,
                              Po_msg      VARCHAR2);

END xx_po_gl_date_change;
/