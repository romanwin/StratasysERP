create or replace package XXWSH_SHIP_FORWARDER_INFO is
  
--------------------------------------------------------------------
--  customization code: CUST283
--  name:               XXWSH_SHIP_FORWARDER_INFO
--  create by:          Dalit A. Raviv
--  $Revision:          1.0 $
--  creation date:      09/03/2010
--  Purpose :           The customization will be comprise of two parts, 
--                      one as a development of a personalized screen, 
--                      and the other of an upload program to populate 
--                      the screen with the relevant information from 
--                      an excel file. 
----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   09/03/2010    Dalit A. Raviv  initial build
----------------------------------------------------------------------- 
   
  -- variable from type record for the insert 
  TYPE shipping_details_rec_type IS RECORD (entity_id              number,
                                            delivery_name          varchar2(30),
                                            carrier_name           varchar2(360),
                                            freight_terms_code     varchar2(30),
                                            ship_method_meaning    varchar2(80),
                                            territory_short_name   varchar2(80),
                                            awb                    varchar2(150),
                                            mawb                   varchar2(150),
                                            pick_up_date           date,
                                            flight_1_number        varchar2(150),
                                            flight_1_date          date,
                                            flight_2_number        varchar2(150),
                                            flight_2_date          date,
                                            pod_date               date,
                                            pod_name               varchar2(150),
                                            invoice_number         varchar2(150),
                                            invoice_date           date, 
                                            local_charges          number,
                                            local_charges_orig     number,
                                            flight_charges         number,
                                            flight_charges_orig    number,
                                            fhd_cost               number,
                                            fhd_cost_orig          number,
                                            other                  number,
                                            other_orig             number,
                                            total_invoice          number,
                                            total_invoice_orig     number,
                                            reshimon_number        number,
                                            reshimon_date          date,
                                            ship_from_org          varchar2(3),
                                            delivery_charge_weight number,
                                            invoice_tot_weight     number,
                                            attribute1             varchar2(240),
                                            attribute2             varchar2(240),
                                            attribute3             varchar2(240),
                                            attribute4             varchar2(240),
                                            attribute5             varchar2(240));
                                            
  /*TYPE delivery_data_rec_type IS RECORD    (delivery_name        varchar2(30),
                                            chargable_weight     number);
  
  TYPE delivery_data_tbl_type IS TABLE OF delivery_data_rec_type
  INDEX BY BINARY_INTEGER;   */                                         

  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               populate_table
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      09/03/2010
  --  Purpose :           Upload program - Using by BPEL
  --                      * If no data exist for the given Invoice_number - update 
  --                        that line to the Table
  --                      * If the is information for a given delivery but there is 
  --                        a different invoice_number then add the line to the table 
  --                      * If an invoice_number already exist in the table then stop  
  --                        the upload with the error indicating the invoice_number
  --                      * If a field does not pass validation, stop the upload with
  --                        the error indicating the non validated field.      
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   09/03/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  --Procedure populate_table;
  
  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               parse_line
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      09/03/2010
  --  Purpose :           get string of concatenated delivery numbers deliminate by
  --                      ':' (111:222:333) 
  --                      return delivery (111) to enter
  --                      and out param of the "left string" - (222:333) 
  --                          out param of the place found                                             
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   09/03/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  function parse_line (p_string    in  varchar2,
                       p_new_str   out varchar2,
                       p_place     out number) return varchar2;
                       
  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               ins_xxwsh_shipping_details
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      09/03/2010
  --  Purpose :           insert row to xxwsh_shipping_details table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   09/03/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  procedure ins_xxwsh_shipping_details (p_shipping_details_rec in  shipping_details_rec_type,
                                        p_error_code           out number,
                                        p_error_desc           out varchar2);                       
  
  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               Call_Bpel_Process
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      16/03/2010
  --  Purpose :           procedure that will call from concurrent program
  --                      and will start BPEL process - XXWSHForwarderProcessRequest
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16/03/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  Procedure Call_Bpel_Process(errbuf   out varchar2,
                              retcode  out varchar2);
  
  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               get_invoice_tot_weight
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/03/2010
  --  Purpose :           procedure that get string of deliveries 111:2222:333 
  --                      will parse it and enter to tbl variable
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/03/2010    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------                             
  function  get_invoice_tot_weight (p_delivery_str in  varchar2,
                                    p_error_code   out number,
                                    p_error_desc   out varchar2) return number;
                                  
  --------------------------------------------------------------------
  --  customization code: CUST283
  --  name:               get_chargable_weight
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      21/03/2010
  --  Purpose :           Function that calculate chargable weight per delivery
  --                      reference Packing list report (field chargable weight)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/03/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  function get_chargable_weight (P_delivery_name in varchar2) return number;                                                             
                              
end XXWSH_SHIP_FORWARDER_INFO;
/

