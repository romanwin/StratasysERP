CREATE OR REPLACE PACKAGE xxconv_il_purchasing_pkg IS

  -- Author  : ELLA.MALCHI
  -- Created : 14/6/2009 17:00:14
  -- Purpose : Purchasing entities conversions

  -- Public type declarations
  PROCEDURE load_quotations(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

  /*Generate FROM PO_CREATE_SR_ASL.CREATE_ASL*/
  PROCEDURE load_asl(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

  /*Generate FROM PO_CREATE_SR_ASL.Create_Sourcing_Rule*/
  PROCEDURE load_sourcing_rule(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

  PROCEDURE load_po_blanket_lines(errbuf        OUT VARCHAR2,
                                  retcode       OUT VARCHAR2,
                                  p_po_segment1 IN VARCHAR2);

  PROCEDURE load_fdm_category_assignments(errbuf  OUT VARCHAR2,
                                          retcode OUT VARCHAR2);

  PROCEDURE convert_po(errbuf         OUT VARCHAR2,
                       retcode        OUT VARCHAR2,
                       p_org_id       IN NUMBER,
                       p_user_id      IN NUMBER,
                       p_resp_id      IN NUMBER,
                       p_resp_appl_id IN NUMBER,
                       p_po_number    IN VARCHAR2);

  PROCEDURE cancel_so_lines_internal(p_so_header_id  IN NUMBER,
                                     p_user_id       IN NUMBER,
                                     p_so_org_id     IN NUMBER,
                                     p_return_status OUT VARCHAR2,
                                     p_error_message OUT VARCHAR2);

  PROCEDURE cancel_requisition_std_cost(errbuf               OUT VARCHAR2,
                                        retcode              OUT VARCHAR2,
                                        p_org_id             IN NUMBER,
                                        p_user_id            IN NUMBER,
                                        p_resp_id            IN NUMBER,
                                        p_resp_appl_id       IN NUMBER,
                                        p_requisition_number IN VARCHAR2);

  PROCEDURE create_requisition_std_cost(errbuf         OUT VARCHAR2,
                                        retcode        OUT VARCHAR2,
                                        p_org_id       IN NUMBER,
                                        p_user_id      IN NUMBER,
                                        p_resp_id      IN NUMBER,
                                        p_resp_appl_id IN NUMBER);

  PROCEDURE convert_po_quotations(errbuf                OUT VARCHAR2,
                                  retcode               OUT VARCHAR2,
                                  p_org_id              IN NUMBER,
                                  p_user_id             IN NUMBER,
                                  p_resp_id             IN NUMBER,
                                  p_resp_appl_id        IN NUMBER,
                                  p_po_quotation_number IN VARCHAR2);

END xxconv_il_purchasing_pkg;
/
