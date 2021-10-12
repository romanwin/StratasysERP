CREATE OR REPLACE PACKAGE BODY APPS.xxpw_ss_xcarrier_pkg
AS
/*****************************************************************************
/*  Name         : XXPW_SS_XCARRIER_PKG
/*  DESCRIPTION  : This custom package is created by ProcessWeaver to communicate with xCarrier Shipping Product
/*
/*  MODIFICATION  HISTORY
/*  Change Number   Version  Date             Modified By                  Remarks
/*  -               1.0                        Venkata Nagarjuna Thota     Initial draft version
/*                  1.1    12-JUN-2015          Abdullah                   Rollback if API fails
/*                  1.2     9-JUL-2015         Venkata Nagarjuna Thota     Added Attribute1 feild for update AWB
/*                  1.3     7-DEC-2015         Venkata Nagarjuna Thota     Added Freight_Term_Code for update Freight_code information
/*                  1.4    20-JAN-2017         Venkata Nagarjuna Thota     Added P_Freight in deliveries_upd_prc to update xCarrier Published Freight information
/*                 1.5    21-MAR-2018          Venkata Nagarjuna Thota    Added P_Delivery_Name to update data to WSH_NEW_DELIVEREIS table using Delivery Name
/* This Custom Function is developed to return the xCarrier URL with Oracle Application context arguments */
   FUNCTION xcarrier_fnc (p_delivery_id NUMBER, p_organization_id NUMBER)
      RETURN VARCHAR2
   IS
      lc_user_name      fnd_user.user_name%TYPE;
      lc_org_id         NUMBER;
      lc_return         VARCHAR2 (300);
      lc_resp_id        NUMBER;
      lc_resp_appl_id   NUMBER;
   BEGIN
      SELECT user_name
        INTO lc_user_name
        FROM fnd_user
       WHERE user_id = (SELECT fnd_global.user_id
                          FROM DUAL);

      SELECT UNIQUE org_id
               INTO lc_org_id
               FROM apps.wsh_delivery_details
              WHERE delivery_detail_id IN (SELECT delivery_detail_id
                                             FROM apps.wsh_delivery_assignments
                                            WHERE delivery_id = p_delivery_id)
                AND org_id IS NOT NULL;

      SELECT fnd_global.resp_id
        INTO lc_resp_id
        FROM DUAL;

      SELECT fnd_global.resp_appl_id
        INTO lc_resp_appl_id
        FROM DUAL;

      lc_return :=
            'https://ssys.myxcarrier.com/xcarrier/Default.html?delno='
         || p_delivery_id
         || '&'
         || 'userid='
         || lc_user_name
         || '&'
         || 'plantid='
         || p_organization_id
         || '&'
         || 'OUid='
         || lc_org_id
         || '&'
         || 'respid='
         || lc_resp_id
         || '&'
         || 'applid='
         || lc_resp_appl_id;
      RETURN lc_return;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN ('Delivery Lines are Not Found');
      WHEN OTHERS
      THEN
         RETURN (SQLERRM);
   END;

/* This Custom Function is developed to check the status of delivery lines and to launch xCarrier URL for valid status.*/
   FUNCTION delivery_val_fnc (p_delivery_id IN NUMBER)
      RETURN NUMBER
   IS
      lc_count             NUMBER;
      lc_organization_id   NUMBER;
   BEGIN
      SELECT COUNT (*)
        INTO lc_count
        FROM apps.wsh_delivery_details
       WHERE delivery_detail_id IN (SELECT delivery_detail_id
                                      FROM apps.wsh_delivery_assignments
                                     WHERE delivery_id = p_delivery_id)
         AND released_status IN ('B', 'N', 'P', 'R', 'S', 'X')
         AND container_flag = 'N';

      IF lc_count = 0
      THEN
         RETURN 0;
      ELSE
         RETURN 1;
      END IF;
   END;

/* This Custom function is developed to check whether user name exists in Oracle applications or not.*/
   FUNCTION validate_user_fnc (p_user_name VARCHAR2)
      RETURN VARCHAR2
   IS
      lc_user_val   NUMBER;
   BEGIN
      SELECT COUNT (*)
        INTO lc_user_val
        FROM fnd_user
       WHERE UPPER (user_name) = UPPER (p_user_name);

      IF lc_user_val = 0
      THEN
         RETURN ('N');
      ELSE
         RETURN ('Y');
      END IF;
   END;

   /* This Custom Procedure is developed to initialize the backend session to get oracle application context and multi org access */
   PROCEDURE initialize_prc (
      p_user                 VARCHAR2,
      p_org_id               NUMBER,
      p_resp_id              NUMBER,
      p_resp_appl_id         NUMBER,
      x_error          OUT   VARCHAR2
   )
   AS
      lc_upd_user   NUMBER;
      lc_user_id    NUMBER;
      PRAGMA AUTONOMOUS_TRANSACTION;
      p_access      VARCHAR2 (1);
   BEGIN
      SELECT user_id
        INTO lc_user_id
        FROM fnd_user
       WHERE UPPER (user_name) = UPPER (p_user);

      -- Initializing the Applications
      apps.fnd_global.apps_initialize (lc_user_id, p_resp_id, p_resp_appl_id);
      lc_upd_user := apps.fnd_global.user_id;

      IF lc_upd_user IS NULL OR lc_upd_user = -1
      THEN
         x_error := 'Failed to Initialize the user: ' || p_user;
      ELSE
         x_error := 'Success';
         COMMIT;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         x_error :=
               'Failed to Initialize: No user/responsibility exists in Oracle with name: '
            || p_user;
      WHEN OTHERS
      THEN
         x_error :=
                   'Unhandled Exception while initializing User: ' || SQLERRM;
   END;

   /* This Custom procedure is used to update the Open delivery details when user performs plan shipment in xCarrier */
   PROCEDURE deliveries_upd_prc (
      p_delivery_id               NUMBER,
      p_delivery_name             VARCHAR2,
      p_org_id                    NUMBER,
      waybill                     VARCHAR2,
      weight                      NUMBER,
      weight_uom_code             VARCHAR2,
      p_expected_del_date         VARCHAR2,
      lines_count                 VARCHAR2,
      cost_center                 VARCHAR2,
      ship_method                 VARCHAR2,
      mot                         VARCHAR2,
      payment_type                VARCHAR2,
      p_freight                   NUMBER,
      x_error               OUT   VARCHAR2
   )
   AS
      init_msg_list        VARCHAR2 (200)              := apps.fnd_api.g_true;
      x_return_status      VARCHAR2 (15);
      x_msg_count          NUMBER;
      x_msg_data           VARCHAR2 (3000);
      x_delivery_id        NUMBER;
      x_name               VARCHAR2 (3000);
      p_action_code        VARCHAR2 (100);
      lc_msg_data          VARCHAR2 (4000);
      lc_errors            VARCHAR2 (4000);
      lc_delivery_number   NUMBER;
      lc_delivery_info     apps.wsh_deliveries_pub.delivery_pub_rec_type;
      lc_uom_code          VARCHAR2 (3);
      lc_carrier_name      wsh_carriers.freight_code%TYPE;
      lc_ship_val          wsh_carrier_services.ship_method_meaning%TYPE;
      lc_carrier           wsh_carriers.carrier_id%TYPE;
      lc_ship_method       wsh_carrier_services.ship_method_meaning%TYPE;
      lc_service           wsh_carrier_services.service_level%TYPE;
      lc_mode              wsh_carrier_services.mode_of_transport%TYPE;
      lc_freight_terms_code   wsh_new_deliveries.freight_terms_code%TYPE;
   BEGIN
      lc_errors := 'Success';
      /* Assigning parameter values to update delivery Info*/
      lc_delivery_info.waybill := waybill;
      lc_delivery_info.attribute1 := waybill;
      lc_delivery_info.gross_weight := weight;
      lc_delivery_info.net_weight := weight;
      lc_delivery_info.number_of_lpn := lines_count;
      lc_delivery_info.attribute5 := cost_center;
      lc_delivery_info.attribute13 := p_freight;
      lc_delivery_info.initial_pickup_date := SYSDATE;
      lc_delivery_info.ultimate_dropoff_date :=
                      TO_DATE (p_expected_del_date, 'DD-MON-RRRR HH24:MI:SS');
      p_action_code := 'UPDATE';

      BEGIN
         IF weight_uom_code IS NOT NULL
         THEN
            SELECT UNIQUE mum.uom_code
              INTO lc_uom_code
              FROM mtl_units_of_measure mum
             WHERE UPPER (uom_class) = UPPER ('WEIGHT')
               AND UPPER (uom_code) = UPPER (weight_uom_code);
               --AND organization_id = p_org_id;

            lc_delivery_info.weight_uom_code := lc_uom_code;
         ELSE
            NULL;
         END IF;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            lc_errors :=
                  'Unable to update Weight UOM, '
               || weight_uom_code
               || ' doesnt match with Oracle';
         WHEN OTHERS
         THEN
            lc_errors := 'UOM: Unhandled exception: ' || SQLERRM;
      END;

      BEGIN
         SELECT wc.freight_code
           INTO lc_carrier_name
           FROM wsh_carriers_v wc, wsh_carrier_services wcs
          WHERE wc.carrier_id = wcs.carrier_id
            AND UPPER (wcs.ship_method_meaning) = UPPER (ship_method);

         SELECT wcs.ship_method_meaning
           INTO lc_ship_val
           FROM wsh_new_deliveries wnd, wsh_carrier_services wcs
          WHERE wnd.ship_method_code = wcs.ship_method_code(+)
                AND wnd.delivery_id = p_delivery_id;

         IF lc_ship_val IS NOT NULL
         THEN
            IF (lc_ship_val <> ship_method)
            THEN
               BEGIN
                  SELECT wc.carrier_id, wcs.ship_method_meaning,
                         wcs.service_level, wcs.mode_of_transport
                    INTO lc_carrier, lc_ship_method,
                         lc_service, lc_mode
                    FROM wsh_carriers_v wc, wsh_carrier_services wcs
                   WHERE wc.carrier_id = wcs.carrier_id
                     AND UPPER (wcs.ship_method_meaning) = UPPER (ship_method);

                  lc_delivery_info.carrier_id := lc_carrier;
                  lc_delivery_info.ship_method_name := lc_ship_method;
                  lc_delivery_info.service_level := lc_service;
                  lc_delivery_info.mode_of_transport := lc_mode;
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     IF lc_errors <> 'Success'
                     THEN
                        lc_errors :=
                              lc_errors
                           || CHR (38)
                           || 'Unable to update Ship Method,'
                           || ship_method
                           || ' not found in Oracle';
                     ELSE
                        lc_errors :=
                              'Unable to update Ship Method,'
                           || ship_method
                           || ' not found in Oracle';
                     END IF;
                  WHEN OTHERS
                  THEN
                     IF lc_errors <> 'Success'
                     THEN
                        lc_errors :=
                              lc_errors
                           || CHR (38)
                           || 'Ship Method: Unhandled exception: '
                           || SQLERRM;
                     ELSE
                        lc_errors :=
                              'Ship Method: Unhandled exception: ' || SQLERRM;
                     END IF;
               END;
            END IF;
         ELSE
            BEGIN
               SELECT wc.carrier_id, wcs.ship_method_meaning,
                      wcs.service_level, wcs.mode_of_transport
                 INTO lc_carrier, lc_ship_method,
                      lc_service, lc_mode
                 FROM wsh_carriers_v wc, wsh_carrier_services wcs
                WHERE wc.carrier_id = wcs.carrier_id
                  AND UPPER (wcs.ship_method_meaning) = UPPER (ship_method);

               lc_delivery_info.carrier_id := lc_carrier;
               lc_delivery_info.ship_method_name := lc_ship_method;
               lc_delivery_info.service_level := lc_service;
               lc_delivery_info.mode_of_transport := lc_mode;
            EXCEPTION
               WHEN NO_DATA_FOUND
               THEN
                  IF lc_errors <> 'Success'
                  THEN
                     lc_errors :=
                           lc_errors
                        || CHR (38)
                        || 'Unable to update Ship Method,'
                        || ship_method
                        || ' not found in Oracle';
                  ELSE
                     lc_errors :=
                           'Unable to update Ship Method,'
                        || ship_method
                        || ' not found in Oracle';
                  END IF;
               WHEN OTHERS
               THEN
                  IF lc_errors <> 'Success'
                  THEN
                     lc_errors :=
                           lc_errors
                        || CHR (38)
                        || 'Ship Method: Unhandled exception: '
                        || SQLERRM;
                  ELSE
                     lc_errors :=
                              'Ship Method: Unhandled exception: ' || SQLERRM;
                  END IF;
            END;
         END IF;
      END;

        --Assgining Payment type
        BEGIN
           SELECT freight_terms_code
             INTO lc_freight_terms_code
             FROM apps.oe_frght_terms_active_v
            WHERE upper(freight_terms) = upper(payment_type);
           lc_delivery_info.freight_terms_code := lc_freight_terms_code;
        EXCEPTION
           WHEN OTHERS
           THEN
              IF lc_errors <> 'Success'
              THEN
                 lc_errors :=
                       lc_errors
                    || CHR (38)
                    || ' Exception while deriving Freight Terms code for Freight-Term: '
                    || payment_type
                    || ' '
                    || SQLERRM;
              ELSE
                 lc_errors :=
                       'Exception while deriving Freight Terms code for Freight-Term: '
                    || payment_type
                    || ' '
                    || SQLERRM;
              END IF;
        END;

      /* Calling Standard API to process the Delivery Data updates */
      apps.wsh_deliveries_pub.create_update_delivery
                                         (p_api_version_number      => 1.0,
                                          p_init_msg_list           => init_msg_list,
                                          x_return_status           => x_return_status,
                                          x_msg_count               => x_msg_count,
                                          x_msg_data                => x_msg_data,
                                          p_action_code             => p_action_code,
                                          p_delivery_info           => lc_delivery_info,
                                          p_delivery_name           => p_delivery_name,
                                          x_delivery_id             => x_delivery_id,
                                          x_name                    => x_name
                                         );

      IF (x_msg_count <> 0)
      THEN
         FOR i IN 1 .. x_msg_count
         LOOP
            lc_msg_data :=
                  lc_msg_data
               || '   '
               || apps.fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
         END LOOP;

         IF lc_errors <> 'Success'
         THEN
            lc_errors := lc_errors || ' - ' || lc_msg_data;
         ELSE
            lc_errors :=
               'Errors while updating Delivery Information : ' || lc_msg_data;
         END IF;

         ROLLBACK;
      ELSE
         COMMIT;
      END IF;

      x_error := lc_errors;
   END;

/* This Custom procedure is developed to update the freight cost from xCarrier, when Freight terms is "PREPAID/ADD or
PREPAID/ADD US". This will delete the existing freight cost and creates new freight cost.*/
   PROCEDURE freight_prc (
      p_delivery_id          NUMBER,
      p_delivery_name        VARCHAR2,
      p_freight_cost         NUMBER,
      p_freight_type         VARCHAR2,
      x_error          OUT   VARCHAR2
   )
   AS
      -- Freight API local variables declaration
      p_commit                  VARCHAR2 (30);
      freight_cost_id           NUMBER;
      pub_freight_costs         apps.wsh_freight_costs_pub.pubfreightcostrectype;
      lc_return_status          VARCHAR2 (15);
      lc_msg_count              NUMBER;
      lc_err_msg_data           VARCHAR2 (4000);
      lc_msg                    VARCHAR2 (4000);
      lc_freight_cost_type_id   NUMBER;
      lc_currency_code          VARCHAR2 (10);
      lc_errors                 VARCHAR2 (2000);
      init_msg_list             VARCHAR2 (200)         := apps.fnd_api.g_true;

      CURSOR freight_cost_id_cur
      IS
         SELECT freight_cost_id
           FROM apps.wsh_freight_costs
          WHERE delivery_id = p_delivery_id;
   BEGIN
      lc_errors := 'Success';

      SELECT freight_cost_type_id, currency_code
        INTO lc_freight_cost_type_id, lc_currency_code
        FROM apps.wsh_freight_cost_types
       WHERE UPPER (NAME) = UPPER (p_freight_type);

      FOR i IN freight_cost_id_cur
      LOOP
         lc_return_status := apps.wsh_util_core.g_ret_sts_success;
         pub_freight_costs.delivery_id := p_delivery_id;
         pub_freight_costs.freight_cost_id := i.freight_cost_id;
         /*Calling Delete_freight_costs API to delete the existing frieght cost.*/
         apps.wsh_freight_costs_pub.delete_freight_costs
                                    (p_api_version_number      => 1.0,
                                     p_init_msg_list           => init_msg_list,
                                     p_commit                  => p_commit,
                                     x_return_status           => lc_return_status,
                                     x_msg_count               => lc_msg_count,
                                     x_msg_data                => lc_err_msg_data,
                                     p_pub_freight_costs       => pub_freight_costs
                                    );
      END LOOP;

      lc_return_status := apps.wsh_util_core.g_ret_sts_success;
      /* Assigning Values to the Parameters for creating the freight costs.*/
      pub_freight_costs.freight_cost_type_id := lc_freight_cost_type_id;
      pub_freight_costs.unit_amount := p_freight_cost;
      pub_freight_costs.currency_code := lc_currency_code;
      pub_freight_costs.delivery_id := p_delivery_id;
      /*Calling API to Create Frieght Cost */
      apps.wsh_freight_costs_pub.create_update_freight_costs
                                    (p_api_version_number      => 1.0,
                                     p_init_msg_list           => init_msg_list,
                                     p_commit                  => p_commit,
                                     x_return_status           => lc_return_status,
                                     x_msg_count               => lc_msg_count,
                                     x_msg_data                => lc_err_msg_data,
                                     p_pub_freight_costs       => pub_freight_costs,
                                     p_action_code             => 'CREATE',
                                     x_freight_cost_id         => freight_cost_id
                                    );

      IF (lc_msg_count <> 0)
      THEN
         FOR i IN 1 .. lc_msg_count
         LOOP
            lc_msg :=
                  lc_msg
               || '   '
               || apps.fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
         END LOOP;

         lc_errors := 'Errors while updating Freight Cost : ' || lc_msg;
         ROLLBACK;
      ELSE
         COMMIT;
         x_error := lc_errors;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         lc_errors :=
               'No Data Found while updating Freight cost for delivery#: '
            || p_delivery_id;
      WHEN OTHERS
      THEN
         lc_errors :=
               'Unhandled exception raised while updating the Freight Cost: '
            || SQLERRM;
         x_error := lc_errors;
   END;

   /* This Custom procedure is used to update the Carrier Signed By,Carrier date OR POD by, POD date details from xCarrier */
   PROCEDURE carrier_pod_upd_prc (
      p_delivery_id              NUMBER,
      p_delivery_name            VARCHAR2,
      p_pod_by                   VARCHAR2 DEFAULT NULL,
      p_pod_date                 VARCHAR2 DEFAULT NULL,
      p_intransit_status         VARCHAR2,
      x_error              OUT   VARCHAR2
   )
   IS
/* Local variables declaration */
      lc_delivery_leg_info          wsh_delivery_legs_grp.dlvy_leg_tab_type;
      lc_delivery_action_info       wsh_delivery_legs_grp.action_parameters_rectype;
      lc_delivery_action_out_info   wsh_delivery_legs_grp.action_out_rec_type;
      lc_return_status              VARCHAR2 (100);
      lc_msg_count                  NUMBER;
      lc_msg_data                   VARCHAR2 (3000);
      lc_delivery_leg_id            wsh_delivery_legs.delivery_leg_id%TYPE;
      lc_sequence_number            wsh_delivery_legs.sequence_number%TYPE;
      lc_pick_up_stop_id            wsh_delivery_legs.pick_up_stop_id%TYPE;
      lc_drop_off_stop_id           wsh_delivery_legs.drop_off_stop_id%TYPE;
      lc_pod_date                   wsh_delivery_legs.pod_date%TYPE;
      lc_count                      NUMBER;
      lc_error_msg                  VARCHAR2 (8000);
      init_msg_list                 VARCHAR2 (3000)          := fnd_api.g_true;
      lc_commit                     VARCHAR2 (3000);
      lc_errors                     VARCHAR2 (3000);
      /* Local Variable for Intransist status*/
      lc_delivery_info              apps.wsh_deliveries_pub.delivery_pub_rec_type;
      p_action_code                 VARCHAR2 (100);
      x_return_status               VARCHAR2 (15);
      x_msg_count                   NUMBER;
      x_msg_data                    VARCHAR2 (3000);
      x_delivery_id                 NUMBER;
      x_name                        VARCHAR2 (3000);
      lc_delivery_number            NUMBER;
   BEGIN
      lc_errors := 'Success';

      /* Updating POD  Status*/
      BEGIN
         SELECT delivery_leg_id, sequence_number, pick_up_stop_id,
                drop_off_stop_id, pod_date
           INTO lc_delivery_leg_id, lc_sequence_number, lc_pick_up_stop_id,
                lc_drop_off_stop_id, lc_pod_date
           FROM apps.wsh_delivery_legs
          WHERE delivery_id = p_delivery_id;

/* Assigning input values and key values to the delivery legs record type */
         lc_delivery_leg_info (1).delivery_leg_id := lc_delivery_leg_id;
         lc_delivery_leg_info (1).delivery_id := p_delivery_id;
         lc_delivery_leg_info (1).sequence_number := lc_sequence_number;
         lc_delivery_leg_info (1).pick_up_stop_id := lc_pick_up_stop_id;
         lc_delivery_leg_info (1).drop_off_stop_id := lc_drop_off_stop_id;

         IF p_pod_date IS NOT NULL
         THEN
            IF lc_pod_date IS NULL
            THEN
               lc_delivery_leg_info (1).pod_date :=
                               TO_DATE (p_pod_date, 'DD-MON-RRRR HH24:MI:SS');
               lc_delivery_leg_info (1).pod_by := p_pod_by;
            ELSE
               lc_errors := 'N';
            END IF;
         END IF;

         lc_delivery_action_info.action_code := 'UPDATE';
/* Calling Standard API to process the updates */
         wsh_delivery_legs_grp.update_delivery_leg
                                                 (1.0,
                                                  init_msg_list,
                                                  lc_commit,
                                                  lc_delivery_leg_info,
                                                  lc_delivery_action_info,
                                                  lc_delivery_action_out_info,
                                                  lc_return_status,
                                                  lc_msg_count,
                                                  lc_msg_data
                                                 );

         IF lc_return_status <> 'S'
         THEN
            SELECT fnd_msg_pub.count_msg
              INTO lc_count
              FROM DUAL;

            FOR i IN 1 .. lc_count
            LOOP
               lc_error_msg :=
                     lc_error_msg
                  || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            x_error :=
                  'Errors while updating the Carrier and POD Details: '
               || lc_error_msg;
            ROLLBACK;
         ELSE
            x_error := lc_errors;
            COMMIT;
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            x_error := 'Unhandled exception: ' || SQLERRM;
      END;

      /* Assigning parameter values to update Intransist Status*/
      lc_delivery_info.attribute6 := p_intransit_status;
      p_action_code := 'UPDATE';
      /* Calling Standard API to process the waybill updates */
      apps.wsh_deliveries_pub.create_update_delivery
                                         (p_api_version_number      => 1.0,
                                          p_init_msg_list           => init_msg_list,
                                          x_return_status           => x_return_status,
                                          x_msg_count               => x_msg_count,
                                          x_msg_data                => x_msg_data,
                                          p_action_code             => p_action_code,
                                          p_delivery_info           => lc_delivery_info,
                                          p_delivery_name           => p_delivery_name,
                                          x_delivery_id             => x_delivery_id,
                                          x_name                    => x_name
                                         );

      IF (x_msg_count <> 0)
      THEN
         FOR i IN 1 .. x_msg_count
         LOOP
            lc_msg_data :=
                  lc_msg_data
               || '   '
               || apps.fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
         END LOOP;

         IF lc_errors <> 'Success'
         THEN
            lc_errors := lc_errors || ' - ' || lc_msg_data;
         ELSE
            lc_errors := 'Errors while updating Waybill : ' || lc_msg_data;
         END IF;

         ROLLBACK;
      ELSE
         COMMIT;
      END IF;

      x_error := lc_errors;
   END;

/* This Custom procedure is used to update the Export Entry Number details from xCarrier */
   PROCEDURE export_number_prc (
      p_delivery_id         NUMBER,
      p_delivery_name       VARCHAR2,
      export_number         VARCHAR2,
      x_error         OUT   VARCHAR2
   )
   AS
      init_msg_list        VARCHAR2 (200)              := apps.fnd_api.g_true;
      x_return_status      VARCHAR2 (15);
      x_msg_count          NUMBER;
      x_msg_data           VARCHAR2 (3000);
      x_delivery_id        NUMBER;
      x_name               VARCHAR2 (3000);
      p_action_code        VARCHAR2 (100);
      lc_msg_data          VARCHAR2 (4000);
      lc_errors            VARCHAR2 (4000);
      lc_delivery_number   NUMBER;
      lc_delivery_info     apps.wsh_deliveries_pub.delivery_pub_rec_type;
   BEGIN
      lc_errors := 'Success';
      /* Assigning parameter values to update delivery Info*/
      lc_delivery_info.attribute12 := export_number;
      p_action_code := 'UPDATE';
      /* Calling Standard API to process the Delivery Data updates */
      apps.wsh_deliveries_pub.create_update_delivery
                                        (p_api_version_number      => 1.0,
                                         p_init_msg_list           => init_msg_list,
                                         x_return_status           => x_return_status,
                                         x_msg_count               => x_msg_count,
                                         x_msg_data                => x_msg_data,
                                         p_action_code             => p_action_code,
                                         p_delivery_info           => lc_delivery_info,
                                         p_delivery_name           => p_delivery_name,
                                         x_delivery_id             => x_delivery_id,
                                         x_name                    => x_name
                                        );

      IF (x_msg_count <> 0)
      THEN
         FOR i IN 1 .. x_msg_count
         LOOP
            lc_msg_data :=
                  lc_msg_data
               || '   '
               || apps.fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
         END LOOP;

         IF lc_errors <> 'Success'
         THEN
            lc_errors := lc_errors || ' - ' || lc_msg_data;
         ELSE
            lc_errors :=
               'Errors while updating Delivery Information : ' || lc_msg_data;
         END IF;

         ROLLBACK;
      ELSE
         COMMIT;
      END IF;

      x_error := lc_errors;
   END;
END;
/