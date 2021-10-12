update xx_qp_pricereq_session set request_source = 'HYBRIS' where request_source is null
/

update xx_qp_pricereq_modifiers set request_source = 'HYBRIS' where request_source is null
/

update xx_qp_pricereq_attributes set request_source = 'HYBRIS' where request_source is null
/

update xx_qp_pricereq_reltd_adj set request_source = 'HYBRIS' where request_source is null
/

commit;