CREATE OR REPLACE TRIGGER XXOKC_K_HEADERS_ALL_B_AIU_TRG
--------------------------------------------------------------------------------------------------
--  name:              XXOKC_K_HEADERS_ALL_B_AIU_TRG
--  create by:         Lingaraj Sarangi
--  Revision:          1.0
--  creation date:     10-May-2018
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0042873 - Service Contract interface - Oracle 2 SFDC
--                                   trigger on OKC_K_HEADERS_ALL_B
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   10-May-2018   Lingaraj Sarangi           CHG0042873 - Service Contract interface - Oracle 2 SFDC
--------------------------------------------------------------------------------------------------
AFTER INSERT OR UPDATE  ON "OKC"."OKC_K_HEADERS_ALL_B"
FOR EACH ROW

when(NEW.STS_CODE != 'ENTERED')
DECLARE
  l_trigger_name    VARCHAR2(50)   := 'XXOKC_K_HEADERS_ALL_B_AIU_TRG';
  l_error_message   VARCHAR2(500)  := '';
  l_old_okc_h_rec   okc.okc_k_headers_all_b%ROWTYPE;
  l_new_okc_h_rec   okc.okc_k_headers_all_b%ROWTYPE;
  l_trigger_action  VARCHAR2(10) := '';
BEGIN

  IF INSERTING THEN
     l_trigger_action := 'INSERT';
  ELSIF UPDATING THEN
     l_trigger_action := 'UPDATE';
  END IF;

  -----------------------------------------------------------
  -- Old Column Values Before Update
  -----------------------------------------------------------
  IF UPDATING THEN

	l_old_okc_h_rec.id:= :OLD.id;
	l_old_okc_h_rec.contract_number			 := :OLD.contract_number;
	l_old_okc_h_rec.authoring_org_id		 := :OLD.authoring_org_id;
	l_old_okc_h_rec.contract_number_modifier := :OLD.contract_number_modifier;
	l_old_okc_h_rec.chr_id_response			 := :OLD.chr_id_response;
	l_old_okc_h_rec.chr_id_award		   	 := :OLD.chr_id_award;
	l_old_okc_h_rec.chr_id_renewed           := :OLD.chr_id_renewed;
	l_old_okc_h_rec.inv_organization_id      := :OLD.inv_organization_id;
	l_old_okc_h_rec.sts_code                 := :OLD.sts_code;
	l_old_okc_h_rec.qcl_id					 := :OLD.qcl_id;
	l_old_okc_h_rec.scs_code				 := :OLD.scs_code;
	l_old_okc_h_rec.trn_code				 := :OLD.trn_code;
	l_old_okc_h_rec.currency_code            := :OLD.currency_code;
	l_old_okc_h_rec.archived_yn				 := :OLD.archived_yn;
	l_old_okc_h_rec.deleted_yn			     := :OLD.deleted_yn;
	l_old_okc_h_rec.template_yn	             := :OLD.template_yn;
	l_old_okc_h_rec.chr_type		         := :OLD.chr_type;
	l_old_okc_h_rec.object_version_number	 := :OLD.object_version_number;
	l_old_okc_h_rec.created_by				 := :OLD.created_by;
	l_old_okc_h_rec.creation_date		     := :OLD.creation_date;
	l_old_okc_h_rec.last_updated_by			 := :OLD.last_updated_by;
	l_old_okc_h_rec.cust_po_number_req_yn    := :OLD.cust_po_number_req_yn;
	l_old_okc_h_rec.pre_pay_req_yn 			 := :OLD.pre_pay_req_yn;
	l_old_okc_h_rec.cust_po_number  		 := :OLD.cust_po_number;
	l_old_okc_h_rec.dpas_rating				 := :OLD.dpas_rating;
	l_old_okc_h_rec.template_used			 := :OLD.template_used;
	l_old_okc_h_rec.date_approved			 := :OLD.date_approved;
	l_old_okc_h_rec.datetime_cancelled		 := :OLD.datetime_cancelled;
	l_old_okc_h_rec.auto_renew_days			 := :OLD.auto_renew_days;
	l_old_okc_h_rec.date_issued              := :OLD.date_issued;
	l_old_okc_h_rec.datetime_responded    	 := :OLD.datetime_responded;
	l_old_okc_h_rec.rfp_type  			     := :OLD.rfp_type;
	l_old_okc_h_rec.keep_on_mail_list 		 := :OLD.keep_on_mail_list;
	l_old_okc_h_rec.set_aside_percent	     := :OLD.set_aside_percent;
	l_old_okc_h_rec.response_copies_req		 := :OLD.response_copies_req;
	l_old_okc_h_rec.date_close_projected	 := :OLD.date_close_projected;
	l_old_okc_h_rec.datetime_proposed	     := :OLD.datetime_proposed;
	l_old_okc_h_rec.date_signed				 := :OLD.date_signed;
	l_old_okc_h_rec.date_terminated			 := :OLD.date_terminated;
	l_old_okc_h_rec.date_renewed		     := :OLD.date_renewed;
	l_old_okc_h_rec.start_date				 := :OLD.start_date;
	l_old_okc_h_rec.end_date			     := :OLD.end_date;
	l_old_okc_h_rec.buy_or_sell			     := :OLD.buy_or_sell;
	l_old_okc_h_rec.issue_or_receive		 := :OLD.issue_or_receive;
	l_old_okc_h_rec.last_update_login		 := :OLD.last_update_login;
	l_old_okc_h_rec.estimated_amount		 := :OLD.estimated_amount;
	l_old_okc_h_rec.attribute_category	     := :OLD.attribute_category;
	l_old_okc_h_rec.last_update_date	     := :OLD.last_update_date;
	l_old_okc_h_rec.attribute1				 := :OLD.attribute1;
	l_old_okc_h_rec.attribute2				 := :OLD.attribute2;
	l_old_okc_h_rec.attribute3				 := :OLD.attribute3;
	l_old_okc_h_rec.attribute4				 := :OLD.attribute4;
	l_old_okc_h_rec.attribute5				 := :OLD.attribute5;
	l_old_okc_h_rec.attribute6				 := :OLD.attribute6;
	l_old_okc_h_rec.attribute7			     := :OLD.attribute7;
	l_old_okc_h_rec.attribute8			     := :OLD.attribute8;
	l_old_okc_h_rec.attribute9				 := :OLD.attribute9;
	l_old_okc_h_rec.attribute10				 := :OLD.attribute10;
	l_old_okc_h_rec.attribute11				 := :OLD.attribute11;
	l_old_okc_h_rec.attribute12				 := :OLD.attribute12;
	l_old_okc_h_rec.attribute13				 := :OLD.attribute13;
	l_old_okc_h_rec.attribute14				 := :OLD.attribute14;
	l_old_okc_h_rec.attribute15				 := :OLD.attribute15;
	l_old_okc_h_rec.security_group_id		 := :OLD.security_group_id;
	l_old_okc_h_rec.chr_id_renewed_to		 := :OLD.chr_id_renewed_to;
	l_old_okc_h_rec.estimated_amount_renewed := :OLD.estimated_amount_renewed;
	l_old_okc_h_rec.currency_code_renewed    := :OLD.currency_code_renewed;
	l_old_okc_h_rec.upg_orig_system_ref      := :OLD.upg_orig_system_ref;
	l_old_okc_h_rec.upg_orig_system_ref_id   := :OLD.upg_orig_system_ref_id;
	l_old_okc_h_rec.application_id           := :OLD.application_id;
	l_old_okc_h_rec.resolved_until           := :OLD.resolved_until;
	l_old_okc_h_rec.orig_system_source_code  := :OLD.orig_system_source_code;
	l_old_okc_h_rec.orig_system_id1          := :OLD.orig_system_id1;
	l_old_okc_h_rec.orig_system_reference1   := :OLD.orig_system_reference1;
	l_old_okc_h_rec.program_application_id   := :OLD.program_application_id;
	l_old_okc_h_rec.program_id               := :OLD.program_id;
	l_old_okc_h_rec.program_update_date      := :OLD.program_update_date;
	l_old_okc_h_rec.request_id               := :OLD.request_id;
	l_old_okc_h_rec.price_list_id            := :OLD.price_list_id;
	l_old_okc_h_rec.pricing_date             := :OLD.pricing_date;
	l_old_okc_h_rec.total_line_list_price    := :OLD.total_line_list_price;
	l_old_okc_h_rec.sign_by_date             := :OLD.sign_by_date;
	l_old_okc_h_rec.user_estimated_amount    := :OLD.user_estimated_amount;
	l_old_okc_h_rec.governing_contract_yn    := :OLD.governing_contract_yn;
	l_old_okc_h_rec.document_id              := :OLD.document_id;
	l_old_okc_h_rec.conversion_type          := :OLD.conversion_type;
	l_old_okc_h_rec.conversion_rate          := :OLD.conversion_rate;
	l_old_okc_h_rec.conversion_rate_date     := :OLD.conversion_rate_date;
	l_old_okc_h_rec.conversion_euro_rate     := :OLD.conversion_euro_rate;
	l_old_okc_h_rec.cust_acct_id             := :OLD.cust_acct_id;
	l_old_okc_h_rec.bill_to_site_use_id      := :OLD.bill_to_site_use_id;
	l_old_okc_h_rec.inv_rule_id              := :OLD.inv_rule_id;
	l_old_okc_h_rec.renewal_type_code        := :OLD.renewal_type_code;
	l_old_okc_h_rec.renewal_notify_to        := :OLD.renewal_notify_to;
	l_old_okc_h_rec.renewal_end_date         := :OLD.renewal_end_date;
	l_old_okc_h_rec.ship_to_site_use_id      := :OLD.ship_to_site_use_id;
	l_old_okc_h_rec.payment_term_id          := :OLD.payment_term_id;
	l_old_okc_h_rec.approval_type            := :OLD.approval_type;
	l_old_okc_h_rec.term_cancel_source       := :OLD.term_cancel_source;
	l_old_okc_h_rec.payment_instruction_type := :OLD.payment_instruction_type;
	l_old_okc_h_rec.org_id                   := :OLD.org_id;
	l_old_okc_h_rec.cancelled_amount         := :OLD.cancelled_amount;
	l_old_okc_h_rec.billed_at_source         := :OLD.billed_at_source;

  END IF;
  -----------------------------------------------------------
  -- New Column Values After Update
  -----------------------------------------------------------
  IF INSERTING OR UPDATING THEN
    l_new_okc_h_rec.id:= :NEW.id;
	l_new_okc_h_rec.contract_number			 := :NEW.contract_number;
	l_new_okc_h_rec.authoring_org_id		 := :NEW.authoring_org_id;
	l_new_okc_h_rec.contract_number_modifier := :NEW.contract_number_modifier;
	l_new_okc_h_rec.chr_id_response			 := :NEW.chr_id_response;
	l_new_okc_h_rec.chr_id_award		   	 := :NEW.chr_id_award;
	l_new_okc_h_rec.chr_id_renewed           := :NEW.chr_id_renewed;
	l_new_okc_h_rec.inv_organization_id      := :NEW.inv_organization_id;
	l_new_okc_h_rec.sts_code                 := :NEW.sts_code;
	l_new_okc_h_rec.qcl_id					 := :NEW.qcl_id;
	l_new_okc_h_rec.scs_code				 := :NEW.scs_code;
	l_new_okc_h_rec.trn_code				 := :NEW.trn_code;
	l_new_okc_h_rec.currency_code            := :NEW.currency_code;
	l_new_okc_h_rec.archived_yn				 := :NEW.archived_yn;
	l_new_okc_h_rec.deleted_yn			     := :NEW.deleted_yn;
	l_new_okc_h_rec.template_yn	             := :NEW.template_yn;
	l_new_okc_h_rec.chr_type		         := :NEW.chr_type;
	l_new_okc_h_rec.object_version_number	 := :NEW.object_version_number;
	l_new_okc_h_rec.created_by				 := :NEW.created_by;
	l_new_okc_h_rec.creation_date		     := :NEW.creation_date;
	l_new_okc_h_rec.last_updated_by			 := :NEW.last_updated_by;
	l_new_okc_h_rec.cust_po_number_req_yn    := :NEW.cust_po_number_req_yn;
	l_new_okc_h_rec.pre_pay_req_yn 			 := :NEW.pre_pay_req_yn;
	l_new_okc_h_rec.cust_po_number  		 := :NEW.cust_po_number;
	l_new_okc_h_rec.dpas_rating				 := :NEW.dpas_rating;
	l_new_okc_h_rec.template_used			 := :NEW.template_used;
	l_new_okc_h_rec.date_approved			 := :NEW.date_approved;
	l_new_okc_h_rec.datetime_cancelled		 := :NEW.datetime_cancelled;
	l_new_okc_h_rec.auto_renew_days			 := :NEW.auto_renew_days;
	l_new_okc_h_rec.date_issued              := :NEW.date_issued;
	l_new_okc_h_rec.datetime_responded    	 := :NEW.datetime_responded;
	l_new_okc_h_rec.rfp_type  			     := :NEW.rfp_type;
	l_new_okc_h_rec.keep_on_mail_list 		 := :NEW.keep_on_mail_list;
	l_new_okc_h_rec.set_aside_percent	     := :NEW.set_aside_percent;
	l_new_okc_h_rec.response_copies_req		 := :NEW.response_copies_req;
	l_new_okc_h_rec.date_close_projected	 := :NEW.date_close_projected;
	l_new_okc_h_rec.datetime_proposed	     := :NEW.datetime_proposed;
	l_new_okc_h_rec.date_signed				 := :NEW.date_signed;
	l_new_okc_h_rec.date_terminated			 := :NEW.date_terminated;
	l_new_okc_h_rec.date_renewed		     := :NEW.date_renewed;
	l_new_okc_h_rec.start_date				 := :NEW.start_date;
	l_new_okc_h_rec.end_date			     := :NEW.end_date;
	l_new_okc_h_rec.buy_or_sell			     := :NEW.buy_or_sell;
	l_new_okc_h_rec.issue_or_receive		 := :NEW.issue_or_receive;
	l_new_okc_h_rec.last_update_login		 := :NEW.last_update_login;
	l_new_okc_h_rec.estimated_amount		 := :NEW.estimated_amount;
	l_new_okc_h_rec.attribute_category	     := :NEW.attribute_category;
	l_new_okc_h_rec.last_update_date	     := :NEW.last_update_date;
	l_new_okc_h_rec.attribute1				 := :NEW.attribute1;
	l_new_okc_h_rec.attribute2				 := :NEW.attribute2;
	l_new_okc_h_rec.attribute3				 := :NEW.attribute3;
	l_new_okc_h_rec.attribute4				 := :NEW.attribute4;
	l_new_okc_h_rec.attribute5				 := :NEW.attribute5;
	l_new_okc_h_rec.attribute6				 := :NEW.attribute6;
	l_new_okc_h_rec.attribute7			     := :NEW.attribute7;
	l_new_okc_h_rec.attribute8			     := :NEW.attribute8;
	l_new_okc_h_rec.attribute9				 := :NEW.attribute9;
	l_new_okc_h_rec.attribute10				 := :NEW.attribute10;
	l_new_okc_h_rec.attribute11				 := :NEW.attribute11;
	l_new_okc_h_rec.attribute12				 := :NEW.attribute12;
	l_new_okc_h_rec.attribute13				 := :NEW.attribute13;
	l_new_okc_h_rec.attribute14				 := :NEW.attribute14;
	l_new_okc_h_rec.attribute15				 := :NEW.attribute15;
	l_new_okc_h_rec.security_group_id		 := :NEW.security_group_id;
	l_new_okc_h_rec.chr_id_renewed_to		 := :NEW.chr_id_renewed_to;
	l_new_okc_h_rec.estimated_amount_renewed := :NEW.estimated_amount_renewed;
	l_new_okc_h_rec.currency_code_renewed    := :NEW.currency_code_renewed;
	l_new_okc_h_rec.upg_orig_system_ref      := :NEW.upg_orig_system_ref;
	l_new_okc_h_rec.upg_orig_system_ref_id   := :NEW.upg_orig_system_ref_id;
	l_new_okc_h_rec.application_id           := :NEW.application_id;
	l_new_okc_h_rec.resolved_until           := :NEW.resolved_until;
	l_new_okc_h_rec.orig_system_source_code  := :NEW.orig_system_source_code;
	l_new_okc_h_rec.orig_system_id1          := :NEW.orig_system_id1;
	l_new_okc_h_rec.orig_system_reference1   := :NEW.orig_system_reference1;
	l_new_okc_h_rec.program_application_id   := :NEW.program_application_id;
	l_new_okc_h_rec.program_id               := :NEW.program_id;
	l_new_okc_h_rec.program_update_date      := :NEW.program_update_date;
	l_new_okc_h_rec.request_id               := :NEW.request_id;
	l_new_okc_h_rec.price_list_id            := :NEW.price_list_id;
	l_new_okc_h_rec.pricing_date             := :NEW.pricing_date;
	l_new_okc_h_rec.total_line_list_price    := :NEW.total_line_list_price;
	l_new_okc_h_rec.sign_by_date             := :NEW.sign_by_date;
	l_new_okc_h_rec.user_estimated_amount    := :NEW.user_estimated_amount;
	l_new_okc_h_rec.governing_contract_yn    := :NEW.governing_contract_yn;
	l_new_okc_h_rec.document_id              := :NEW.document_id;
	l_new_okc_h_rec.conversion_type          := :NEW.conversion_type;
	l_new_okc_h_rec.conversion_rate          := :NEW.conversion_rate;
	l_new_okc_h_rec.conversion_rate_date     := :NEW.conversion_rate_date;
	l_new_okc_h_rec.conversion_euro_rate     := :NEW.conversion_euro_rate;
	l_new_okc_h_rec.cust_acct_id             := :NEW.cust_acct_id;
	l_new_okc_h_rec.bill_to_site_use_id      := :NEW.bill_to_site_use_id;
	l_new_okc_h_rec.inv_rule_id              := :NEW.inv_rule_id;
	l_new_okc_h_rec.renewal_type_code        := :NEW.renewal_type_code;
	l_new_okc_h_rec.renewal_notify_to        := :NEW.renewal_notify_to;
	l_new_okc_h_rec.renewal_end_date         := :NEW.renewal_end_date;
	l_new_okc_h_rec.ship_to_site_use_id      := :NEW.ship_to_site_use_id;
	l_new_okc_h_rec.payment_term_id          := :NEW.payment_term_id;
	l_new_okc_h_rec.approval_type            := :NEW.approval_type;
	l_new_okc_h_rec.term_cancel_source       := :NEW.term_cancel_source;
	l_new_okc_h_rec.payment_instruction_type := :NEW.payment_instruction_type;
	l_new_okc_h_rec.org_id                   := :NEW.org_id;
	l_new_okc_h_rec.cancelled_amount         := :NEW.cancelled_amount;
	l_new_okc_h_rec.billed_at_source         := :NEW.billed_at_source;
  END IF;


  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.okc_header_trg_processor(p_old_okc_h_rec     => l_old_okc_h_rec,
                                                         p_new_okc_h_rec     => l_new_okc_h_rec,
                                                         p_trigger_name      => l_trigger_name,
                                                         p_trigger_action    => l_trigger_action
                                                        );




Exception
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);

  fnd_log.string(log_level => fnd_log.level_unexpected,
	             module    => 'TRIGGER.XXOKC_K_HEADERS_ALL_B_AIU_TRG',
	             message   => l_error_message
                 );

  --RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXOKC_K_HEADERS_ALL_B_AIU_TRG;
/