CREATE OR REPLACE PACKAGE xxpo_notification_attr_pkg IS

   -- Author  : ELLA.MALCHI
   -- Created : 2009-09-21 15:00:47
   -- Purpose : Add notification attributes

   -- Public type declarations
   FUNCTION get_requisition_justifications(p_po_line_id NUMBER)
      RETURN VARCHAR2;
   FUNCTION get_requisition_justifications(p_req_line_id   NUMBER,
                                           p_currency_code VARCHAR2)
      RETURN VARCHAR2;
   PRAGMA RESTRICT_REFERENCES(get_requisition_justifications, WNDS, WNPS);

   FUNCTION get_requisition_requestors(p_po_line_id NUMBER) RETURN VARCHAR2;
   FUNCTION get_requisition_requestors(p_req_line_id   NUMBER,
                                       p_currency_code VARCHAR2)
      RETURN VARCHAR2;
   PRAGMA RESTRICT_REFERENCES(get_requisition_requestors, WNDS, WNPS);

   PROCEDURE get_po_distributions_details(document_id   IN VARCHAR2,
                                          display_type  IN VARCHAR2,
                                          document      IN OUT NOCOPY CLOB, -- <BUG 7006113>
                                          document_type IN OUT NOCOPY VARCHAR2);

   PROCEDURE get_po_lines_details(document_id   IN VARCHAR2,
                                  display_type  IN VARCHAR2,
                                  document      IN OUT NOCOPY CLOB, -- <BUG 7006113>
                                  document_type IN OUT NOCOPY VARCHAR2);

END xxpo_notification_attr_pkg;
/

