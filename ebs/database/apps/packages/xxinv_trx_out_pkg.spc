CREATE OR REPLACE PACKAGE xxinv_trx_out_pkg AUTHID CURRENT_USER IS
  ----------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  --------------------------------------------------
  -- 1.0   02/02/2021  Roman W.   CHG0049272 : TPL - Receiving Inspection interface
  ----------------------------------------------------------------------------------

  type xxinv_trx_rcv_loads_in_rec is record( -- Added By Roman W. CHG0049272
    load_line_id        NUMBER,
    po_line_location_id NUMBER,
    doc_type            VARCHAR2(120),
    load_id             VARCHAR2(120),
    load_qty            NUMBER);

  type xxinv_trx_rcv_loads_in_tab is table of xxinv_trx_rcv_loads_in_rec; -- Added By Roman W. CHG0049272

  ---------------------------------------------------------------------------
  -- $Header: XXINV_TRX_OUT_PKG   $
  ---------------------------------------------------------------------------
  -- Package: XXINV_TRX_OUT_PKG
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: CUST750 - SH interfaces\CR1043 - Generate Outgoing  files
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  24.9.13   yuval tal         initial build
  ---------------------------------------------------------------------------
  PROCEDURE populate_rcv_file(errbuf          OUT VARCHAR2,
                              retcode         OUT VARCHAR2,
                              p_file_code     IN VARCHAR2,
                              p_days_back     IN NUMBER,
                              p_tpl_user_name IN VARCHAR2,
                              p_directory     IN VARCHAR2,
                              p_inspect_flag  IN VARCHAR2);

  PROCEDURE populate_ship_file(errbuf      OUT VARCHAR2,
                               retcode     OUT VARCHAR2,
                               p_file_code IN VARCHAR2,
                               p_user_name IN VARCHAR2,
                               p_directory IN VARCHAR2);
  -----------------------------------------------------------------
  -- populate_ship_file_allocate
  ----------------------------------------------------------------
  -- Purpose: CHG0041294-TPL Interface FC - Remove Pick Allocations
  --          check  that the relevant open orders that were released to Warehouse,
  --           and were  assigned to delivery, or has any allocations.
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  11.10.17   piyali bhowmick      initial build
  -----------------------------------------------------------------
  PROCEDURE populate_ship_file_allocate(errbuf      OUT VARCHAR2,
                                        retcode     OUT VARCHAR2,
                                        p_file_code IN VARCHAR2,
                                        p_user_name IN VARCHAR2,
                                        p_directory IN VARCHAR2,
                                        p_batch_id  IN NUMBER);
  -----------------------------------------------------------------
  -- populate_ship_file_no_allocate
  ----------------------------------------------------------------
  -- Purpose: CHG0041294-TPL Interface FC - Remove Pick Allocations
  --          check  that the relevant open orders that were released to Warehouse,
  --           and were not assigned to delivery, or has any allocations.
  --
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  11.10.17   piyali bhowmick      initial build
  -----------------------------------------------------------------

  PROCEDURE populate_ship_file_no_allocate(errbuf      OUT VARCHAR2,
                                           retcode     OUT VARCHAR2,
                                           p_file_code IN VARCHAR2,
                                           p_user_name IN VARCHAR2,
                                           p_directory IN VARCHAR2,
                                           p_batch_id  IN NUMBER);

  PROCEDURE populate_wip_file(errbuf      OUT VARCHAR2,
                              retcode     OUT VARCHAR2,
                              p_file_code IN VARCHAR2,
                              p_user_name IN VARCHAR2,
                              p_directory IN VARCHAR2);

  FUNCTION is_subinventory_tpl(p_organization_id NUMBER,
                               p_subinventory    VARCHAR2) RETURN NUMBER;

  --          for PRINT_RMA=?Y?  submit report ?XX: SSYS RMA Report?
  --          copy report to directory  with name RMA_<delivery_id>.pdf
  PROCEDURE generate_rma_report(errbuf            OUT VARCHAR2,
                                retcode           OUT VARCHAR2,
                                p_prefix_name     VARCHAR2,
                                p_organization_id NUMBER,
                                p_line_id         NUMBER);

  FUNCTION get_from_mail_address RETURN VARCHAR2;

  PROCEDURE get_service_parameters(errbuf                   OUT VARCHAR2,
                                   retcode                  OUT VARCHAR2,
                                   p_service_request_number OUT VARCHAR2,
                                   p_machine_serial_number  OUT VARCHAR2,
                                   p_field_service_engineer OUT VARCHAR2,
                                   p_source_line_id         IN NUMBER);

  -----------------------------------------------------------------
  -- is_rcv_trx_processed
  ----------------------------------------------------------------
  -- Purpose: CHG0032515 (Expeditors interfaces)
  --          check whether transaction  processed (status  S success  or C closed )
  --
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.8.14   noam yanai      initial build
  -----------------------------------------------------------------
  FUNCTION is_rcv_trx_processed(p_source_code        VARCHAR2,
                                p_doc_type           VARCHAR,
                                p_order_header_id    NUMBER,
                                p_shipment_header_id NUMBER) RETURN VARCHAR2;

  PROCEDURE split_serial_in_rcv_file(errbuf        OUT VARCHAR2,
                                     retcode       OUT VARCHAR2,
                                     p_source_code IN VARCHAR2,
                                     p_batch_id    IN NUMBER);

  PROCEDURE resend_file(errbuf    OUT VARCHAR2,
                        retcode   OUT VARCHAR2,
                        p_type    IN VARCHAR2,
                        p_file_id IN NUMBER,
                        p_line_id IN NUMBER);

  -------------------------------------------------------------------
  -- Ver    When         Who        Descr
  -- -----  -----------  ---------  ----------------------------------
  -- 1.0    17/02/2021   Roman W.   CHG0049272
  --------------------------------------------------------------------
  procedure get_loads(p_po_line_location_id    IN NUMBER,
                      p_doc_type               IN VARCHAR2,
                      p_qty                    IN NUMBER,
                      p_xxinv_trx_rcv_loads_in OUT xxinv_trx_rcv_loads_in_tab,
                      p_error_code             OUT VARCHAR2,
                      p_error_desc             OUT VARCHAR2);
END xxinv_trx_out_pkg;
/
