CREATE OR REPLACE PACKAGE xxpo_po_linkage_pkg IS

  --------------------------------------------------------------------
  --  name:            XXPO_PO_LINKAGE_PKG
  --  create by:       ELLA.MALCHI
  --  Revision:        1.0
  --  creation date:   02/09/2009 13:25:06
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/09/2009  Ella Malchi       initial build
  --  1.1  27/10/2013  Dalit A. Raviv    Procedure delete_po_linkage - Add parameter of release_num
  --  1.2  21/01/2014  Vitaly            CUST-6  CR-1254:  New procedure update_header_id was added
  --------------------------------------------------------------------

  -- Original PO Header Record
  TYPE po_order_header_rec_type IS RECORD(
    po_header_id  NUMBER := NULL,
    po_number     VARCHAR2(30) := NULL,
    currency_code VARCHAR(3) := NULL,
    rate          NUMBER := NULL,
    rate_date     DATE := NULL,
    rate_type     VARCHAR2(30) := NULL);

  g_miss_order_header_rec po_order_header_rec_type;

  -- Original PO Lines Record
  TYPE po_order_line_rec_type IS RECORD(
    po_header_id NUMBER := NULL,
    po_line_id   NUMBER := NULL,
    item_id      NUMBER := NULL,
    category_id  NUMBER := NULL,
    quantity     NUMBER := NULL,
    unit_price   NUMBER := NULL);

  g_miss_order_line_rec po_order_line_rec_type;

  TYPE quotation_rec_type IS RECORD(
    po_header_id           NUMBER := NULL,
    po_line_id             NUMBER := NULL,
    line_location_id       NUMBER := NULL,
    currency_code          VARCHAR(3) := NULL,
    functional_currency    VARCHAR(3) := NULL,
    rate                   NUMBER := NULL,
    rate_date              DATE := NULL,
    rate_type              VARCHAR2(30) := NULL,
    line_quantity          NUMBER := NULL,
    line_curr_price        NUMBER := NULL,
    line_func_price        NUMBER := NULL,
    price_break_quantity   NUMBER := NULL,
    organization_id        NUMBER := NULL,
    price_break_curr_price NUMBER := NULL,
    price_break_func_price NUMBER := NULL);

  g_miss_quotation_rec quotation_rec_type;

  TYPE quotation_tbl_type IS TABLE OF quotation_rec_type INDEX BY BINARY_INTEGER;
  g_miss_quotation_tbl quotation_tbl_type;

  PROCEDURE get_catalog_price(t_order_header          po_order_header_rec_type,
                              t_order_line            po_order_line_rec_type,
                              t_selected_quote        quotation_rec_type,
                              t_quotations            quotation_tbl_type,
                              x_base_unit_price       OUT NOCOPY NUMBER,
                              x_from_line_location_id OUT NOCOPY NUMBER,
                              x_price                 OUT NOCOPY NUMBER,
                              x_return_status         OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------
  --  name:            delete_po_linkage
  --  create by:       ELLA.MALCHI
  --  Revision:        1.0
  --  creation date:   02/09/2009 13:25:06
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/09/2009  Ella Malchi       initial build
  --  1.1  27/10/2013  Dalit A. Raviv    add parameter of p_release_num
  --------------------------------------------------------------------
  PROCEDURE delete_po_linkage(errbuf        OUT VARCHAR2,
                              retcode       OUT VARCHAR2,
                              po_number     IN clef062_po_index_esc_set.document_id%TYPE,
                              p_release_num IN NUMBER);

  --------------------------------------------------------------------
  --  name:            update_header_id
  --  create by:       Vitaly
  --  Revision:        1.0
  --  creation date:   21/01/2014
  --------------------------------------------------------------------
  --  purpose : CUST-6  CR-1254 - Populate PO Header ID for Standard linked PO
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  21/01/2014  Vitaly         initial build
  --------------------------------------------------------------------
  PROCEDURE update_header_id(errbuf      OUT VARCHAR2,
                             retcode     OUT VARCHAR2,
                             p_days_back IN NUMBER);

END xxpo_po_linkage_pkg;
/
