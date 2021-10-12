CREATE OR REPLACE PACKAGE xxconv_inv_trx_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxconv_inv_trx_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxconv_inv_trx_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: CR1178 - Receive and  re-ship intransit shipment at cutover
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  7.7.13     Vitaly       initial build
  ------------------------------------------------------------------
  PROCEDURE transfer_oh_qty(errbuf               OUT VARCHAR2,
                            retcode              OUT VARCHAR2,
                            p_shipment_header_id NUMBER);
  ----------------------------------------------------------------------------
  -----PROCEDURE transfer_oh_qty_tpl(p_from_organization_id IN NUMBER);

  PROCEDURE handle_new_intransit_shipment(errbuf               OUT VARCHAR2,
                                          retcode              OUT VARCHAR2,
                                          p_shipment_header_id NUMBER,
                                          p_request_id         NUMBER);
  PROCEDURE validate_existing_quantities(errbuf               OUT VARCHAR2,
                                         retcode              OUT VARCHAR2,
                                         p_shipment_header_id NUMBER,
                                         p_request_id         NUMBER);
  PROCEDURE handle_rcv_internal_trx(errbuf               OUT VARCHAR2,
                                    retcode              OUT VARCHAR2,
                                    p_shipment_header_id NUMBER,
                                    p_request_id         NUMBER);
  PROCEDURE update_rcv_status(errbuf               OUT VARCHAR2,
                              retcode              OUT VARCHAR2,
                              p_status             VARCHAR2,
                              p_err_message        VARCHAR2,
                              p_shipment_header_id NUMBER,
                              p_trx_id             NUMBER DEFAULT NULL);

  PROCEDURE populate_rcv_file(errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_org_id          IN NUMBER,
                              p_shipment_number IN VARCHAR2,
                              p_request_id      IN NUMBER);
  PROCEDURE main(errbuf            OUT VARCHAR2,
                 retcode           OUT VARCHAR2,
                 p_org_id          IN NUMBER,
                 p_shipment_number IN VARCHAR2);

END xxconv_inv_trx_pkg;
/
