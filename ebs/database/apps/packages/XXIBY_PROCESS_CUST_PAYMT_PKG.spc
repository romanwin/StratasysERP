CREATE OR REPLACE PACKAGE xxiby_process_cust_paymt_pkg /* AUTHID CURRENT_USER */ IS
  -----------------------------------------------------------------------
  --  name:               XXIBY_PROCESS_CUST_PAYMT_PKG
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Customize iPayments process to capture Token data instead of Credit Card.
  ----------------------------------------------------------------------
  --  ver  date          name            desc
  --  ---  -----------   ------------    -------------------------------
  --  1.0  17/08/2016    Sujoy Das       CHG0031464 - Customize iPayments process to capture Token data instead of Credit Card.
  --  1.1  31/08/2016    Sujoy Das       CHG0039336 - Changes in Procedure 'send_email_notification' for Refund notification.
  --                                      New Functions added 'get_merchantid','get_binvalue','get_terminalid','get_industrytype'
  --                                      New Procedures added 'send_smtp_mail'
  --  1.2  15/09/2016    Sujoy Das       CHG0039376 - Changes in below procedures/function for split shipment scenarios.
  --                                      New Functions added 'get_line_remitted_flag', 'get_line_pson', 'get_so_header_id'
  --                                      New Procedures added 'get_so_tangibleid', 'update_orb_trn_mapping', 'new_auth_orbital',
  --                                                           'cancel_void_orbital', 'cancel_full_orbital_so', 'cancel_partial_orbital_so',
  --                                                           'split_void_new_orbital_auth', 'main'
  --  1.3  12/10/2016    Sujoy Das       CHG0039481 - Changes in below procedures/function for integration with eStore.
  --                                      Updated Procedure 'set_cc_token_assignment'
  --                                      New Functions added 'g_miss_token_rec'
  --                                      New Procedures added 'get_cctoken_list', 'update_estore_pson', 'create_new_creditcard'
  -- 1.4   05.06.2017    Lingaraj(TCS)    INC0094556 -Error when sending CC receipt
  --                                      send_email_notification Parameter Data type Changed
  -- 1.7   20/09/2018    Dan Melamed     CHG0043983 - Close connections on exception
  -- 1.8   26/09/2019    Roman W.        CHG0046328 - Show connection error or credit card processor rejection reason
  --                                      JAVA change was done at :
  --                                        1. net.paymentech.servlet.CreditCardProcessingServlet
  --                                        2. net.paymentech.servlet.PlaceNewOrderServlet
  --                                        3. net.paymentech.servlet.CreditCardTranxReversalServlet
  --                                        4. net.orb.util.EBSOrbitalVoidTransact
  -- 1.9   2019/12/10    Roman W.        CHG0046663 - Show connection error
  --                                          or credit card processor rejection reason - part 2
  -- 2.0   08/07/2020    Yuval Yal       CHG0048217 - add p_source and account number parameter  
  -- 2.1   04/04/2021    Roman W.        CHG0049588 - cc 
  -----------------------------------------------------------------------
  g_rc_unknown_card           CONSTANT VARCHAR2(30) := 'UNKNOWN_CARD';
  g_channel_credit_card       CONSTANT VARCHAR2(30) := 'CREDIT_CARD';
  g_chnnl_attrib_use_required CONSTANT VARCHAR2(30) := 'REQUIRED';
  g_chnnl_attrib_use_disabled CONSTANT VARCHAR2(30) := 'DISABLED';
  g_rc_invalid_instrument     CONSTANT VARCHAR2(30) := 'INVALID_INSTRUMENT';
  g_chnnl_attrib_use_optional CONSTANT VARCHAR2(30) := 'OPTIONAL';
  g_rc_invalid_chnnl          CONSTANT VARCHAR2(30) := 'INVALID_PMT_CHANNEL';
  G_AX                        CONSTANT VARCHAR2(30) := 'AX'; -- AMEX
  G_MC                        CONSTANT VARCHAR2(30) := 'MC'; -- Master Card
  G_VI                        CONSTANT VARCHAR2(30) := 'VI'; -- Visa

  -------------------------------------
  --         Request 
  -------------------------------------
  type MFCReq is record( -- CHG0049588 - cc  
    txRefNum VARCHAR2(120),
    version  VARCHAR2(120),
    amount   VARCHAR2(120),
    orderID  VARCHAR2(120));

  type headerReq is record( -- CHG0049588 - cc  
    source     VARCHAR2(120),
    sourceId   VARCHAR2(120),
    token      VARCHAR2(120),
    bin        VARCHAR2(120),
    merchantID VARCHAR2(120),
    terminalID VARCHAR2(120),
    user       VARCHAR2(120),
    pass       VARCHAR2(120));

  type ccMFCReq is record( -- CHG0049588 - cc  
    pHeaderReq headerReq,
    pMFCReq    MFCReq);

  -------------------------------------
  --         Rsponse
  -------------------------------------
  type headerResp is record( -- CHG0049588 - cc  
    source    VARCHAR2(120),
    sourceId  VARCHAR2(120),
    isSuccess VARCHAR2(120),
    message   VARCHAR2(2000));

  type MFCResp is record( -- CHG0049588 - cc  
    procStatus           VARCHAR2(120),
    procStatusMessag     VARCHAR2(2000),
    respCode             VARCHAR2(120),
    txRefNum             VARCHAR2(120),
    approvalStatus       VARCHAR2(120),
    authorizationCode    VARCHAR2(120),
    profileProcStatus    VARCHAR2(120),
    profileProcStatusMsg VARCHAR2(2000));

  type ccMFCResp is record( -- CHG0049588 - cc  
    pHeaderResp headerResp,
    pMFCResp    MFCResp);

  -- newOrderDetailsReq --
  type markForCaptureType is record(
    --- Level 2
    l2_pCardOrderID       VARCHAR2(120),
    l2_pCardDestZip       VARCHAR2(120), -- All CardBrand
    l2_pCardDestAddress   VARCHAR2(120), -- Amex
    l2_pCardDestAddress2  VARCHAR2(120), -- Amex
    l2_pCardDestCity      VARCHAR2(120), -- Amex
    l2_pCardDestStateCd   VARCHAR2(120), -- Amex
    l2_taxInd             VARCHAR2(120), -- Amex
    l2_pCardRequestorName VARCHAR2(120), -- Amex                                     
    l2_taxAmount          VARCHAR2(120),
    
    --- Level 3
    l3_pCard3FreightAmt    VARCHAR2(120),
    l3_pCard3DutyAmt       VARCHAR2(120),
    l3_pCard3ShipFromZip   VARCHAR2(120),
    l3_pCard3DestCountryCd VARCHAR2(120),
    l3_pCard3DiscAmt       VARCHAR2(120),
    l3_pCard3VATtaxRate    VARCHAR2(120),
    l3_pCard3VATtaxAmt     VARCHAR2(120),
    l3_pCard3LineItemCount VARCHAR2(120));

  type PC3LineItemType is record(
    l3_pCard3DtlIndex    VARCHAR2(120),
    l3_pCard3DtlDesc     VARCHAR2(120),
    l3_pCard3DtlProdCd   VARCHAR2(120),
    l3_pCard3DtlUOM      VARCHAR2(120),
    l3_pCard3DtlQty      VARCHAR2(120),
    l3_pCard3DtlTaxRate  VARCHAR2(120),
    l3_pCard3DtlTaxAmt   VARCHAR2(120),
    l3_pCard3Dtllinetot  VARCHAR2(120),
    l3_pCard3DtlCommCd   VARCHAR2(120),
    l3_pCard3DtlUnitCost VARCHAR2(120),
    l3_pCard3DtlDisc     VARCHAR2(120),
    l3_pCard3DtlGrossNet VARCHAR2(120),
    l3_pCard3DtlDiscInd  VARCHAR2(120));

  --------------------------------------------
  --       DEBUG Type
  --------------------------------------------
  /* --NEW 7OCT2016
  TYPE Token_Rec_Type IS RECORD
  (
       token              VARCHAR2(100),
       instrid            NUMBER,
       card_holder_name   VARCHAR2(240),
       cc_last_four_digit VARCHAR2(4),
       card_issuer   VARCHAR2(50),
       expirydate         VARCHAR2(7)
  );
  --NEW 7OCT2016
  TYPE Token_Tbl_Type IS TABLE OF Token_Rec_Type
    INDEX BY BINARY_INTEGER;*/

  -------------------------------------------------------------------------
  --  name:               add_cc_token
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to add data into IBY_CREDITCARD table by calling API.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to add data into IBY_CREDITCARD table by calling API.
  -----------------------------------------------------------------------
  PROCEDURE add_cc_token(p_err_code    OUT NUMBER,
                         p_err_message OUT VARCHAR2,
                         ---    p_instr_id           OUT NUMBER,
                         p_owner_id           NUMBER,
                         p_card_holder_name   VARCHAR2,
                         p_billing_address_id VARCHAR2,
                         p_card_number        VARCHAR2,
                         p_expiration_date    VARCHAR2,
                         p_instrument_type    VARCHAR2,
                         p_purchasecard_flag  VARCHAR2,
                         p_card_issuer        VARCHAR2,
                         p_single_use_flag    VARCHAR2,
                         p_info_only_flag     VARCHAR2,
                         p_card_purpose       VARCHAR2,
                         p_active_flag        VARCHAR2,
                         p_cc_last4digit      VARCHAR2,
                         p_billto_contact_id  VARCHAR2);
  --------------------------------------------------------------
  --  name:               set_cc_token_assignment
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to add data into IBY_PMT_INSTR_USES_ALL table by calling API IBY_FNDCPT_SETUP_PUB.set_payer_instr_assignment.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to add data into IBY_PMT_INSTR_USES_ALL table by calling API IBY_FNDCPT_SETUP_PUB.set_payer_instr_assignment.
  --  1.1   12/10/2016    Sujoy Das       CHG0039481 - Parameter p_instrument_id is added.
  -----------------------------------------------------------------------
  PROCEDURE set_cc_token_assignment(p_err_code        OUT NUMBER,
                                    p_err_message     OUT VARCHAR2,
                                    p_party_id        NUMBER,
                                    p_cust_account_id NUMBER,
                                    p_account_site_id NUMBER,
                                    p_org_id          NUMBER,
                                    p_instrument_id   NUMBER DEFAULT NULL,
                                    p_start_date      DATE,
                                    p_end_date        DATE);
  --------------------------------------------------------------
  --  name:               get_credit_card_type
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Function to get Credit Card TYPE from Credit Card number.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Function to get Credit Card TYPE from Credit Card number.
  -----------------------------------------------------------------------
  FUNCTION get_credit_card_type(p_cc_num VARCHAR2) RETURN VARCHAR2;
  --------------------------------------------------------------
  --  name:               get_cc_detail
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to call servlet and fetch Credit Card data against Token.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to call servlet and fetch Credit Card data against Token.
  -----------------------------------------------------------------------
  PROCEDURE get_cc_detail(p_err_code                OUT NUMBER,
                          p_err_message             OUT VARCHAR2,
                          p_customerrefnum          NUMBER,
                          p_customername            OUT VARCHAR2,
                          p_ccexp                   OUT DATE,
                          p_ccaccountnum            OUT VARCHAR2,
                          p_card_type               OUT VARCHAR2,
                          p_cc_last4digit           OUT VARCHAR2,
                          p_orderdefaultdescription OUT NUMBER);
  --------------------------------------------------------------
  TYPE creditcard_rec_type IS RECORD(
    card_id                   NUMBER,
    owner_id                  NUMBER,
    card_holder_name          VARCHAR2(80),
    billing_address_id        NUMBER,
    billing_postal_code       VARCHAR2(50),
    billing_address_territory VARCHAR2(2),
    card_number               VARCHAR2(30),
    expiration_date           DATE,
    expired_flag              VARCHAR2(1),
    instrument_type           VARCHAR2(30),
    purchasecard_flag         VARCHAR2(1),
    purchasecard_subtype      VARCHAR2(30),
    card_issuer               VARCHAR2(30),
    fi_name                   VARCHAR2(80),
    single_use_flag           VARCHAR2(1),
    info_only_flag            VARCHAR2(1),
    card_purpose              VARCHAR2(30),
    card_description          VARCHAR2(240),
    active_flag               VARCHAR2(1),
    inactive_date             DATE,
    address_type              VARCHAR2(1), -- Internal to payments, defaulted to 'S'
    attribute_category        VARCHAR2(150),
    attribute1                VARCHAR2(150),
    attribute2                VARCHAR2(150),
    attribute3                VARCHAR2(150),
    attribute4                VARCHAR2(150),
    attribute5                VARCHAR2(150),
    attribute6                VARCHAR2(150),
    attribute7                VARCHAR2(150),
    attribute8                VARCHAR2(150),
    attribute9                VARCHAR2(150),
    attribute10               VARCHAR2(150),
    attribute11               VARCHAR2(150),
    attribute12               VARCHAR2(150),
    attribute13               VARCHAR2(150),
    attribute14               VARCHAR2(150),
    attribute15               VARCHAR2(150),
    attribute16               VARCHAR2(150),
    attribute17               VARCHAR2(150),
    attribute18               VARCHAR2(150),
    attribute19               VARCHAR2(150),
    attribute20               VARCHAR2(150),
    attribute21               VARCHAR2(150),
    attribute22               VARCHAR2(150),
    attribute23               VARCHAR2(150),
    attribute24               VARCHAR2(150),
    attribute25               VARCHAR2(150),
    attribute26               VARCHAR2(150),
    attribute27               VARCHAR2(150),
    attribute28               VARCHAR2(150),
    attribute29               VARCHAR2(150),
    attribute30               VARCHAR2(150),
    register_invalid_card     VARCHAR2(1) -- This parameter is used by OIE to register invalid cards
    );

  TYPE pmtchannel_attribuses_rec_type IS RECORD(
    instr_seccode_use       VARCHAR2(30),
    instr_voiceauthflag_use VARCHAR2(30),
    instr_voiceauthcode_use VARCHAR2(30),
    instr_voiceauthdate_use VARCHAR2(30),
    po_number_use           VARCHAR2(30),
    po_line_number_use      VARCHAR2(30),
    addinfo_use             VARCHAR2(30),
    instr_billing_address   VARCHAR2(30));
  --------------------------------------------------------------
  --  name:               create_card
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to create Credit Card. Taking copy from API IBY_FNDCPT_SETUP_PUB.Create_Card
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to create Credit Card. Taking copy from API IBY_FNDCPT_SETUP_PUB.Create_Card
  -----------------------------------------------------------------------
  PROCEDURE create_card(p_api_version     IN NUMBER,
                        p_init_msg_list   IN VARCHAR2 := fnd_api.g_false,
                        p_commit          IN VARCHAR2 := fnd_api.g_true,
                        x_return_status   OUT NOCOPY VARCHAR2,
                        x_msg_count       OUT NOCOPY NUMBER,
                        x_msg_data        OUT NOCOPY VARCHAR2,
                        p_card_instrument IN creditcard_rec_type,
                        x_card_id         OUT NOCOPY NUMBER,
                        x_response        OUT NOCOPY iby_fndcpt_common_pub.result_rec_type);
  --------------------------------------------------------------
  --  name:               card_exists
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to check Credit Card exist or not. Taking copy from API IBY_FNDCPT_SETUP_PUB.card_exists
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to check Credit Card exist or not. Taking copy from API IBY_FNDCPT_SETUP_PUB.card_exists
  -----------------------------------------------------------------------
  PROCEDURE card_exists(p_api_version     IN NUMBER,
                        p_init_msg_list   IN VARCHAR2 := fnd_api.g_false,
                        x_return_status   OUT NOCOPY VARCHAR2,
                        x_msg_count       OUT NOCOPY NUMBER,
                        x_msg_data        OUT NOCOPY VARCHAR2,
                        p_owner_id        NUMBER,
                        p_card_number     VARCHAR2,
                        x_card_instrument OUT NOCOPY creditcard_rec_type,
                        x_response        OUT NOCOPY iby_fndcpt_common_pub.result_rec_type,
                        p_card_instr_type IN VARCHAR2 DEFAULT NULL);
  ---------------------------------------------------------------
  --  name:               validate_cc_billing
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Function to Validates the billing address passed for a credit card instrument. Taking copy from API IBY_FNDCPT_SETUP_PUB.validate_cc_billing
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Function to Validates the billing address passed for a credit card instrument. Taking copy from API IBY_FNDCPT_SETUP_PUB.validate_cc_billing
  -----------------------------------------------------------------------
  FUNCTION validate_cc_billing(p_is_update  IN VARCHAR2,
                               p_creditcard IN creditcard_rec_type)
    RETURN BOOLEAN;
  --------------------------------------------------------------
  --  name:               get_card
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to get credit card detail. Taking copy from API IBY_FNDCPT_SETUP_PUB.get_card
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to get credit card detail. Taking copy from API IBY_FNDCPT_SETUP_PUB.get_card
  -----------------------------------------------------------------------
  PROCEDURE get_card(p_api_version     IN NUMBER,
                     p_init_msg_list   IN VARCHAR2 := fnd_api.g_false,
                     x_return_status   OUT NOCOPY VARCHAR2,
                     x_msg_count       OUT NOCOPY NUMBER,
                     x_msg_data        OUT NOCOPY VARCHAR2,
                     p_card_id         NUMBER,
                     x_card_instrument OUT NOCOPY creditcard_rec_type,
                     x_response        OUT NOCOPY iby_fndcpt_common_pub.result_rec_type);
  --------------------------------------------------------------
  --  name:               get_payment_channel_attribs
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to get payment channel detail. Taking copy from API IBY_FNDCPT_SETUP_PUB.get_payment_channel_attribs
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to get payment channel detail. Taking copy from API IBY_FNDCPT_SETUP_PUB.get_payment_channel_attribs
  -----------------------------------------------------------------------
  PROCEDURE get_payment_channel_attribs(p_api_version         IN NUMBER,
                                        p_init_msg_list       IN VARCHAR2 := fnd_api.g_false,
                                        x_return_status       OUT NOCOPY VARCHAR2,
                                        x_msg_count           OUT NOCOPY NUMBER,
                                        x_msg_data            OUT NOCOPY VARCHAR2,
                                        p_channel_code        IN VARCHAR2,
                                        x_channel_attrib_uses OUT NOCOPY pmtchannel_attribuses_rec_type,
                                        x_response            OUT NOCOPY iby_fndcpt_common_pub.result_rec_type);
  ---------------------------------------------------------------
  --  name:               send_email_notification
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to send Email Notification to customer.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to send Email Notification to customer.
  -----------------------------------------------------------------------
  PROCEDURE send_email_notification(p_err_message         OUT VARCHAR2,
                                    p_err_code            OUT NUMBER, -- INC0094556 05.06.17
                                    p_rec_date_low        IN VARCHAR2,
                                    p_rec_date_high       IN VARCHAR2,
                                    p_remit_batch         IN VARCHAR2 DEFAULT NULL,
                                    p_receipt_class       IN VARCHAR2 DEFAULT NULL,
                                    p_payment_method      IN VARCHAR2 DEFAULT NULL,
                                    p_rec_num_low         IN VARCHAR2 DEFAULT NULL,
                                    p_rec_num_high        IN VARCHAR2 DEFAULT NULL,
                                    p_customer_number     IN VARCHAR2 DEFAULT NULL,
                                    p_resend_notification IN VARCHAR2 DEFAULT 'N');

  ---------------------------------------------------------------
  --  name:               print_message
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to Print messages to output.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to Print messages to output.
  -----------------------------------------------------------------------
  PROCEDURE print_message(p_msg         VARCHAR2,
                          p_destination VARCHAR2 DEFAULT fnd_file.log);

  ---------------------------------------------------------------
  --  name:               get_orb_ccno
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to get orbital connection parameters.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to get orbital connection parameters.It is called from Java Servlet.
  -----------------------------------------------------------------------
  PROCEDURE get_orb_ccno(p_ordernumber IN VARCHAR2,
                         p_ccnumber    OUT VARCHAR2,
                         p_err_code    OUT NUMBER,
                         p_err_message OUT VARCHAR2);

  ---------------------------------------------------------------
  --  name:               get_orb_trnrefnum
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to get orbital trxn ref number.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to get orbital trxn ref number.It is called from Java Servlet.
  -----------------------------------------------------------------------
  PROCEDURE get_orb_trnrefnum(p_ordernumber IN VARCHAR2,
                              p_trnrefnum   OUT VARCHAR2,
                              p_err_code    OUT NUMBER,
                              p_err_message OUT VARCHAR2);
  ---------------------------------------------------------------
  --  name:               get_so_tangibleid
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Procedure to fetch tangibleid(PSON) from Sales Order.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Procedure to fetch tangibleid(PSON) from Sales Order.
  -----------------------------------------------------------------------
  PROCEDURE get_so_tangibleid(p_so_header_id IN OUT NUMBER, -- SO Header ID
                              p_tangibleid   IN OUT VARCHAR2, -- iby_trxn_summaries_all.TANGIBLEID
                              p_errorcode    OUT NUMBER,
                              p_error        OUT VARCHAR2);
  ---------------------------------------------------------------
  --  name:               get_so_header_id
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Function to fetch header_id from Sales Order.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Function to fetch header_id from Sales Order.
  -----------------------------------------------------------------------
  FUNCTION get_so_header_id(p_tangibleid IN VARCHAR2) RETURN NUMBER;
  ---------------------------------------------------------------
  --  name:               get_merchantid
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0031464 - Function to fetch merchantid for payee orb.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0031464 - Function to fetch merchantid for payee orb.
  -----------------------------------------------------------------------
  FUNCTION get_merchantid RETURN VARCHAR2;
  ---------------------------------------------------------------
  --  name:               get_binvalue
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0031464 - Function to fetch bin value for payee orb.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0031464 - Function to fetch bin value for payee orb.
  -----------------------------------------------------------------------
  FUNCTION get_binvalue RETURN VARCHAR2;
  ---------------------------------------------------------------
  --  name:               get_terminalid
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0031464 - Function to fetch terminalid value for payee orb.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0031464 - Function to fetch terminalid value for payee orb.
  -----------------------------------------------------------------------
  FUNCTION get_terminalid RETURN VARCHAR2;
  ---------------------------------------------------------------
  --  name:               get_industrytype
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0031464 - Function to fetch industrytype value for payee orb.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0031464 - Function to fetch industrytype value for payee orb.
  -----------------------------------------------------------------------
  FUNCTION get_industrytype RETURN VARCHAR2;
  ---------------------------------------------------------------
  --  name:               main
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      15/09/2016
  --  Purpose :           CHG0039376 - Procedure to call Full Cancel, Partial Cancel and Split Shipment processes.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/09/2016    Sujoy Das       CHG0039376 - Procedure to call Full Cancel, Partial Cancel and Split Shipment processes.
  -----------------------------------------------------------------------
  PROCEDURE main(p_errorcode OUT NUMBER, p_error OUT VARCHAR2);

  ---------------------------------------------------------------
  --  name:               insert_orb_trn_mapping
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to insert data reated to orbital.It is called from Java Servlet.
  ----------------------------------------------------------------------
  -- ver   date          name            desc
  -- ----  ------------  --------------  -------------------------------
  -- 1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to insert data reated to orbital.It is called from Java Servlet.
  -- 1.1   26/04/2021    Roman W.        CHG0049588 - cc
  -----------------------------------------------------------------------
  PROCEDURE insert_orb_trn_mapping(p_ordernumber              IN VARCHAR2,
                                   p_trnrefnum                IN VARCHAR2,
                                   p_orbital_token            IN VARCHAR2,
                                   p_ctiLevel3Eligible        IN VARCHAR2 DEFAULT NULL, -- CHG0049588
                                   p_cardBrand                IN VARCHAR2 DEFAULT NULL, -- CHG0049588
                                   p_mitReceivedTransactionID IN VARCHAR2 DEFAULT NULL, -- CHG0049588
                                   p_err_code                 OUT NUMBER,
                                   p_err_message              OUT VARCHAR2);
  ---------------------------------------------------------------
  --  name:               get_orb_req_param
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Procedure to fetch orbital related data.It is called from Java Servlet.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to fetch orbital related data.It is called from Java Servlet.
  -----------------------------------------------------------------------
  PROCEDURE get_orb_req_param(p_tangibleid  IN VARCHAR2,
                              p_option_det  OUT SYS_REFCURSOR,
                              p_err_code    OUT NUMBER,
                              p_err_message OUT VARCHAR2);
  ---------------------------------------------------------------
  --  name:               Get_Customer_Email
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - function to get customer email address whom to send credit card receipts.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - function to get customer email address whom to send credit card receipts.
  -----------------------------------------------------------------------
  FUNCTION get_customer_email(p_customer_number IN VARCHAR2,
                              p_cash_receipt_id VARCHAR2,
                              p_ibycc_attr2     VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2;
  ---------------------------------------------------------------
  --  name:               get_customer_phone
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - function to get customer phone number whom to send credit card receipts.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - function to get customer phone number whom to send credit card receipts.
  -----------------------------------------------------------------------
  FUNCTION get_customer_phone(p_customer_number IN VARCHAR2,
                              p_ibycc_attr2     VARCHAR2) RETURN VARCHAR2;
  ---------------------------------------------------------------
  --  name:               get_masked_ccnumber
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Get Masked CC Number
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Procedure to fetch orbital related data.
  -----------------------------------------------------------------------
  FUNCTION get_masked_ccnumber(p_instrument_id NUMBER) RETURN VARCHAR2;
  ---------------------------------------------------------------
  --  name:               get_ibycc_attr2
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      17/08/2016
  --  Purpose :           CHG0031464 - Get attribute2 from iby_creditcard.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   17/08/2016    Sujoy Das       CHG0031464 - Get attribute2 from iby_creditcard.
  -----------------------------------------------------------------------
  FUNCTION get_ibycc_attr2(p_instrument_id NUMBER) RETURN VARCHAR2;
  ---------------------------------------------------------------
  --  name:               send_smtp_mail
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      31/08/2016
  --  Purpose :           CHG0031464 - Procedure to send mail using SMTP.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/08/2016    Sujoy Das       CHG0031464 - Procedure to send mail using SMTP.
  --  1.1   05.06.2017    Lingaraj(TCS)   INC0094556 - Error when sending CC receipt
  -- 1.2    20/Sep/2018   Dan Melamed      CHG0043983 - Close connections on exception
  -----------------------------------------------------------------------
  PROCEDURE send_smtp_mail(p_msg_to        IN VARCHAR2,
                           p_msg_from      IN VARCHAR2,
                           p_msg_to1       IN VARCHAR2 DEFAULT NULL,
                           p_msg_to2       IN VARCHAR2 DEFAULT NULL,
                           p_msg_to3       IN VARCHAR2 DEFAULT NULL,
                           p_msg_to4       IN VARCHAR2 DEFAULT NULL,
                           p_msg_to5       IN VARCHAR2 DEFAULT NULL,
                           p_msg_subject   IN VARCHAR2,
                           p_msg_text      IN VARCHAR2 DEFAULT NULL,
                           p_msg_text_html IN CLOB /*VARCHAR2*/ DEFAULT NULL, --05.06.17 Datatype Modifiedto CLOB , INC0094556
                           p_err_code      OUT NUMBER,
                           p_err_message   OUT VARCHAR2);
  ---------------------------------------------------------------
  --  name:               get_cctoken_list
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      06-OCT-2016
  --  Purpose :           CHG0039481 - Procedure to get List of Token Information.This will be requested By eStore.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06-OCT-2016    Sujoy Das      CHG0039481 - Procedure to get List of Token Information.This will be requested By eStore.
  -- 1.1    8/7/2020      yuval tal      CHG0048217 - add p_source and account number parameter
  -----------------------------------------------------------------------
  PROCEDURE get_cctoken_list(p_source         in varchar2, --CHG0048217
                             p_pmt_type       IN VARCHAR2,
                             p_cust_acc_id    IN NUMBER,
                             p_account_number in varchar2 default null, --CHG0048217
                             p_site_id        IN NUMBER,
                             p_contact_id     IN NUMBER,
                             p_org_id         IN NUMBER DEFAULT NULL --After 12.2.4 Go Live, this may required for Cros Reference
                             --Out Parameters
                            ,
                             x_list_of_token OUT xxiby_cctoken_tab_type,
                             x_error_code    OUT VARCHAR2,
                             x_error         OUT VARCHAR2);
  ---------------------------------------------------------------
  --  name:               update_estore_pson
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      06-OCT-2016
  --  Purpose :           CHG0039481 - Procedure to Update the auto generated oracle PSON/Tangable id in Oracle IBY Tables with eStore provided PSON.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06-OCT-2016    Sujoy Das      CHG0039481 - Procedure to Update the auto generated oracle PSON/Tangable id in Oracle IBY Tables with eStore provided PSON.
  -----------------------------------------------------------------------
  PROCEDURE update_estore_pson(p_estore_pson     IN VARCHAR2, --Required
                               p_iby_trxn_ext_id IN NUMBER DEFAULT NULL,
                               p_so_header_id    IN NUMBER,
                               p_oracle_pson     IN VARCHAR2 DEFAULT NULL,
                               --Out Parameters
                               x_error_code OUT VARCHAR2,
                               x_error      OUT VARCHAR2);
  ---------------------------------------------------------------
  --  name:               create_new_creditcard
  --  create by:          Sujoy Das
  --  Revision:           1.0
  --  creation date:      06-OCT-2016
  --  Purpose :           CHG0039481 - Procedure to create CreditCard entry in IBY_CREDITCARD table. This is called from eStore side.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06-OCT-2016    Sujoy Das      CHG0039481 - Procedure to create CreditCard entry in IBY_CREDITCARD table. This is called from eStore side.
  -----------------------------------------------------------------------
  PROCEDURE create_new_creditcard(p_token               IN VARCHAR2,
                                  p_cust_number         IN VARCHAR2,
                                  p_cust_account_id     IN VARCHAR2,
                                  p_bill_to_contact_id  IN NUMBER,
                                  p_org_id              IN NUMBER,
                                  p_bill_to_site_use_id IN NUMBER
                                  --Out Parameters
                                 ,
                                  x_instr_id       OUT NUMBER,
                                  x_chname         OUT VARCHAR2,
                                  x_expiry_date    OUT DATE,
                                  x_cc_issuer_code OUT VARCHAR2,
                                  x_cc_number      OUT VARCHAR2,
                                  x_error_code     OUT VARCHAR2,
                                  x_error          OUT VARCHAR2);

  PROCEDURE new_auth_orbital(p_err_code     OUT NUMBER,
                             p_err_message  OUT VARCHAR2,
                             p_merchantid   IN VARCHAR2,
                             p_bin          IN VARCHAR2,
                             p_terminalid   IN VARCHAR2,
                             p_industrytype IN VARCHAR2,
                             p_pson         IN VARCHAR2,
                             p_auth_amount  IN NUMBER,
                             p_orb_token    IN VARCHAR2);

  --------------------------------------------------------------------------
  -- Ver     When        Who            Description
  -- ------  ----------  -------------  ------------------------------------
  -- 1.0     18/09/2019  Roman W.       CHG0046328 - Show connection error 
  --                                                 or credit card 
  --                                                 processor rejection reason
  --------------------------------------------------------------------------
  PROCEDURE get_xxiby_cc_detail_row(p_responce_clob IN CLOB,
                                    p_cc_detail     OUT xxiby_cc_detail_row_type,
                                    p_error_code    OUT NUMBER,
                                    p_error_desc    OUT VARCHAR2);

  --------------------------------------------------------------------------
  -- Ver    When        Who       Description
  -- -----  ----------  --------  ------------------------------------------
  -- 1.0    29/09/2019  Roman W.  CHG0046328
  --------------------------------------------------------------------------
  PROCEDURE get_xxiby_place_new_order_row(p_responce_clob   IN CLOB,
                                          p_place_new_order OUT xxiby_place_new_order_row_type,
                                          p_error_code      OUT NUMBER,
                                          p_error_desc      OUT VARCHAR2);

  --------------------------------------------------------------------------
  -- Ver    When        Who       Description
  -- -----  ----------  --------  ------------------------------------------
  -- 1.0    29/09/2019  Roman W.  CHG0046328
  --------------------------------------------------------------------------
  PROCEDURE get_creditcardtranxrevers_row(p_responce_clob IN CLOB,
                                          p_out_row       OUT xxiby_cc_tranx_revers_row_type,
                                          p_error_code    OUT NUMBER,
                                          p_error_desc    OUT VARCHAR2);

  ----------------------------------------------------------------------------------------------
  -- Ver     When          Who              Descr
  -- ------  ------------  ---------------  ----------------------------------------------------
  -- 1.0     2019/12/10    Roman W.         CHG0046663 - Show connection error
  --                                          or credit card processor rejection reason - part 2
  ----------------------------------------------------------------------------------------------
  PROCEDURE get_resp_code_oraauth(p_servlet_action    IN VARCHAR2, -- oraauth / oracapture / orareturn
                                  p_approval_status   IN VARCHAR2, -- ApprovalStatus
                                  p_resp_code         IN VARCHAR2, -- RespCode
                                  p_resp_code_message IN VARCHAR2, -- RespCodeMessage
                                  p_oapfstatus        OUT VARCHAR2, -- Approved - 0000 | Decline / Error - 0001
                                  p_oapfvenderrcode   OUT VARCHAR2,
                                  p_oapfvenderrmsg    OUT VARCHAR2,
                                  p_error_code        OUT VARCHAR2,
                                  p_error_desc        OUT VARCHAR2);

  ---------------------------------------------------------------------------
  -- Ver   When        Who         Descr
  -- ----  ----------  ----------  ------------------------------------------
  -- 1.0   26/04/2021  Roman W.    CHG0049588 - cc 
  ---------------------------------------------------------------------------
  procedure get_orb_cc_level(p_ordernumber              IN VARCHAR2,
                             p_ctiLevel3Eligible        OUT VARCHAR2,
                             p_cardBrand                OUT VARCHAR2,
                             p_mitreceivedtransactionid OUT VARCHAR2,
                             p_error_code               OUT VARCHAR2,
                             p_error_desc               OUT VARCHAR2);

  ------------------------
  -- CC procedures 
  -- calling oic services 
  ---------------------------
  PROCEDURE cc_new_order(p_req      IN VARCHAR2,
                         p_resp     OUT VARCHAR2,
                         p_err_code OUT VARCHAR2,
                         p_err_msg  OUT VARCHAR2);

  --------------------------------------------------------------------------
  -- Ver   When         Who         Descr 
  -- ----  -----------  ----------  ----------------------------------------
  -- 1.0   06/04/2021   Roman W.    CHG0049588 - cc  
  --------------------------------------------------------------------------
  PROCEDURE cc_mfc(p_req      IN CLOB,
                   p_resp     OUT CLOB,
                   p_err_code OUT VARCHAR2,
                   p_err_msg  OUT VARCHAR2);

  --------------------------------------------------------------------------
  -- Ver   When         Who         Descr 
  -- ----  -----------  ----------  ----------------------------------------
  -- 1.0   06/04/2021   Roman W.    CHG0049588 - cc  
  --------------------------------------------------------------------------
  PROCEDURE cc_reversal(p_merchantid    IN VARCHAR2,
                        p_bin           IN VARCHAR2,
                        p_terminalid    IN VARCHAR2,
                        p_pson          IN VARCHAR2,
                        p_cancel_amount IN NUMBER,
                        p_txrefnum      IN VARCHAR2,
                        p_err_code      OUT VARCHAR2,
                        p_err_msg       OUT VARCHAR2);

  PROCEDURE cc_profile_fetch(p_customerrefnum IN NUMBER, --Use Token Value here
                             p_resp           OUT CLOB,
                             p_err_code       OUT VARCHAR2,
                             p_err_msg        OUT VARCHAR2,
                             p_customername   OUT VARCHAR2, --from XML response
                             p_ccexp          OUT DATE, --from XML response
                             p_ccaccountnum   OUT VARCHAR2, --from XML response
                             p_card_type      OUT VARCHAR2, --from XML response 
                             p_cc_last4digit  OUT VARCHAR2 --from XML response 
                             );

  --------------------------------------------------------------------------
  -- Ver    When         Who          Descr 
  -- -----  -----------  ----------   --------------------------------------
  -- 1.0    2021/04/04   Roman W.     CHG0049588 - cc 
  --------------------------------------------------------------------------
  procedure parse_ccMFCReq_json_request(p_json       IN VARCHAR2,
                                        p_ccMFCReq   OUT ccMFCReq,
                                        p_error_code OUT VARCHAR2,
                                        p_error_desc OUT VARCHAR2);

  ------------------------------------------------------------------------
  -- Ver   When         Who          Descr 
  -- ----  -----------  -----------  -------------------------------------
  -- 1.0   29/04/2021   Roman W.     CHG0049588 - cc
  ------------------------------------------------------------------------
  function get_mfc_error_responce_json(p_error_desc VARCHAR2) return varchar2;

  --------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  ---------------------------------------
  -- 1.0   04/04/2021   Roman W.     CHG0049588 - cc 
  --------------------------------------------------------------------------
  function get_mfc_responce_json(p_ccMFCResp ccMFCResp) return VARCHAR2;

  ------------------------------------------------------------------------
  -- Ver   When         Who          Descr 
  -- ----  -----------  -----------  -------------------------------------
  -- 1.0   29/04/2021   Roman W.     CHG0049588 - cc
  ------------------------------------------------------------------------
  function get_mfc_responce_json(p_resp VARCHAR2) return VARCHAR2;

  --------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  ---------------------------------------
  -- 1.0   04/04/2021   Roman W.     CHG0049588 - cc
  --------------------------------------------------------------------------
  procedure get_mfc_request_json(p_ccMFCReq         IN ccMFCReq,
                                 p_out_json_request OUT VARCHAR2,
                                 p_error_code       OUT VARCHAR2,
                                 p_error_desc       OUT VARCHAR2);

  --------------------------------------------------------------------------
  -- Ver   When         Who        Descr 
  -- ----  -----------  ---------  -----------------------------------------
  -- 1.0   05/04/2021   Roman W.   CHG0049588 - cc 
  --------------------------------------------------------------------------
  procedure parse_ccMFCResp_json_responce(p_json       IN VARCHAR2,
                                          p_ccMFCResp  OUT ccMFCResp,
                                          p_error_code OUT VARCHAR2,
                                          p_error_desc OUT VARCHAR2);

  ---------------------------------------------------------------------------
  -- Ver   When         Who           Descr 
  -- ----  -----------  ------------  ---------------------------------------
  -- 1.0   13/04/2021   Roman W.      CHG0049588 - cc 
  ---------------------------------------------------------------------------
  function get_ccNewOrderResp_err_json(p_orderID          IN VARCHAR2,
                                       p_sourceId         IN VARCHAR2,
                                       p_procStatusMessag IN VARCHAR2)
    return VARCHAR2;

  ---------------------------------------------------------------------------
  -- Ver   When         Who           Descr 
  -- ----  -----------  ------------  ---------------------------------------
  -- 1.0   13/04/2021   Roman W.      CHG0049588 - cc 
  ---------------------------------------------------------------------------
  procedure parse_ccNewOrderResp_json_resp(p_responceIn  IN VARCHAR2,
                                           p_responceOut OUT VARCHAR2,
                                           p_error_code  OUT VARCHAR2,
                                           p_error_desc  OUT VARCHAR2);

  ------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ---------  --------------------------------------
  -- 1.0   2021/04/20   Roman W.   CHG0049588 - cc  
  ------------------------------------------------------------------------
  procedure debug(p_msg        IN VARCHAR2,
                  p_error_code OUT VARCHAR2,
                  p_error_desc OUT VARCHAR2);
  ---------------------------------------------------------------------------
  -- Ver   When        Who         Descr
  -- ----  ----------  ----------  ------------------------------------------
  -- 1.0   07/04/2021  Roman W.    CHG0049588 - cc 
  ---------------------------------------------------------------------------
  procedure debug(p_xxiby_cc_debug_tbl IN OUT xxiby_cc_debug_tbl%rowtype,
                  p_error_code         OUT VARCHAR2,
                  p_error_desc         OUT VARCHAR2);

  -------------------------------------------------------------------------------
  -- Ver   When         Who           Descr
  -- ----  -----------  ------------  -------------------------------------------  
  -- 1.0   08/06/2021   Roman W.      CHG0049588 -Credit Card Chase Payment 
  --                                     - add data required for level 2 and 3   
  -------------------------------------------------------------------------------
  procedure validate_markForCaptureType(p_cardbrand          IN VARCHAR2,
                                        p_markForCaptureType IN OUT markForCaptureType,
                                        p_error_code         OUT VARCHAR2,
                                        p_error_desc         OUT VARCHAR2);

  -------------------------------------------------------------------------------
  -- Ver   When         Who           Descr
  -- ----  -----------  ------------  -------------------------------------------  
  -- 1.0   08/06/2021   Roman W.      CHG0049588 -Credit Card Chase Payment 
  --                                     - add data required for level 2 and 3   
  -------------------------------------------------------------------------------  
  procedure validate_PC3LineItemType(p_cardbrand       IN VARCHAR2,
                                     p_PC3LineItemType IN OUT PC3LineItemType,
                                     p_error_code      OUT VARCHAR2,
                                     p_error_desc      OUT VARCHAR2);

  -------------------------------------------------------------------------------
  -- Ver   When         Who         Descr 
  -- ----  -----------  ----------  ---------------------------------------------
  -- 1.0   22/04/2021   Roman W.    CHG0049588 -Credit Card Chase Payment 
  --                                     - add data required for level 2 and 3   
  -------------------------------------------------------------------------------
  procedure get_l2_l3_json(p_orderID    IN VARCHAR2,
                           p_out_json   OUT VARCHAR2,
                           p_error_code OUT VARCHAR2,
                           p_error_desc OUT VARCHAR2);

  --------------------------------------------------------------------
  -- Ver   When        Who         Descr
  -- ----  ----------  ----------  -----------------------------------
  -- 1.0   13/05/2021  Roman W.    CHG0049588 - cc 
  --------------------------------------------------------------------
  function get_industry_type return VARCHAR2;

  ---------------------------------------------------------------------
  -- Ver   When         Who            Descr 
  -- ----  -----------  -------------  --------------------------------
  -- 1.0   20/05/2021   Roman W.       CHG0049588 - cc   
  ---------------------------------------------------------------------
  procedure get_ccExp(p_order_id   IN VARCHAR2,
                      p_ccExp      OUT VARCHAR2,
                      p_error_code OUT VARCHAR,
                      p_error_desc OUT VARCHAR);

END xxiby_process_cust_paymt_pkg;
/
