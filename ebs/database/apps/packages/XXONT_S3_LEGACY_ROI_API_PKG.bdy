CREATE OR REPLACE PACKAGE BODY xxont_s3_legacy_roi_api_pkg IS
  g_num_user_id        NUMBER := apps.fnd_global.user_id;
  g_num_application_id NUMBER := apps.fnd_global.resp_appl_id;
  g_num_resp_id        NUMBER := apps.fnd_global.resp_id;
  l_return_status      VARCHAR2(10);
 x_return_status      VARCHAR2(10);
  x_msg_count          NUMBER;
  x_msg_data           VARCHAR2(4000);
  x_expire_date date;
  x_object_id number;

  -- Created : 08/09/2016 2:37:10 PM
  -- Purpose : Stratasys ASN Interim Solution

  /******************************************************************************************************************************************
  * Type                : Package                                                                                                          *
  * Module Name         : ASN Creation                                                                                                   *
  * Name                : xxont_s3_legacy_rcvng_trxn_api_pkg                                                                                           *
  * Script Name         : xxont_s3_legacy_rcvng_trxn_api_pkg.pks                                                                                       *
  * Procedure           : 1.call_receivingtransaction                                                                                             *
                                                                                                                                   *                                                                                                                                            *
  * Purpose             : This script is used to create Package "xxont_s3_legacy_rcvng_trxn_api_pkg" in APPS schema,                                   *
                                                                                                                                           *
  * HISTORY                                                                                                                                *
  * =======                                                                                                                                *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                       *
  * -------  ----------- ---------------    ------------------------------------                                                              *
  * 1.00     08/23/2016  TCS               Draft version                                                                                     *
  ******************************************************************************************************************************************/

  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : ASN Creation                                                                                                      *
  * Name                : call_receivingtransaction                                                                                                *
  * Script Name         : xxont_s3_legacy_rcvng_trxn_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will call the Receiving Open Interface Standard program to create ASN in
                           Legacy system with the same data of S3 environment.                                                                                         *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/23/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/
  PROCEDURE call_receivingtransaction(p_grp_id IN NUMBER,p_request_status out varchar2) IS
    l_reqid          NUMBER;
    v_phase          VARCHAR2(2000);
    v_wait_status    VARCHAR2(2000);
    v_message        VARCHAR2(2000);
    v_dev_status     VARCHAR2(100);
    v_dev_phase      VARCHAR2(100);
    v_request_status BOOLEAN;
  BEGIN

    l_reqid := fnd_request.submit_request(application => 'PO',
                                          program     => 'RVCTP',
                                          description => '', ---Receiving Transaction Processor
                                          start_time  => NULL,
                                          sub_request => FALSE,
                                          argument1   => 'BATCH',
                                          argument2   => p_grp_id,
                                          argument3   => '');

    COMMIT;
    v_request_status := fnd_concurrent.wait_for_request(request_id => l_reqid,
                                                        INTERVAL   => 5,
                                                        max_wait   => 600,
                                                        phase      => v_phase,
                                                        status     => v_wait_status,
                                                        dev_phase  => v_dev_phase,
                                                        dev_status => v_dev_status,
                                                        message    => v_message);
    COMMIT;
    p_request_status:=v_dev_status;
  END call_receivingtransaction;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         : ASN Creation                                                                                                      *
  * Name                : call_receivingtransaction                                                                                                *
  * Script Name         : xxont_s3_legacy_rcvng_trxn_api_pkg.pkb                                                                                        *
  *                                                                                                                                         *
                                                                                                                                            *                                                                                                                                            *
  * Purpose             :  This procedure will create a Lot Number for a particular item in the Legacy system                                                          *
                                                                                                                                            *
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     08/23/2016  TCS                Initial version                                                                                      *
  ******************************************************************************************************************************************/

  PROCEDURE create_lot(p_org_id     IN NUMBER,
                       p_item_id    IN NUMBER,
                       p_lot_number IN VARCHAR2,
                       p_status     OUT VARCHAR2) IS
  BEGIN
    inv_lot_api_pub.insertlot(p_api_version       => 1,
                              p_init_msg_list     => fnd_api.g_false,
                              p_commit            => fnd_api.g_false,
                              p_validation_level  => fnd_api.g_valid_level_full,
                              p_inventory_item_id => p_item_id,
                              p_organization_id   => p_org_id,
                              p_lot_number        => p_lot_number,
                              p_expiration_date   => x_expire_date,
                              x_object_id         => x_object_id,
                              x_return_status     => x_return_status,
                              x_msg_count         => x_msg_count,
                              x_msg_data          => x_msg_data);
  commit;
  p_status:=x_return_status;
     fnd_file.put_line(fnd_file.log,'Create lot status = ' || x_return_status);

    fnd_file.put_line(fnd_file.log,
                      'l_msg_count = ' || to_char(x_msg_count));
    fnd_file.put_line(fnd_file.log,
                      substr('l_msg_data = ' || x_msg_data,
                             1,
                             255));
    IF x_msg_count > 1 THEN
      FOR i IN 1 .. x_msg_count LOOP
        fnd_file.put_line(fnd_file.log,
                          i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
                                              1,
                                              255));
      END LOOP;
    END IF;
  END create_lot;
END xxont_s3_legacy_roi_api_pkg;
/
