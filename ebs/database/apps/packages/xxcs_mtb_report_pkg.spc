CREATE OR REPLACE PACKAGE xxcs_mtb_report_pkg IS
   function get_factor_for_sr_statistics(p_report_date_from          in DATE,
                                         p_report_date_to            in DATE,
                                         p_printer_install_date      in DATE,
                                         p_printer_activity_end_date in DATE) return number;
   function get_counter_reading(p_date  in DATE,
                                p_printer_serial_number in VARCHAR2) return number;
   function get_last_counter_reading(p_printer_serial_number in VARCHAR2) return number;
   function convert_duration_uom(p_from_uom  in VARCHAR2,
                                 p_to_uom    in VARCHAR2,
                                 p_duration in NUMBER) return number;
   function get_item_cost(p_inventory_organization_id  IN NUMBER,
                          p_inventory_item_id          IN NUMBER,
                          p_precision                  IN NUMBER,
                          p_from_quantity              IN NUMBER,
                          p_from_uom                   IN VARCHAR2) return number;
   function get_workdays(p_org_id     IN NUMBER,
                         p_date_from  IN DATE,
                         p_date_to    IN DATE) return number;
END xxcs_mtb_report_pkg;
/

