CREATE OR REPLACE PACKAGE BODY XXOM_S3_EVENT_PKG AS
  ----------------------------------------------------------------------------
  --  name:            XXOM_S3_EVENT_PKG
  --  create by:       TCS
  --  $Revision:       1.0
  --  creation date:   22/08/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package containing procedure to collect the delivery details while a business event is triggered
  --                   once a ship confirm is done on Oracle order Management.
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  17/08/2016  TCS                    Initial build
  ----------------------------------------------------------------------------
  FUNCTION process_event(p_subscription_guid IN RAW,
                         p_event             IN OUT wf_event_t) RETURN VARCHAR2 IS

    -- Local Variable Declaration .

    l_param_list        wf_parameter_list_t;
    l_param_name        VARCHAR2(240);
    l_param_value       VARCHAR2(2000);
    l_event_name        VARCHAR2(2000);
    l_event_key         VARCHAR2(2000);
    l_event_data        VARCHAR2(4000);
    l_instance_id       NUMBER;
    l_dml_type          VARCHAR2(10); -- DML type (Create/Update)
    l_extension_id      NUMBER; -- Extension id
    l_data_level_id     NUMBER;
    l_cust_account_id   NUMBER;
    l_cust_acct_site_id NUMBER;
    l_contact_point_id  NUMBER;
    l_organization_id   NUMBER;
    l_return_status     VARCHAR2(20); -- Return status
    l_return_msg        VARCHAR2(1000); -- Return message
    l_value_changed     VARCHAR2(10);
    l_org_id            NUMBER; -- Data level id
    l_attr_group_name   VARCHAR2(100); -- Attribute Group Name
    l_eff_date          DATE;
    l_status            VARCHAR2(100) := 'SUCCESS';
    l_count             NUMBER := 0;
    l_order_name        VARCHAR2(100);

    l_xxssys_event_rec xxssys_events%ROWTYPE;

  BEGIN

    SAVEPOINT event_start;

--    DELETE FROM xx_be_debug_log_tmp;

    l_param_list := p_event.getparameterlist;
    l_event_name := p_event.geteventname();
    l_event_key  := p_event.geteventkey();
    l_event_data := p_event.geteventdata();

    IF (l_param_list IS NOT NULL) THEN
      FOR i IN l_param_list.FIRST .. l_param_list.LAST LOOP
        -- ORG lelev event
        IF l_event_name = 'oracle.apps.wsh.delivery.gen.shipconfirmed' THEN
          l_param_name  := l_param_list(i).getname;
          l_param_value := l_param_list(i).getvalue;

          /*BEGIN
            SELECT distinct ottt.NAME
              INTO l_order_name
              FROM wsh_new_deliveries      wnd,
                   oe_order_headers_all    ooha,
                   oe_transaction_types_tl ottt
             WHERE wnd.delivery_id = l_param_value
               AND wnd.source_header_id = ooha.header_id
               AND ooha.order_type_id = ottt.transaction_type_id;
          EXCEPTION
            WHEN OTHERS THEN
              l_order_name := '';
          END;*/
          
             BEGIN
               SELECT distinct ottt.NAME
                 INTO l_order_name
                 FROM wsh_delivery_details     wdd,
                      wsh_delivery_assignments wda,
                      oe_order_headers_all     ooha,
                      oe_transaction_types_tl  ottt
                WHERE wda.delivery_id = l_param_value
                  AND wdd.delivery_detail_id = wda.delivery_detail_id
                  AND wdd.source_header_id = ooha.header_id
                  AND ooha.order_type_id = ottt.transaction_type_id;
                  
             EXCEPTION
               WHEN OTHERS THEN
                 l_order_name := '';
             END;
          

          IF l_order_name = 'Internal Interim Order-OBJ IL' THEN
            BEGIN

              l_xxssys_event_rec.target_name := 'S3';
              l_xxssys_event_rec.entity_name := 'ASN';
              l_xxssys_event_rec.entity_id   := l_param_value;
              l_xxssys_event_rec.event_name  := l_event_name;
              l_xxssys_event_rec.active_flag := 'Y';

              xxssys_event_pkg.insert_event(p_xxssys_event_rec => l_xxssys_event_rec);

            EXCEPTION
              WHEN no_data_found THEN

                NULL;
              WHEN OTHERS THEN
                           NULL;
            END;
          END IF;
        END IF;

      END LOOP;
    END IF;
RETURN 'SUCCESS';
  EXCEPTION
    WHEN OTHERS THEN
      -- context information that helps locate the source of an error.
      xxssys_event_pkg.process_event_error(p_event_id     => l_xxssys_event_rec.event_id,
                                           p_error_system => l_xxssys_event_rec.status,
                                           p_err_message  => l_xxssys_event_rec.err_message);

      ROLLBACK TO event_start;

      wf_core.CONTEXT(pkg_name  => 'XXOM_S3_EVENT_PKG',
                      proc_name => 'XX_INSERT',
                      arg1      => p_event.geteventname(),
                      arg2      => p_event.geteventkey(),
                      arg3      => p_subscription_guid); -- Retrieves error information from the error stack and sets it into the event message. --

      wf_event.seterrorinfo(p_event => p_event,
                            p_type  => 'ERROR');

      RETURN 'ERROR';

  END process_event;
END xxom_s3_event_pkg;
/
