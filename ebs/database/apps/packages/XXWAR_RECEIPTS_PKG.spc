CREATE OR REPLACE PACKAGE xxwar_receipts_pkg
AS
/*****************************************************************************************
 * $Header$                                                                       		 *
 * Program Name : XXWAR_RECEIPTS_PKG.pkb                                           	     *
 * Language     : PL/SQL                                                           		 *
 * Description  : This package has the following procedures                        		 *
 *                  1. submit_lockbox                                              		 *
 *                     Submits the Lockbox Program in new transmission mode        		 *
 *                     with submit import ; submit validation and submit           		 *
 *                     post quick cash as "YES"                                          *
 *                  2. conc_stat_and_adj_creation                                        *
 *                     Get the Phase sand Status of the concurrent request               *
 *                     and call the private procedure create_adjustment, if              *
 *                     payment method is ACH-CTX                                         *
 *                                                                                       *
 *                                                                                       *
 * History      :                                                                        *
 *                                                                                       *
 * WHO            Version       WHAT                                     WHEN            *
 *--------------- -------  ---------------------------------------     -------------     *
 * Raguraman K    1.0   	Original version.                      		12-May-2008      *
 * Raguraman K    1.1   	Modified.xxwar_lbx_derive_rcpt_num                        	 *
 *                   		to derive the receipt number for LBX                      	 *
 * Raguraman K    1.2   	Addition function to derive receipt                       	 *
 *                   		number for LBX, ACH and DTD                               	 *
 *                                                                             			 *
 * Ujjwala Meka   1.3   	Added function  xxwar_validate_invoice                       *
 *                  		to validate the invoice                                      *
 * Kalyan G       1.4    	Issue#64649 Added new function          	10-Feb-2011      *
 *                  		xxwar_validate_customer                                      *
 * Kalyan G       1.5  		Issue:65174 added new function          	09-Mar-2011      *
 *                  		xxwar_get_invoice_amt to get amount                          *
 *                  		based on invoice number status in ERP                        *
 * Kalyan G       1.6  		Enhancement#65531:xxwar_dtd_derive_rcpt_num 24-Mar-2011      *
 *                  		function parameter modified                                  *
 * Sudheer 		  1.7  		Enhancement#ENH72, Patch #8443 ACH Non-CTX  05-Mar-2013      *
 *                 		    Receipts  for Identifying Customer Number                    *
 *                          based on Originator Company ID                               *
 *****************************************************************************************
 * Stratasys - Version Control
 ******************************************************************************************
 * Venu Kandi     3.0      CR 1312 - Tech Log 209 - Initial Creation              24-Feb-2014   * 
 ****************************************************************************************
 */
  g_lbx_request_id     NUMBER;
  g_process_status     VARCHAR2 (2) ;
  g_error_string       VARCHAR2 (32000) ;
  g_adj_creation_flag  VARCHAR2 (1) ;
  g_data_fetch_flag    VARCHAR2 (1) ;
  g_error_type         VARCHAR2(40);
  g_trans_name         VARCHAR2(50);

PROCEDURE submit_lockbox
  (
    p_user_name                IN VARCHAR2,
    p_resp_name                IN VARCHAR2,
    p_batch_hdr_id             IN VARCHAR2,
    p_lockbox_file_id          IN VARCHAR2,
    p_datafile_path_name       IN VARCHAR2,
    p_controlfile_name         IN VARCHAR2,
    p_transmission_format_name IN VARCHAR2,
    p_lockbox_number           IN VARCHAR2,
    p_organization_name        IN VARCHAR2,
    p_data_fetch_flag          IN VARCHAR2,
    p_auto_adjustments_flag    IN VARCHAR2,
    p_request_id               IN OUT NUMBER,
    p_process_status           IN OUT NUMBER,
    p_parent_request_id        OUT NUMBER,
    p_error_string             OUT VARCHAR2,
    p_error_type               OUT VARCHAR2,
    p_error_count              OUT NUMBER,
    p_transmission_name        OUT VARCHAR2,
    p_parent_logfile           OUT VARCHAR2,
    p_logfile                  OUT VARCHAR2,
    p_outfile                  OUT VARCHAR2,
	p_email_ids                OUT VARCHAR2);

PROCEDURE submit_lockbox_pvt
     (x_errbuf                   OUT       VARCHAR2,
      x_retcode                  OUT       VARCHAR2,
      p_batch_hdr_id             IN        VARCHAR2,
      p_lockbox_file_id          IN        VARCHAR2,
      p_datafile_path_name       IN        VARCHAR2,
      p_controlfile_name         IN        VARCHAR2,
      p_transmission_format_name IN        VARCHAR2,
      p_lockbox_number           IN        VARCHAR2,
      p_organization_name        IN        VARCHAR2,
      p_data_fetch_flag          IN        VARCHAR2,
      p_auto_adjustments_flag    IN        VARCHAR2,
      p_process_status           IN        NUMBER,
      p_request_id               IN        NUMBER
     );

PROCEDURE print_out(p_print_msg VARCHAR2);

PROCEDURE print_log  (p_print_msg VARCHAR2);

PROCEDURE load_custom_data
            ( p_lbx_file_id IN VARCHAR2,
			  p_payment_rec_id IN NUMBER DEFAULT NULL,
			  p_inv_trfmd_rec_id IN NUMBER DEFAULT NULL,
              x_return_status OUT VARCHAR2,
              x_error_msg OUT VARCHAR2);

PROCEDURE load_custom_data
              (errbuf               OUT        VARCHAR2,
               retcode              OUT        NUMBER,
               p_batch_name         IN         VARCHAR2
              );

PROCEDURE create_adjustment
            ( p_lockbox_file_id IN VARCHAR2,
              p_org_id IN NUMBER,
              x_adjst_creation_status OUT VARCHAR2
             );

PROCEDURE create_adjustment
              (errbuf        OUT  VARCHAR2,
               retcode       OUT  VARCHAR2,
               p_batch_name IN VARCHAR2
              );
 PROCEDURE update_adjustment
             (p_adj_hdr_id         IN  NUMBER,
              p_adj_error          IN  VARCHAR2,
              p_status             IN  VARCHAR2,
              p_base_table_adj_id  IN  NUMBER
             );

PROCEDURE update_batch_stg
              (p_lockbox_file_id    IN  NUMBER,
               p_status             IN  NUMBER
              );
FUNCTION xxwar_derive_inv_amt (p_invoice_rec_id NUMBER, p_amt_paid NUMBER)
      RETURN NUMBER;

FUNCTION xxwar_get_receipt_date (p_invoice_rec_id NUMBER)
     RETURN DATE;
FUNCTION xxwar_dtd_get_receipt_date (p_invoice_rec_id NUMBER)
     RETURN DATE;
FUNCTION xxwar_lbx_derive_rcpt_num (p_payment_rec_id NUMBER)
     RETURN VARCHAR2;

   /*Below Functions were added by Raguraman, 10-OCT-2008 for phase 2 */
FUNCTION xxwar_ach_derive_rcpt_num (p_payment_rec_id NUMBER)
RETURN VARCHAR2;

FUNCTION xxwar_dtd_comments (p_string VARCHAR2)  --Enhancement#65531
RETURN VARCHAR2;

/*commented for Enhancement#65531 new function with same name is added below.
FUNCTION xxwar_dtd_derive_rcpt_num (p_invoice_rec_id NUMBER)
     RETURN VARCHAR2;*/
FUNCTION xxwar_dtd_derive_rcpt_num (p_check_num VARCHAR2)  --Enhancement#65531
     RETURN VARCHAR2;
FUNCTION xxwar_lbx_derive_batch_num (p_payment_rec_id NUMBER)
     RETURN VARCHAR2;
FUNCTION xxwar_dtd_misc_derive_rcpt_num (p_invoice_rec_id NUMBER)
      RETURN VARCHAR2;

FUNCTION xxwar_validate_invoice (p_invoice_rec_id NUMBER)
     RETURN VARCHAR2;
	 Procedure misc_receipts(
    p_user_name                IN VARCHAR2,
    p_resp_name                IN VARCHAR2,
	p_lockbox_file_id          IN NUMBER,
	p_organization_name        IN VARCHAR2,
	p_receipts_created         OUT NUMBER,
	p_receipts_failed          OUT NUMBER,
	p_logfile                 OUT VARCHAR2,
	p_outfile                 OUT VARCHAR2,
	p_error_string            OUT VARCHAR2,
    p_error_count               OUT NUMBER,
	p_process_status          OUT NUMBER,
    p_email_ids               OUT VARCHAR2,
    p_error_type              OUT VARCHAR2
	);

PROCEDURE misc_receipts_pvt(
                         x_errbuf             OUT VARCHAR2
                        ,x_retcode            OUT VARCHAR2
                        ,p_organization_name  IN VARCHAR2
						,p_lockbox_file_id    IN  NUMBER
                        ,p_payment_type       IN VARCHAR2
                       	);
PROCEDURE batch_receipts_details(
                          x_errbuf             OUT VARCHAR2
                         ,x_retcode            OUT VARCHAR2
						 ,p_org_id              IN NUMBER
						 ,p_date                IN DATE
						 ,p_receipt_method      IN VARCHAR2
                       	);

FUNCTION xxwar_format_utility (p_ip_string      VARCHAR2,
                               p_line_width     NUMBER)
RETURN VARCHAR2;

FUNCTION xxwar_validate_customer (p_cust_num VARCHAR2)    -- Issue#64649
RETURN VARCHAR2;

FUNCTION xxwar_get_invoice_amt (p_invoice_rec_id NUMBER)   -- Issue:65174
RETURN NUMBER;

FUNCTION xxwar_get_invoice_rec_id (p_string VARCHAR2)
RETURN VARCHAR2;

/* Function added for #ENH72 */
/*   This Function will fetch the Customer Number and Customer Name by passsing Originator Company Id from
	 the lookup XXWAR_CUST_ACH_COMPID_MAP so that, the receipt will be created with 'Applied' status with
	  proper customer details. */
FUNCTION XXWAR_VALIDATE_CUSTOMER_ACH(P_ORIGINATOR_COMPANY_ID VARCHAR2)
RETURN VARCHAR2;
/* Function Ended for #ENH72 */

END xxwar_receipts_pkg;
/
