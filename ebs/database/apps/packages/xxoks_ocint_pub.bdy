CREATE OR REPLACE PACKAGE BODY xxoks_ocint_pub AS
/* $Header: OKSPOCIB.pls 120.26.12000000.3 2008/03/11 04:16:53 vgujarat ship $ */
----------------------------------------------------------------------------------------
   g_unexpected_error   CONSTANT VARCHAR2 (200)
                                               := 'OKC_CONTRACTS_UNEXP_ERROR';
   g_sqlcode_token      CONSTANT VARCHAR2 (200) := 'SQLcode';
   g_sqlerrm_token      CONSTANT VARCHAR2 (200) := 'SQLerrm';
   g_required_value     CONSTANT VARCHAR2 (200) := okc_api.g_required_value;
   g_col_name_token     CONSTANT VARCHAR2 (200) := okc_api.g_col_name_token;
----------------------------------------------------------------------------------------
  -- Constants used for Message Logging
   g_level_unexpected   CONSTANT NUMBER         := fnd_log.level_unexpected;
   g_level_error        CONSTANT NUMBER         := fnd_log.level_error;
   g_level_exception    CONSTANT NUMBER         := fnd_log.level_exception;
   g_level_event        CONSTANT NUMBER         := fnd_log.level_event;
   g_level_procedure    CONSTANT NUMBER         := fnd_log.level_procedure;
   g_level_statement    CONSTANT NUMBER         := fnd_log.level_statement;
   g_level_current      CONSTANT NUMBER    := fnd_log.g_current_runtime_level;
   g_module_current     CONSTANT VARCHAR2 (255)
                                             := 'oks.plsql.oks_int_ocint_pub';

----------------------------------------------------------------------------------------
   FUNCTION check_strmlvl_exists (p_cle_id IN NUMBER)
      RETURN NUMBER
   IS
      CURSOR l_billsch_csr (p_cle_id IN NUMBER)
      IS
         SELECT ID
           FROM oks_stream_levels_v
          WHERE cle_id = p_cle_id;

      l_strmlvl_id   NUMBER;
   BEGIN
      OPEN l_billsch_csr (p_cle_id);

      FETCH l_billsch_csr
       INTO l_strmlvl_id;

      IF (l_billsch_csr%FOUND)
      THEN
         RETURN (l_strmlvl_id);
      ELSE
         RETURN (NULL);
      END IF;

      CLOSE l_billsch_csr;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN (NULL);
   END;

   FUNCTION check_lvlelements_exists (p_cle_id IN NUMBER)
      RETURN BOOLEAN
   IS
      CURSOR l_billsll_csr (p_cle_id IN NUMBER)
      IS
         SELECT 'x'
           FROM oks_stream_levels_v sll, oks_level_elements lvl
          WHERE lvl.rul_id = sll.ID AND sll.cle_id = p_cle_id;

      v_flag   BOOLEAN      := FALSE;
      v_temp   VARCHAR2 (5);
   BEGIN
      OPEN l_billsll_csr (p_cle_id);

      FETCH l_billsll_csr
       INTO v_temp;

      IF (l_billsll_csr%FOUND)
      THEN
         v_flag := TRUE;
      ELSE
         v_flag := FALSE;
      END IF;

      CLOSE l_billsll_csr;

      RETURN (v_flag);
   END;

   PROCEDURE oc_interface (
      errbuf    OUT NOCOPY   VARCHAR2,
      retcode   OUT NOCOPY   NUMBER
   )
   IS
      l_init_msg_list              VARCHAR2 (1)       DEFAULT fnd_api.g_false;
      l_commit                     VARCHAR2 (1)       DEFAULT fnd_api.g_false;
      l_return_status              VARCHAR2 (1);
      l_msg_count                  NUMBER;
      l_msg_data                   VARCHAR2 (2000);
      l_wait                       NUMBER             DEFAULT DBMS_AQ.no_wait;
      l_no_more_messages           VARCHAR2 (240);
      l_header_rec                 oe_order_pub.header_rec_type;
      l_old_header_rec             oe_order_pub.header_rec_type;
      l_header_adj_tbl             oe_order_pub.header_adj_tbl_type;
      l_old_header_adj_tbl         oe_order_pub.header_adj_tbl_type;
      l_header_price_att_tbl       oe_order_pub.header_price_att_tbl_type;
      l_old_header_price_att_tbl   oe_order_pub.header_price_att_tbl_type;
      l_header_adj_att_tbl         oe_order_pub.header_adj_att_tbl_type;
      l_old_header_adj_att_tbl     oe_order_pub.header_adj_att_tbl_type;
      l_header_adj_assoc_tbl       oe_order_pub.header_adj_assoc_tbl_type;
      l_old_header_adj_assoc_tbl   oe_order_pub.header_adj_assoc_tbl_type;
      l_header_scredit_tbl         oe_order_pub.header_scredit_tbl_type;
      l_old_header_scredit_tbl     oe_order_pub.header_scredit_tbl_type;
      l_line_tbl                   oe_order_pub.line_tbl_type;
      l_old_line_tbl               oe_order_pub.line_tbl_type;
      l_line_adj_tbl               oe_order_pub.line_adj_tbl_type;
      l_old_line_adj_tbl           oe_order_pub.line_adj_tbl_type;
      l_line_price_att_tbl         oe_order_pub.line_price_att_tbl_type;
      l_old_line_price_att_tbl     oe_order_pub.line_price_att_tbl_type;
      l_line_adj_att_tbl           oe_order_pub.line_adj_att_tbl_type;
      l_old_line_adj_att_tbl       oe_order_pub.line_adj_att_tbl_type;
      l_line_adj_assoc_tbl         oe_order_pub.line_adj_assoc_tbl_type;
      l_old_line_adj_assoc_tbl     oe_order_pub.line_adj_assoc_tbl_type;
      l_line_scredit_tbl           oe_order_pub.line_scredit_tbl_type;
      l_old_line_scredit_tbl       oe_order_pub.line_scredit_tbl_type;
      l_lot_serial_tbl             oe_order_pub.lot_serial_tbl_type;
      l_old_lot_serial_tbl         oe_order_pub.lot_serial_tbl_type;
      l_action_request_tbl         oe_order_pub.request_tbl_type;
      l_oe_line_rec                oe_order_pub.line_rec_type;
      l_dequeue_mode               VARCHAR2 (240)      DEFAULT DBMS_AQ.remove;
      l_navigation                 VARCHAR2 (240)
                                                 DEFAULT DBMS_AQ.next_message;
      l_repv_rec                   oks_rep_pvt.repv_rec_type;
      l_out_repv_rec               oks_rep_pvt.repv_rec_type;
      l_request_id                 NUMBER;
--General Variables
      l_ctr                        NUMBER;
      l_oldline_count              NUMBER;
      l_newline_count              NUMBER;
      l_user_id                    NUMBER;
      l_index                      NUMBER;
      index1                       NUMBER;
      err_msg                      VARCHAR2 (1000)                      := '';
      l_hdrid                      NUMBER                             := NULL;
      dup_val                      VARCHAR2 (1)                         := '';
      l_ord_num                    NUMBER;
      l_exists                     VARCHAR2 (1);

      CURSOR l_order_hdr_csr (p_ordlineid NUMBER)
      IS
         SELECT oh.header_id, oh.order_number
           FROM oe_order_lines_all ol, oe_order_headers_all oh
          WHERE ol.line_id = (p_ordlineid)
            AND oh.org_id = okc_context.get_okc_org_id
            AND oh.header_id = ol.header_id;

      CURSOR l_order_csr (p_ordlineid NUMBER)
      IS
         SELECT org_id, ship_from_org_id, sold_from_org_id,
                NVL (fulfilled_quantity, 0) fqty,
                service_reference_line_id rolineid, header_id
           FROM okx_order_lines_v
          WHERE id1 = (p_ordlineid);

      CURSOR check_ordline_exists (p_ordlineid NUMBER)
      IS
         SELECT 'x'
           FROM oks_reprocessing
          WHERE order_line_id = p_ordlineid;

--Fix for bug 3492335
      CURSOR is_ib_trackable (
         l_ref_order_line_id   NUMBER,
         l_organization_id     NUMBER
      )
      IS
         SELECT comms_nl_trackable_flag
           FROM mtl_system_items_b
          WHERE inventory_item_id = (SELECT inventory_item_id
                                       FROM oe_order_lines_all
                                      WHERE line_id = l_ref_order_line_id)
            AND organization_id = l_organization_id
	    AND serviceable_product_flag = 'Y' ;  /*BUG6181908 -- FP Bug#6006309*/

--BUG6181908 --FP Bug 6006309

   Cursor csi_ib_trackable(l_ref_order_line_id Number , l_organization_id Number)
   Is
   Select mtl.comms_nl_trackable_flag
   From mtl_system_items_b mtl
       ,csi_item_instances csi
   Where csi.instance_id = l_ref_order_line_id
     and mtl.inventory_item_id = csi.inventory_item_id
     and mtl.organization_id = l_organization_id
     and mtl. serviceable_product_flag = 'Y';

--BUG6181908 --FP Bug 6006309

      l_order_rec                  l_order_csr%ROWTYPE;
      l_api_version       CONSTANT NUMBER                               := 1.0;
      x_msg_count                  NUMBER;
      x_msg_data                   VARCHAR2 (2000);
      ib_flag                      VARCHAR2 (1);
--
      aso_handle_exception         EXCEPTION;
      aso_handle_normal            EXCEPTION;
   BEGIN
      SAVEPOINT oks_ocinterface_pub;
      fnd_file.put_line (fnd_file.LOG, 'Start of OC_interface...');
      l_user_id := fnd_global.user_id;
      fnd_file.put_line (fnd_file.LOG, 'User Id : ' || TO_CHAR (l_user_id));

      LOOP
         l_oldline_count := 0;
         l_newline_count := 0;
         aso_order_feedback_pub.get_notice
                   (p_api_version                   => 1.0,
                    p_init_msg_list                 => l_init_msg_list,
                    p_commit                        => l_commit,
                    x_return_status                 => l_return_status,
                    x_msg_count                     => l_msg_count,
                    x_msg_data                      => l_msg_data,
                    p_app_short_name                => 'OKS',
                    p_wait                          => l_wait,
                    x_no_more_messages              => l_no_more_messages,
                    x_header_rec                    => l_header_rec,
                    x_old_header_rec                => l_old_header_rec,
                    x_header_adj_tbl                => l_header_adj_tbl,
                    x_old_header_adj_tbl            => l_old_header_adj_tbl,
                    x_header_price_att_tbl          => l_header_price_att_tbl,
                    x_old_header_price_att_tbl      => l_old_header_price_att_tbl,
                    x_header_adj_att_tbl            => l_header_adj_att_tbl,
                    x_old_header_adj_att_tbl        => l_old_header_adj_att_tbl,
                    x_header_adj_assoc_tbl          => l_header_adj_assoc_tbl,
                    x_old_header_adj_assoc_tbl      => l_old_header_adj_assoc_tbl,
                    x_header_scredit_tbl            => l_header_scredit_tbl,
                    x_old_header_scredit_tbl        => l_old_header_scredit_tbl,
                    x_line_tbl                      => l_line_tbl,
                    x_old_line_tbl                  => l_old_line_tbl,
                    x_line_adj_tbl                  => l_line_adj_tbl,
                    x_old_line_adj_tbl              => l_old_line_adj_tbl,
                    x_line_price_att_tbl            => l_line_price_att_tbl,
                    x_old_line_price_att_tbl        => l_old_line_price_att_tbl,
                    x_line_adj_att_tbl              => l_line_adj_att_tbl,
                    x_old_line_adj_att_tbl          => l_old_line_adj_att_tbl,
                    x_line_adj_assoc_tbl            => l_line_adj_assoc_tbl,
                    x_old_line_adj_assoc_tbl        => l_old_line_adj_assoc_tbl,
                    x_line_scredit_tbl              => l_line_scredit_tbl,
                    x_old_line_scredit_tbl          => l_old_line_scredit_tbl,
                    x_lot_serial_tbl                => l_lot_serial_tbl,
                    x_old_lot_serial_tbl            => l_old_lot_serial_tbl,
                    x_action_request_tbl            => l_action_request_tbl
                   );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success)
         THEN
            FOR i IN 1 .. fnd_msg_pub.count_msg
            LOOP
               fnd_msg_pub.get (p_msg_index          => -1,
                                p_encoded            => 'F',
                                p_data               => l_msg_data,
                                p_msg_index_out      => l_index
                               );
               fnd_file.put_line (fnd_file.LOG, l_msg_data);
            END LOOP;

            ROLLBACK TO oks_ocinterface_pub;
            RETURN;
         END IF;

         l_newline_count := l_line_tbl.COUNT;
         fnd_file.put_line (fnd_file.LOG,
                            'Lines to process = ' || l_newline_count
                           );
         EXIT WHEN l_no_more_messages = fnd_api.g_true;

         IF l_newline_count <= 0
         THEN                                        --Order Line Record Found
            fnd_file.put_line (fnd_file.LOG, 'No lines to insert');
         ELSE
            fnd_file.put_line (fnd_file.LOG,
                                  'Processing the order lines... line count='
                               || TO_CHAR (l_newline_count)
                              );

            FOR l_count IN 1 .. l_newline_count
            LOOP
               l_exists := 'y';
               fnd_file.put_line (fnd_file.LOG,
                                     'Processing Order Line '
                                  || l_line_tbl (l_count).line_id
                                 );
               fnd_file.put_line
                              (fnd_file.LOG,
                                  'Service Ref Type Code '
                               || l_line_tbl (l_count).service_reference_type_code
                              );
               fnd_file.put_line
                                (fnd_file.LOG,
                                    'Service line Id       '
                                 || l_line_tbl (l_count).service_reference_line_id
                                );
               fnd_file.put_line
                         (fnd_file.LOG,
                             'Profile option value  '
                          || fnd_profile.VALUE
                                            ('OKS_CONTRACTS_VALIDATION_SOURCE')
                         );

               OPEN check_ordline_exists (l_line_tbl (l_count).line_id);

               FETCH check_ordline_exists
                INTO l_exists;

               IF check_ordline_exists%NOTFOUND
               THEN
                  l_exists := 'y';
               END IF;

               CLOSE check_ordline_exists;

               --Check Delayed Service
               IF (l_exists <> 'x')
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                     'Order line not present already...'
                                    );

                  IF     NVL (l_line_tbl (l_count).service_reference_type_code,
                              'REF_TYPE'
                             ) IN ('CUSTOMER_PRODUCT', 'ORDER')
                     AND l_line_tbl (l_count).service_reference_line_id IS NOT NULL
                  THEN                              --Checking Delayed Service
                     --Check Fulfillment
                     l_order_rec.fqty := 0;
                     l_order_rec.rolineid := NULL;
                     l_order_rec.header_id := NULL;

                     OPEN l_order_csr (l_line_tbl (l_count).line_id);

                     FETCH l_order_csr
                      INTO l_order_rec;

                     IF l_order_csr%NOTFOUND
                     THEN
                        l_order_rec.fqty := 0;
                     END IF;

                     CLOSE l_order_csr;

                     fnd_file.put_line (fnd_file.LOG,
                                           'Fulfillment Quantity  '
                                        || l_order_rec.fqty
                                       );
                     fnd_file.put_line (fnd_file.LOG,
                                           'Order Org Id          '
                                        || l_order_rec.org_id
                                       );
                     fnd_file.put_line (fnd_file.LOG,
                                           'Order Organization Id '
                                        || l_order_rec.ship_from_org_id
                                       );
                     fnd_file.put_line (fnd_file.LOG,
                                           'Sold from Org Id      '
                                        || l_order_rec.sold_from_org_id
                                       );
                     okc_context.set_okc_org_context (l_order_rec.org_id,
                                                      NULL);
                     fnd_file.put_line (fnd_file.LOG,
                                           'org_context - '
                                        || TO_CHAR (okc_context.get_okc_org_id)
                                       );
                     fnd_file.put_line
                                 (fnd_file.LOG,
                                     'organization_context - '
                                  || TO_CHAR
                                          (okc_context.get_okc_organization_id)
                                 );

--Check IB Trackable flag
                     IF NVL (l_line_tbl (l_count).service_reference_type_code,
                             'REF_TYPE'
                            ) = 'ORDER'
                     THEN
                        OPEN is_ib_trackable
                               (l_line_tbl (l_count).service_reference_line_id,
                                okc_context.get_okc_organization_id
                               );

                        FETCH is_ib_trackable
                         INTO ib_flag;

                        CLOSE is_ib_trackable;
                     ELSE
			--BUG6181908 --FP Bug 6006309
  			-- ib_flag := 'Y';
 			Open csi_ib_trackable(l_line_tbl(l_count).service_reference_line_id, okc_context.get_okc_organization_id);
 			Fetch csi_ib_trackable into ib_flag;
 			Close csi_ib_trackable;
			--BUG6181908 --FP Bug 6006309

                     END IF;

                     IF NVL (ib_flag, 'N') = 'Y'
                     THEN
                        IF l_order_rec.fqty > 0
                        THEN
                           OPEN l_order_hdr_csr (l_line_tbl (l_count).line_id);

                           FETCH l_order_hdr_csr
                            INTO l_hdrid, l_ord_num;

                           IF l_order_hdr_csr%NOTFOUND
                           THEN
                              fnd_file.put_line (fnd_file.LOG,
                                                 ' Invalid Order line ID'
                                                );

                              CLOSE l_order_hdr_csr;
                           ELSE
                              CLOSE l_order_hdr_csr;

                              fnd_file.put_line (fnd_file.LOG,
                                                 'Order Header ID ' || l_hdrid
                                                );
                              l_repv_rec.order_id := l_hdrid;
                              l_repv_rec.order_line_id :=
                                                  l_line_tbl (l_count).line_id;
                              l_repv_rec.order_number := l_ord_num;
                              l_repv_rec.success_flag := 'N';
                              l_repv_rec.source_flag := 'ASO';
                              l_repv_rec.reprocess_yn := 'Y';
                              SAVEPOINT before_insert;
                              oks_rep_pub.insert_row
                                          (p_api_version        => 1.0,
                                           p_init_msg_list      => l_init_msg_list,
                                           x_return_status      => l_return_status,
                                           x_msg_count          => l_msg_count,
                                           x_msg_data           => l_msg_data,
                                           p_repv_rec           => l_repv_rec,
                                           x_repv_rec           => l_out_repv_rec
                                          );
                              fnd_file.put_line
                                          (fnd_file.LOG,
                                              'OKS_REP_PUB - RETURN STATUS : '
                                           || l_return_status
                                          );

                              IF NOT (l_return_status =
                                                     fnd_api.g_ret_sts_success
                                     )
                              THEN
                                 FOR i IN 1 .. fnd_msg_pub.count_msg
                                 LOOP
                                    fnd_msg_pub.get
                                                  (p_msg_index          => -1,
                                                   p_encoded            => 'F',
                                                   p_data               => l_msg_data,
                                                   p_msg_index_out      => l_index
                                                  );

                                    SELECT INSTR (l_msg_data,
                                                  'ORA-00001',
                                                  1,
                                                  1
                                                 )
                                      INTO index1
                                      FROM DUAL;

                                    IF (index1 > 0)
                                    THEN
                                       dup_val := 'Y';
                                       EXIT;
                                    END IF;

                                    fnd_file.put_line
                                                (fnd_file.LOG,
                                                    'oks_rep_pub.insert_row: '
                                                 || l_msg_data
                                                );
                                 END LOOP;

                                 IF (dup_val <> 'Y')
                                 THEN
                                    RAISE g_exception_halt_validation;
                                 END IF;

                                 l_return_status := fnd_api.g_ret_sts_success;
                              END IF;
                           END IF;
                        END IF;
                     END IF;
                  END IF;
               ELSE
                  fnd_file.put_line (fnd_file.LOG, 'Duplicate Order Line');
               END IF;
            END LOOP;
         END IF;
      END LOOP;

      errbuf := '';
      retcode := 0;
--Modified for 12.0 ASO Queue Replacement Project (JVARGHES)
      COMMIT WORK;
--
      fnd_file.put_line (fnd_file.LOG, 'Order Capture INT Program finished.');
--Modified for 12.0 ASO Queue Replacement Project (JVARGHES)
--
--l_request_id := FND_REQUEST.SUBMIT_REQUEST('OKS','OKSREPROC','','',FALSE,'SEL','');
--if (l_request_id > 0) then
-- COMMIT WORK;
--end if;
--FND_FILE.PUT_LINE (FND_FILE.LOG, 'Firing Order Reprocess concurrent program');
--FND_FILE.PUT_LINE (FND_FILE.LOG, 'Request Id - '||to_char(l_request_id));
--
--
   EXCEPTION
      WHEN g_exception_halt_validation
      THEN
         ROLLBACK TO before_insert;
      WHEN OTHERS
      THEN
         ROLLBACK TO before_insert;
         -- Retrieve error message into errbuf
         errbuf := SQLERRM;
         retcode := 2;
         fnd_file.put_line (fnd_file.LOG,
                            'Oracle Error Code is -' || TO_CHAR (SQLCODE)
                           );
         fnd_file.put_line (fnd_file.LOG,
                               'Oracle Error Message is -'
                            || SUBSTR (SQLERRM, 1, 512)
                           );
   END oc_interface;

   PROCEDURE handle_order_error (
      x_return_status   OUT NOCOPY      VARCHAR2,
      p_upd_rec         IN              oks_rep_pvt.repv_rec_type
   )
   IS
      CURSOR l_old_repv_csr (p_id NUMBER)
      IS
         SELECT object_version_number
           FROM oks_reprocessing_v
          WHERE ID = p_id;

      --l_old_repv_rec    l_old_repv_csr%ROWTYPE;
      l_obj_vers_num    NUMBER;
      l_new_repv_rec    oks_rep_pvt.repv_rec_type;
      l_repv_rec        oks_rep_pvt.repv_rec_type;
      l_return_status   VARCHAR2 (1)             := okc_api.g_ret_sts_success;
      l_msg_count       NUMBER;
      l_msg_data        VARCHAR2 (2000);
      l_index           NUMBER;
   BEGIN
      x_return_status := l_return_status;

      OPEN l_old_repv_csr (p_upd_rec.ID);

      FETCH l_old_repv_csr
       INTO l_obj_vers_num;

      CLOSE l_old_repv_csr;

      l_repv_rec.ID := p_upd_rec.ID;

      IF (p_upd_rec.order_line_id IS NOT NULL)
      THEN
         l_repv_rec.order_line_id := p_upd_rec.order_line_id;
      END IF;

      l_repv_rec.object_version_number := l_obj_vers_num;
      l_repv_rec.ERROR_TEXT := p_upd_rec.ERROR_TEXT;
      l_repv_rec.success_flag := p_upd_rec.success_flag;
      l_repv_rec.contract_id := p_upd_rec.contract_id;
      l_repv_rec.contract_line_id := p_upd_rec.contract_line_id;
      l_repv_rec.subline_id := p_upd_rec.subline_id;
      l_repv_rec.conc_request_id := p_upd_rec.conc_request_id;
      l_repv_rec.reprocess_yn := 'N';
      oks_rep_pub.update_row (p_api_version        => 1.0,
                              p_init_msg_list      => 'T',
                              x_return_status      => l_return_status,
                              x_msg_count          => l_msg_count,
                              x_msg_data           => l_msg_data,
                              p_repv_rec           => l_repv_rec,
                              x_repv_rec           => l_new_repv_rec
                             );
      fnd_file.put_line (fnd_file.LOG,
                         'Update Row : Return Status = ' || l_return_status
                        );

      IF NOT (l_return_status = fnd_api.g_ret_sts_success)
      THEN
         FOR i IN 1 .. fnd_msg_pub.count_msg
         LOOP
            fnd_msg_pub.get (p_msg_index          => -1,
                             p_encoded            => 'F',
                             p_data               => l_msg_data,
                             p_msg_index_out      => l_index
                            );
            fnd_file.put_line (fnd_file.LOG,
                               'Update Row Error : ' || l_msg_data
                              );
         END LOOP;

         RAISE g_exception_halt_validation;
      END IF;
   EXCEPTION
      WHEN g_exception_halt_validation
      THEN
         fnd_file.put_line
                   (fnd_file.LOG,
                       'Error in Handle Order Error : Oracle Error Code is -'
                    || TO_CHAR (SQLCODE)
                   );
         fnd_file.put_line
                 (fnd_file.LOG,
                     'Error in Handle Order Error : Oracle Error Message is -'
                  || SUBSTR (SQLERRM, 1, 512)
                 );
         x_return_status := l_return_status;
      WHEN OTHERS
      THEN
         x_return_status := okc_api.g_ret_sts_unexp_error;
         fnd_file.put_line (fnd_file.LOG,
                            'Oracle Error Code is -' || TO_CHAR (SQLCODE)
                           );
         fnd_file.put_line (fnd_file.LOG,
                               'Oracle Error Message is -'
                            || SUBSTR (SQLERRM, 1, 512)
                           );
   END handle_order_error;

  --------------------------------------------------------------------
  --  name:            order_reprocess
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   22/04/2012
  --------------------------------------------------------------------
  --  purpose :        order_reprocess
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/04/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE order_reprocess ( errbuf     OUT NOCOPY      VARCHAR2,
                              retcode    OUT NOCOPY      NUMBER,
                              p_option   IN              VARCHAR2,
                              p_source   IN              VARCHAR2
                            ) IS
    l_init_msg_list           VARCHAR2 (1)      DEFAULT fnd_api.g_false;
    --l_commit                  VARCHAR2 (1)      DEFAULT fnd_api.g_false;
    l_return_status           VARCHAR2 (1);
    l_msg_count               NUMBER;
    l_msg_data                VARCHAR2 (2000);
    --l_wait                    NUMBER            DEFAULT DBMS_AQ.no_wait;
    --l_dequeue_mode            VARCHAR2 (240)    DEFAULT DBMS_AQ.remove;
    --l_navigation              VARCHAR2 (240)    DEFAULT DBMS_AQ.next_message;
    --General Variables
    --l_ctr                     NUMBER;
    l_line_count              NUMBER;
    --l_user_id                 NUMBER;
    --l_organization_id         NUMBER;
    l_k_line_id               NUMBER            := NULL;
    --Header
    l_k_header_rec            oks_extwar_util_pvt.header_rec_type;
    --Line
    l_k_line_rec              oks_extwar_util_pvt.line_rec_type;
    --SalesCredit
    l_salescredit_tbl_in      oks_extwarprgm_pvt.salescredit_tbl;
    --Pricing Attributes
    l_pricing_attributes_in   oks_extwarprgm_pvt.pricing_attributes_type;
    --For Creating Contract
    --l_extwar_rec              oks_extwarprgm_pvt.extwar_rec_type;
    l_cp_id                   NUMBER;
    l_cp_name                 VARCHAR2 (240);
    l_cp_desc                 VARCHAR2 (240);
    l_cp_qty                  NUMBER;
    l_cp_uom                  VARCHAR2 (3);
    l_fulfill                 VARCHAR2 (1)      := 'Y';
    l_prog_id                 NUMBER;
    l_req_id                  NUMBER;

    CURSOR l_cp_csr (cpid NUMBER) IS
      SELECT csi.instance_id cp_id, csi.inventory_item_id, mtl.NAME NAME,
             mtl.description description, csi.quantity quantity,
             csi.unit_of_measure uom_code
      FROM   csi_item_instances csi, okx_system_items_v mtl
      WHERE  csi.instance_id = cpid
      AND    mtl.inventory_item_id = csi.inventory_item_id
      AND    ROWNUM < 2;

    TYPE cp_rec_type IS RECORD ( cp_id   NUMBER);

    TYPE cp_tbl_type IS TABLE OF cp_rec_type
    INDEX BY BINARY_INTEGER;

    CURSOR l_order_csr (p_ordlineid NUMBER) IS
      SELECT org_id, ship_from_org_id, sold_from_org_id,
             NVL (fulfilled_quantity, 0) fqty,
             service_reference_line_id rolineid, header_id
      FROM   okx_order_lines_v
      WHERE  id1 = (p_ordlineid);

    CURSOR l_contract_csr (p_ordlineid NUMBER) IS
      SELECT rel.cle_id, rel.chr_id
      FROM   okc_k_rel_objs_v rel, okc_k_lines_b line
      WHERE  rel.object1_id1 = TO_CHAR (p_ordlineid)
      AND    rel.jtot_object1_code = 'OKX_ORDERLINE'
      AND    line.ID = rel.cle_id
      AND    line.lse_id IN (9, 25);

    CURSOR l_contact_csr (p_line_id NUMBER) IS
      SELECT oc.object1_id1, oc.cro_code
      FROM   oks_k_order_contacts_v oc, oks_k_order_details_v od
      WHERE  oc.cod_id = od.ID AND od.order_line_id1 = p_line_id;
    /*
	  Cursor l_custprod_csr (p_ordlineid Number, c_organization_id NUMBER) IS
	   SELECT csi.instance_id cp_id
	     FROM   csi_item_instances csi
 	         ,csi_instance_statuses st
                 ,mtl_system_items_b mtl
 	    WHERE csi.last_oe_order_line_id = p_ordlineid
   	      AND csi.instance_status_id = st.instance_status_id
              AND mtl.inventory_item_id = csi.inventory_item_id
              AND mtl.organization_id = c_organization_id
              AND Nvl(st.service_order_allowed_flag,'N') = 'Y'
       	      AND mtl.comms_nl_trackable_flag = 'Y'
              AND mtl.serviceable_product_flag = 'Y' ;*/
              
    --  1.0  22/04/2012  Dalit A. Raviv
    Cursor l_custprod_csr (p_ordlineid       Number,
                           c_organization_id number) is
      select csi.instance_id              cp_id
      from   csi_item_instances           csi,
             csi_instance_statuses        st,
             mtl_system_items_b           mtl,
             mtl_categories_b             mcb,
             mtl_item_categories          mic 
      where  csi.last_oe_order_line_id    = p_ordlineid
      and    csi.instance_status_id       = st.instance_status_id
      and    mtl.inventory_item_id        = csi.inventory_item_id
      and    mtl.organization_id          = c_organization_id
      and    nvl(st.service_order_allowed_flag,'N') = 'Y'
      and    mtl.comms_nl_trackable_flag  = 'Y'
      and    mtl.serviceable_product_flag = 'Y'
      and    mtl.inventory_item_id        = csi.inventory_item_id
      and    mtl.inventory_item_id        = mic.inventory_item_id
      and    mcb.category_id              = mic.category_id
      and    mtl.organization_id          = mic.organization_id --91
      --and    mic.organization_id          = 91
      and    (mcb.attribute4              = 'PRINTER' or mcb.category_id = 7127)
      and    csi.serial_number            is not null;
/*
    CURSOR l_organization_csr (p_org_id NUMBER) IS
      SELECT master_organization_id
      FROM   oe_system_parameters_all
      WHERE  org_id = p_org_id;
*/
    CURSOR l_serv_ref_csr (p_ordline_id NUMBER) IS
      SELECT service_reference_type_code, service_reference_line_id
      FROM okx_order_lines_v
      WHERE id1 = p_ordline_id;

    CURSOR l_contract_line_csr (p_subline_id NUMBER) IS
      SELECT cle_id
      FROM okc_k_lines_b
      WHERE ID = p_subline_id;

    --General
    l_index                   NUMBER;
    l_process                 BOOLEAN;
    l_order_rec               l_order_csr%ROWTYPE;
    l_ref_order_rec           l_order_csr%ROWTYPE;
    l_cp_tbl                  cp_tbl_type;
    l_cp_ctr                  NUMBER                                    := 0;
    l_hdr_rec                 oks_extwarprgm_pvt.k_header_rec_type;
    l_line_rec                oks_extwarprgm_pvt.k_line_service_rec_type;
    l_covd_rec                oks_extwarprgm_pvt.k_line_covered_level_rec_type;
    l_chrid                   NUMBER                                 := NULL;
    l_lineid                  NUMBER                                 := NULL;
    l_rnrl_rec_out            oks_renew_util_pvt.rnrl_rec_type;
    l_renewal_rec             oks_extwar_util_pvt.renewal_rec_type;
    l_contact_tbl             oks_extwarprgm_pvt.contact_tbl;
    l_ptr1                    NUMBER                                    := 0;
    l_covlvl_id               NUMBER;
    --l_rule_id                 NUMBER;
    --l_rule_group_id           NUMBER;
    l_api_version    CONSTANT NUMBER                                  := 1.0;
    l_update_line             VARCHAR2 (1);
    l_duration                NUMBER;
    l_timeunits               VARCHAR2 (240);
    l_sll_tbl                 oks_bill_sch.streamlvl_tbl;
    l_bil_sch_out             oks_bill_sch.itembillsch_tbl;
    x_msg_count               NUMBER;
    x_msg_data                VARCHAR2 (2000);
    x_return_status           VARCHAR2 (1)      := okc_api.g_ret_sts_success;
    l_repv_tbl                oks_rep_pvt.repv_tbl_type;
    l_reproc_line_rec         oks_rep_pvt.repv_rec_type;
    l_serv_ref_rec            l_serv_ref_csr%ROWTYPE;
    l_upd_tbl                 oks_rep_pvt.repv_tbl_type;
    l_out_repv_rec            oks_rep_pvt.repv_rec_type;
    l_conc_rec                oks_rep_pvt.repv_rec_type;
    i                         NUMBER;
    l_ctr1                    NUMBER;
    l_cont_line_id            NUMBER;
    --l_dummy                   VARCHAR2 (30);
    l_error_temp              VARCHAR2 (2000);
    l_error_msg               VARCHAR2 (2000);

    l_process_status          VARCHAR2(20);

      PROCEDURE create_contract (p_reproc_line_rec                oks_rep_pvt.repv_rec_type,
                                 x_upd_tbl           OUT NOCOPY   oks_rep_pvt.repv_tbl_type,
                                 x_return_status     OUT NOCOPY   VARCHAR2   ) IS
         CURSOR l_party_csr  IS
            SELECT NAME
              FROM okx_parties_v
             WHERE id1 = l_k_header_rec.party_id;

         -- cursor to get ship and installation dates
         -- vigandhi 04-jun-2002
         CURSOR l_get_dates_csr (p_cp_id NUMBER)
         IS
            SELECT csi.install_date, ol.actual_shipment_date,
                   mtl.service_starting_delay
              FROM csi_item_instances csi,
                   oe_order_lines_all ol,
                   okx_system_items_v mtl
             WHERE csi.instance_id = p_cp_id
               AND csi.last_oe_order_line_id = ol.line_id
               AND csi.inventory_item_id = mtl.id1
               AND ROWNUM < 2;

         CURSOR l_hdr_scs_csr (p_chr_id NUMBER)
         IS
            SELECT scs_code
              FROM okc_k_headers_v
             WHERE ID = p_chr_id;

         CURSOR l_inv_csr (p_ordline_id NUMBER)
         IS
            SELECT inventory_item_id
              FROM oe_order_lines                          --mmadhavi for MOAC
             WHERE line_id = p_ordline_id;

         CURSOR l_lndates_csr (p_id NUMBER)
         IS
            SELECT start_date, end_date
              FROM okc_k_lines_b
             WHERE ID = p_id;

         CURSOR l_hdrdates_csr (p_id NUMBER)
         IS
            SELECT start_date, end_date, sts_code
              FROM okc_k_headers_b
             WHERE ID = p_id;

         CURSOR l_refnum_csr (p_cp_id NUMBER)
         IS
            SELECT instance_number
              FROM csi_item_instances
             WHERE instance_id = p_cp_id;


         -- Cursor to roll up the tax amount from sublines to the topline

         CURSOR c_extwar_line_amount(p_chr_id IN NUMBER, p_line_id IN NUMBER) IS
         SELECT
             SUM(NVL(slines.tax_amount,0)) tax_amount
         FROM
              okc_k_lines_b clines
             ,oks_k_lines_b slines
         WHERE
             clines.dnz_chr_id = p_chr_id
         and clines.cle_id = p_line_id
         and clines.id = slines.cle_id;

        -- Cursor to rollup the tax amount from toplines to header

        CURSOR c_extwar_hdr_amount(p_chr_id IN NUMBER) IS
        SELECT
             SUM(NVL(slines.tax_amount,0)) tax_amount
        FROM
             okc_k_lines_b clines
            ,oks_k_lines_b slines
        WHERE
            clines.dnz_chr_id = p_chr_id
        AND clines.lse_id IN (1, 19)
        AND clines.id = slines.cle_id;

         l_hdr_scs_code        VARCHAR2 (30);
         l_party_name          okx_parties_v.NAME%TYPE;
         l_get_dates_rec       l_get_dates_csr%ROWTYPE;
         l_sts_code            VARCHAR2 (30);
         l_ste_code            VARCHAR2 (30);
         l_ship_date           DATE;
         l_installation_date   DATE;
         l_strmlvl_id          NUMBER;
         l_cp_inventory        NUMBER;
         l_inv_item_id         NUMBER;
         l_serv_ref_rec        l_serv_ref_csr%ROWTYPE;
         l_order_error         VARCHAR2 (2000);
         l_lndates_rec         l_lndates_csr%ROWTYPE;
         l_hdrdates_rec        l_hdrdates_csr%ROWTYPE;
         l_ref_num             VARCHAR2 (30);
         l_inst_dtls_rec       oks_ihd_pvt.ihdv_rec_type;
         l_insthist_rec        oks_ins_pvt.insv_rec_type;
         x_inst_dtls_rec       oks_ihd_pvt.ihdv_rec_type;
         x_insthist_rec        oks_ins_pvt.insv_rec_type;
         l_error               VARCHAR2 (1)                        := 'N';
         l_header_id           NUMBER;
         l_period_start        oks_k_headers_v.period_start%TYPE;
         l_period_type         oks_k_headers_v.period_type%TYPE;
         l_price_uom           oks_k_headers_v.price_uom%TYPE;
         l_line_tax_amount     NUMBER;
         l_header_tax_amount   NUMBER;

         -- Added fro fix of bug# 5165947

         l_BOM_instance_id     NUMBER;
         l_BOM_instance_flag   VARCHAR2(10);
         l_eff_line_upd_flag   VARCHAR2(10);

         l_prev_line_amt       NUMBER;
         l_curr_line_amt       NUMBER;

         cursor c_line_ammt_ckeck(c_line_id in number)
          is select nvl(price_negotiated,0) from okc_k_lines_b where id = c_line_id;

         -- Added fro fix of bug# 5165947

      BEGIN
         x_upd_tbl.DELETE;

         OPEN l_get_dates_csr (l_cp_tbl (1).cp_id);

         FETCH l_get_dates_csr
          INTO l_get_dates_rec;

         CLOSE l_get_dates_csr;
	 /* Fix for 6389290 */
	 x_upd_tbl (1).order_line_id := p_reproc_line_rec.order_line_id;
	 /* Fix Ends */
         l_ship_date :=
              TRUNC (l_get_dates_rec.actual_shipment_date)
            + NVL (l_get_dates_rec.service_starting_delay, 0);
         l_installation_date := TRUNC (l_get_dates_rec.install_date);
         oks_extwar_util_pvt.get_contract_header_info
                          (p_order_line_id      => p_reproc_line_rec.order_line_id,
                           p_cp_id              => NULL,
                           p_caller             => 'OC',
                           x_order_error        => l_order_error,
                           x_return_status      => l_return_status,
                           x_header_rec         => l_k_header_rec
                          );
         fnd_file.put_line
                        (fnd_file.LOG,'OC INTERFACE :- get_contract_header_info status '|| l_return_status );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success)
         THEN
            IF l_order_error IS NULL
            THEN
               l_order_error := '#';

               FOR i IN 1 .. fnd_msg_pub.count_msg
               LOOP
                  fnd_msg_pub.get (p_msg_index          => i,
                                   p_encoded            => 'T',
                                   p_data               => l_msg_data,
                                   p_msg_index_out      => l_index
                                  );
                  l_order_error := l_order_error || l_msg_data || '#';
                  fnd_message.set_encoded (l_msg_data);
                  l_msg_data := fnd_message.get;
                  fnd_file.put_line (fnd_file.LOG,'GET CONTRACT HDR FAILURE ' || l_msg_data);
               END LOOP;
            END IF;

            x_upd_tbl (1).ERROR_TEXT := l_order_error;
            x_upd_tbl (1).success_flag := 'E';
            x_upd_tbl (1).order_line_id := p_reproc_line_rec.order_line_id;
            x_upd_tbl (1).ID := p_reproc_line_rec.ID;
            RAISE g_exception_halt_validation;
         END IF;

         oks_extwar_util_pvt.get_k_service_line
                          (p_order_line_id          => p_reproc_line_rec.order_line_id,
                           p_cp_id                  => l_cp_tbl (1).cp_id,
                           p_shipped_date           => l_ship_date,
                           p_installation_date      => l_installation_date,
                           p_caller                 => 'OC',
                           x_order_error            => l_order_error,
                           x_return_status          => l_return_status,
                           x_line_rec               => l_k_line_rec
                          );
         fnd_file.put_line (fnd_file.LOG,'OC INTERFACE :- get_k_service_line status '|| l_return_status );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success) THEN
            IF l_order_error IS NULL  THEN
               l_order_error := '#';

               FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
                  fnd_msg_pub.get (p_msg_index          => i,
                                   p_encoded            => 'T',
                                   p_data               => l_msg_data,
                                   p_msg_index_out      => l_index
                                  );
                  l_order_error := l_order_error || l_msg_data || '#';
                  fnd_message.set_encoded (l_msg_data);
                  l_msg_data := fnd_message.get;
                  fnd_file.put_line (fnd_file.LOG, 'GET ORDER LINE FAILURE ' || l_msg_data  );
               END LOOP;
            END IF;

            x_upd_tbl (1).ERROR_TEXT := l_order_error;
            x_upd_tbl (1).success_flag := 'E';
            x_upd_tbl (1).order_line_id := p_reproc_line_rec.order_line_id;
            x_upd_tbl (1).ID := p_reproc_line_rec.ID;
            RAISE g_exception_halt_validation;
         END IF;

         oks_renew_util_pub.get_renew_rules
                                 (p_api_version        => 1.0,
                                  p_init_msg_list      => 'T',
                                  x_return_status      => l_return_status,
                                  x_msg_count          => l_msg_count,
                                  x_msg_data           => l_msg_data,
                                  p_chr_id             => NULL,
                                  p_party_id           => l_k_header_rec.party_id,
                                  p_org_id             => l_k_header_rec.authoring_org_id,
                                  p_date               => SYSDATE,
                                  p_rnrl_rec           => NULL,
                                  x_rnrl_rec           => l_rnrl_rec_out
                                 );
         fnd_file.put_line (fnd_file.LOG, 'OC INTERFACE :- get_renew_rules status ' || l_return_status );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success) THEN
            FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
               fnd_msg_pub.get (p_msg_index          => -1,
                                p_encoded            => 'F',
                                p_data               => l_msg_data,
                                p_msg_index_out      => l_index
                               );
               fnd_file.put_line (fnd_file.LOG, 'RENEWAL RULE FAILURE ' || l_msg_data );
            END LOOP;

            RAISE g_exception_halt_validation;
         END IF;

         oks_integration_util_pub.create_k_order_details
                                  (p_header_id          => l_k_header_rec.order_hdr_id,
                                   x_return_status      => l_return_status,
                                   x_msg_count          => l_msg_count,
                                   x_msg_data           => l_msg_data
                                  );
         fnd_file.put_line (fnd_file.LOG, 'OC INTERFACE :- get_K_order_details status ' || l_return_status );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success) THEN
            FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
               fnd_msg_pub.get (p_msg_index          => -1,
                                p_encoded            => 'F',
                                p_data               => l_msg_data,
                                p_msg_index_out      => l_index
                               );
               fnd_file.put_line (fnd_file.LOG,
                                  'ORDER DETAIL FAILURE ' || l_msg_data
                                 );
            END LOOP;

            RAISE g_exception_halt_validation;
         END IF;

         oks_extwar_util_pvt.get_k_order_details
                                             (p_reproc_line_rec.order_line_id,
                                              l_renewal_rec
                                             );
--mmadhavi added following logic for Partial Periods Computation
         oks_renew_util_pub.get_period_defaults
                                 (p_hdr_id             => NULL,
                                  p_org_id             => l_k_header_rec.authoring_org_id,
                                  x_period_type        => l_period_type,
                                  x_period_start       => l_period_start,
                                  x_price_uom          => l_price_uom,
                                  x_return_status      => l_return_status
                                 );

         --25-JAN-2006 mchoudha for partial periods CR-003
         --All the extended warranty contracts created from order management will have Service
         --stamped on them if GCD is setup. Period Type will be pulled from GCD.
         IF l_period_start IS NOT NULL AND l_period_type IS NOT NULL  THEN
            l_period_start := 'SERVICE';
            --22-MAR-2006 mchoudha Changes for partial periods CR3
            --Period type will be picked up from GCD and not hard coded
            --l_period_type := 'FIXED';
         END IF;

         fnd_file.put_line (fnd_file.LOG,'OC INTERFACE :- get_period_defaults ' || l_return_status);
         fnd_file.put_line
                     (fnd_file.LOG,'OC INTERFACE :- get_period_defaults l_period_start '|| l_period_start);
         fnd_file.put_line
                      (fnd_file.LOG, 'OC INTERFACE :- get_period_defaults l_period_type ' || l_period_type );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success)  THEN
            FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
               fnd_msg_pub.get (p_msg_index          => -1,
                                p_encoded            => 'F',
                                p_data               => l_msg_data,
                                p_msg_index_out      => l_index
                               );
               fnd_file.put_line (fnd_file.LOG,'get_period_defaults FAILURE ' || l_msg_data );
            END LOOP;

            RAISE g_exception_halt_validation;
         END IF;

--mmadhavi end Partial Periods logic
         IF    l_renewal_rec.chr_id IS NOT NULL  OR l_renewal_rec.link_chr_id IS NOT NULL  THEN
            l_hdr_rec.merge_type := 'LTC';
            l_hdr_rec.merge_object_id := NVL (l_renewal_rec.chr_id, l_renewal_rec.link_chr_id);
         ELSE
            l_hdr_rec.merge_type := 'NEW';
            l_hdr_rec.merge_object_id := NULL;
         END IF;

         fnd_file.put_line (fnd_file.LOG, 'OC INTERFACE :- Create K Hdr status '|| l_return_status);

         OPEN l_party_csr;
         FETCH l_party_csr INTO l_party_name;
         CLOSE l_party_csr;

         fnd_file.put_line (fnd_file.LOG, 'OC INTERFACE :- party name ' || l_party_name );

         IF fnd_profile.VALUE ('OKS_CONTRACT_CATEGORY') = 'SERVICE' THEN
            l_line_rec.warranty_flag := 'S';
            l_covd_rec.warranty_flag := 'S';
            l_hdr_rec.scs_code := 'SERVICE';
            l_hdr_rec.short_description := 'CUSTOMER:  ' || l_party_name || ' Contract';
         ELSIF fnd_profile.VALUE ('OKS_CONTRACT_CATEGORY') = 'SUBSCRIPTION'  THEN
            l_line_rec.warranty_flag := 'SU';
            l_hdr_rec.scs_code := 'SUBSCRIPTION';
            l_covd_rec.warranty_flag := 'SU';
            l_hdr_rec.short_description :=  'CUSTOMER:  ' || l_party_name || '   Contract';
         ELSIF fnd_profile.VALUE ('OKS_CONTRACT_CATEGORY') = 'WARRANTY'
               OR fnd_profile.VALUE ('OKS_CONTRACT_CATEGORY') IS NULL  THEN
            l_line_rec.warranty_flag := 'E';
            l_hdr_rec.scs_code := 'WARRANTY';
            l_covd_rec.warranty_flag := 'E';
            l_hdr_rec.short_description := 'CUSTOMER:  '|| l_party_name || '  Warranty/Extended Warranty Contract';
         END IF;

--changing l_extwar_rec.merge...to l_hdr_rec
         IF l_hdr_rec.merge_object_id IS NOT NULL THEN
            OPEN l_hdr_scs_csr (l_hdr_rec.merge_object_id);
	          FETCH l_hdr_scs_csr INTO l_hdr_scs_code;
            CLOSE l_hdr_scs_csr;

            IF l_hdr_scs_code <> fnd_profile.VALUE ('OKS_CONTRACT_CATEGORY') THEN
               l_return_status := okc_api.g_ret_sts_error;
               --OKC_API.set_message(G_APP_NAME,'OKS_CONTRACT_CATEGORY','Cat',l_hdr_scs_code);
               fnd_message.set_name ('OKS', 'OKS_CONTRACT_CATEGORY');
               fnd_message.set_token (token      => 'Cat',
                                      VALUE      => l_hdr_scs_code);
               l_order_error := '#' || fnd_message.get_encoded || '#';
               x_upd_tbl (1).ERROR_TEXT := l_order_error;
               x_upd_tbl (1).success_flag := 'E';
               x_upd_tbl (1).order_line_id := p_reproc_line_rec.order_line_id;
               x_upd_tbl (1).ID := p_reproc_line_rec.ID;
               RAISE g_exception_halt_validation;
            END IF;
         END IF;

         l_contact_tbl.DELETE;

         IF l_k_header_rec.invoice_to_contact_id IS NOT NULL  THEN
            l_contact_tbl (1).party_role := 'CUSTOMER';
            l_contact_tbl (1).contact_role := 'BILLING';
            l_contact_tbl (1).contact_object_code := 'OKX_PCONTACT';
            l_contact_tbl (1).contact_id := l_k_header_rec.invoice_to_contact_id;
            l_contact_tbl (1).flag := 'H';
            l_ptr1 := 2;
         ELSE
            l_ptr1 := 1;
         END IF;

         FOR l_contact_rec IN l_contact_csr (p_reproc_line_rec.order_line_id) LOOP
            l_contact_tbl (l_ptr1).party_role := 'CUSTOMER';
            l_contact_tbl (l_ptr1).contact_role := l_contact_rec.cro_code;
            l_contact_tbl (l_ptr1).contact_object_code := 'OKX_PCONTACT';
            l_contact_tbl (l_ptr1).contact_id := l_contact_rec.object1_id1;
            l_contact_tbl (l_ptr1).flag := 'K';        -- changed 17-jul-2003
            l_ptr1 := l_ptr1 + 1;
         END LOOP;

         --OKC_CONTEXT.SET_OKC_ORG_CONTEXT ( p_org_id          => l_k_header_rec.authoring_org_id,
         --                                  p_organization_id => Null
         --                                 );

         ---mmadhavi sales credit bug 4174921
         l_salescredit_tbl_in.DELETE;
         l_header_id := p_reproc_line_rec.order_id;
         oks_extwar_util_pvt.salescredit_header
                                (p_order_hdr_id         => p_reproc_line_rec.order_id,
                                 x_salescredit_tbl      => l_salescredit_tbl_in,
                                 x_return_status        => l_return_status
                                );
         fnd_file.put_line (fnd_file.LOG, 'OC INTERFACE :- SalesCredit at Header ' || l_return_status );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success) THEN
            FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
               fnd_msg_pub.get (p_msg_index          => -1,
                                p_encoded            => 'F',
                                p_data               => l_msg_data,
                                p_msg_index_out      => l_index
                               );
               fnd_file.put_line (fnd_file.LOG, 'READ SALES CREDIT ERROR IN HEADER'|| l_msg_data );
            END LOOP;

            RAISE g_exception_halt_validation;
         END IF;

--mmadhavi bug 4069827

         -- rty_code has been added, (Extwarranty consolidation) vigandhi
         l_hdr_rec.contract_number := okc_api.g_miss_char;
         l_hdr_rec.rty_code := 'CONTRACTSERVICESORDER';
         l_hdr_rec.start_date := l_k_line_rec.srv_sdt;
         l_hdr_rec.end_date := l_k_line_rec.srv_edt;
         -- l_hdr_rec.sts_code                     := 'ACTIVE';
         l_hdr_rec.class_code := 'SVC';
         l_hdr_rec.authoring_org_id := l_k_header_rec.authoring_org_id;
         --l_hdr_rec.org_id := l_k_header_rec.org_id; --MMadhavi MOAC : need to add in rec type also
         l_hdr_rec.party_id := l_k_header_rec.party_id;
         l_hdr_rec.third_party_role := l_rnrl_rec_out.rle_code;
         l_hdr_rec.bill_to_id := l_k_header_rec.bill_to_id;
         l_hdr_rec.ship_to_id := l_k_header_rec.ship_to_id;
         l_hdr_rec.chr_group := l_rnrl_rec_out.cgp_new_id;
         l_hdr_rec.cust_po_number := l_k_header_rec.cust_po_number;
         l_hdr_rec.agreement_id := l_k_header_rec.agreement_id;
         --party name to be done
         l_hdr_rec.currency := l_k_header_rec.currency;
         l_hdr_rec.accounting_rule_id :=
                                    NVL (l_k_header_rec.accounting_rule_id, 1);
         l_hdr_rec.invoice_rule_id := NVL (l_k_header_rec.invoice_rule_id, -2);
         l_hdr_rec.order_hdr_id := l_k_header_rec.order_hdr_id;
         l_hdr_rec.price_list_id := l_k_header_rec.price_list_id;
         l_hdr_rec.payment_term_id := l_k_header_rec.hdr_payment_term_id;
         l_hdr_rec.renewal_type := l_renewal_rec.renewal_type;
         l_hdr_rec.RENEWAL_APPROVAL_FLAG := l_renewal_rec.RENEWAL_APPROVAL_FLAG;  --Bug# 5173373
         l_hdr_rec.renewal_markup := l_renewal_rec.markup_percent;
         l_hdr_rec.renewal_pricing_type := l_renewal_rec.renewal_pricing_type;
         l_hdr_rec.renewal_price_list_id := l_renewal_rec.price_list_id1;
         l_hdr_rec.cvn_type := l_k_header_rec.hdr_cvn_type;
         l_hdr_rec.cvn_rate := l_k_header_rec.hdr_cvn_rate;
         l_hdr_rec.cvn_date := l_k_header_rec.hdr_cvn_date;
         l_hdr_rec.cvn_euro_rate := NULL;
         l_hdr_rec.tax_status_flag := l_k_header_rec.hdr_tax_status_flag;
         l_hdr_rec.tax_exemption_id := l_k_header_rec.hdr_tax_exemption_id;
         l_hdr_rec.renewal_type := l_renewal_rec.renewal_type;
         l_hdr_rec.RENEWAL_APPROVAL_FLAG := l_renewal_rec.RENEWAL_APPROVAL_FLAG;  --Bug# 5173373

         l_hdr_rec.renewal_pricing_type := l_renewal_rec.renewal_pricing_type;
         l_hdr_rec.renewal_price_list_id := l_renewal_rec.price_list_id1;
         l_hdr_rec.renewal_markup := l_renewal_rec.markup_percent;
         l_hdr_rec.renewal_po := l_renewal_rec.po_required_yn;
         l_hdr_rec.contact_id := l_k_header_rec.ship_to_contact_id;
         l_hdr_rec.qto_contact_id := l_renewal_rec.contact_id;
         l_hdr_rec.qto_email_id := l_renewal_rec.email_id;
         l_hdr_rec.qto_phone_id := l_renewal_rec.phone_id;
         l_hdr_rec.qto_fax_id := l_renewal_rec.fax_id;
         l_hdr_rec.qto_site_id := l_renewal_rec.site_id;
         l_hdr_rec.order_line_id := p_reproc_line_rec.order_line_id;
         l_hdr_rec.billing_profile_id := l_renewal_rec.billing_profile_id;
         --new parameter added -vigandhi (May29-02)
         l_hdr_rec.qcl_id := l_rnrl_rec_out.qcl_id;
         l_hdr_rec.salesrep_id := l_k_header_rec.salesrep_id;
         l_hdr_rec.pdf_id := l_rnrl_rec_out.pdf_id;
         l_hdr_rec.ccr_number := l_k_header_rec.ccr_number;
         l_hdr_rec.ccr_exp_date := l_k_header_rec.ccr_exp_date;
--mmadhavi added for Partial Periods Computation
         l_hdr_rec.period_start := l_period_start;
         l_hdr_rec.period_type := l_period_type;
         l_hdr_rec.price_uom := l_price_uom;

--mmadhavi end Partial Periods Computation
         IF l_hdr_rec.start_date > SYSDATE  THEN
            oks_extwarprgm_pvt.get_sts_code ('SIGNED',
                                             NULL,
                                             l_ste_code,
                                             l_sts_code
                                            );
         ELSE
            oks_extwarprgm_pvt.get_sts_code ('ACTIVE',
                                             NULL,
                                             l_ste_code,
                                             l_sts_code
                                            );
         END IF;

         l_hdr_rec.sts_code := l_sts_code;
         -- Added by JVARGHES for 12.0 enhancements.
         l_hdr_rec.renewal_status := 'COMPLETE';
         l_hdr_rec.grace_period := l_rnrl_rec_out.grace_period; --Bug# 4549857
         l_hdr_rec.grace_duration := l_rnrl_rec_out.grace_duration;
                                                                --Bug# 4549857
         --

         -- Added as part of bug fix 5008188
         -- l_hdr_rec.tax_classification_code := l_k_header_rec.tax_classification_code;  -- Fix for bug# 5403061
         l_hdr_rec.tax_classification_code :=  NULL;   -- Fix for bug# 5403061
         l_hdr_rec.exemption_certificate_number := l_k_header_rec.exemption_certificate_number;
         l_hdr_rec.exemption_reason_code := l_k_header_rec.exemption_reason_code;
         --

         oks_extwarprgm_pvt.create_k_hdr
                                (p_k_header_rec            => l_hdr_rec,
                                 p_contact_tbl             => l_contact_tbl,
                                 p_salescredit_tbl_in      => l_salescredit_tbl_in,
                                 --mmadhavi  bug 4174921
                                 p_caller                  => 'OC',
                                 x_order_error             => l_order_error,
                                 x_chr_id                  => l_chrid,
                                 x_return_status           => l_return_status,
                                 x_msg_count               => l_msg_count,
                                 x_msg_data                => l_msg_data
                                );
         fnd_file.put_line (fnd_file.LOG,  'OC INTERFACE :- Create K Hdr ID = '|| TO_CHAR (l_chrid) );
         fnd_file.put_line (fnd_file.LOG,  'OC INTERFACE :- Create K Hdr status ' || l_return_status );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success) THEN
            IF l_order_error IS NULL  THEN
               l_order_error := '#';

               FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
                  fnd_msg_pub.get (p_msg_index          => i,
                                   p_encoded            => 'T',
                                   p_data               => l_msg_data,
                                   p_msg_index_out      => l_index
                                  );
                  l_order_error := l_order_error || l_msg_data || '#';
                  fnd_message.set_encoded (l_msg_data);
                  l_msg_data := fnd_message.get;
                  fnd_file.put_line (fnd_file.LOG, 'Create_k_hdr FAILURE ' || l_msg_data  );
               END LOOP;
            END IF;

            x_upd_tbl (1).ERROR_TEXT := l_order_error;
            x_upd_tbl (1).success_flag := 'E';
            x_upd_tbl (1).order_line_id := p_reproc_line_rec.order_line_id;
            x_upd_tbl (1).ID := p_reproc_line_rec.ID;
            RAISE g_exception_halt_validation;
         END IF;

         x_upd_tbl (1).contract_id := l_chrid;

         -- Fix for Bug 2805292
         IF l_hdr_rec.order_hdr_id IS NOT NULL AND l_hdr_rec.merge_type = 'NEW' THEN
            okc_oc_int_pub.create_k_relationships
                           (p_api_version              => l_api_version,
                            p_init_msg_list            => l_init_msg_list,
                            p_commit                   => okc_api.g_false,
                            p_sales_contract_id        => okc_api.g_miss_num,
                            p_service_contract_id      => l_chrid,
                            p_quote_id                 => okc_api.g_miss_num,
                            p_quote_line_tab           => okc_oc_int_pub.g_miss_ql_tab,
                            p_order_id                 => l_hdr_rec.order_hdr_id,
                            p_order_line_tab           => okc_oc_int_pub.g_miss_ol_tab,
                            p_trace_mode               => NULL,
                            x_return_status            => l_return_status,
                            x_msg_count                => l_msg_count,
                            x_msg_data                 => l_msg_data
                           );

            IF (fnd_log.level_event >= fnd_log.g_current_runtime_level)  THEN
               fnd_log.STRING
                  (fnd_log.level_event,
                   g_module_current || '.ORDER_REPROCESS.CREATE_CONTRACT',
                      ' okc_oc_int_pub.create_k_relationships(Return status = ' || l_return_status|| ')'
                  );
            END IF;

            --OKS_RENEW_PVT.DEBUG_LOG( '(OKS_EXTWARPRGM_PVT).okc_oc_int_pub.create_k_relationships '|| l_return_status);
            fnd_file.put_line (fnd_file.LOG,'(OKS_EXTWARPRGM_PVT).okc_oc_int_pub.create_k_relationships ' || l_return_status );

            IF NOT (l_return_status = fnd_api.g_ret_sts_success) THEN
               FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
                  fnd_msg_pub.get (p_msg_index          => -1,
                                   p_encoded            => 'F',
                                   p_data               => l_msg_data,
                                   p_msg_index_out      => l_index
                                  );
                  fnd_file.put_line (fnd_file.LOG, 'K HDR CREATION ERROR ' || l_msg_data );
               END LOOP;

               RAISE g_exception_halt_validation;
            END IF;
         END IF;

         oks_extwar_util_pvt.salescredit
                          (p_order_line_id        => p_reproc_line_rec.order_line_id,
                           x_salescredit_tbl      => l_salescredit_tbl_in,
                           x_return_status        => l_return_status
                          );
         fnd_file.put_line (fnd_file.LOG, 'OC INTERFACE :- SalesCredit ' || l_return_status  );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success) THEN
            FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
               fnd_msg_pub.get (p_msg_index          => -1,
                                p_encoded            => 'F',
                                p_data               => l_msg_data,
                                p_msg_index_out      => l_index
                               );
               fnd_file.put_line (fnd_file.LOG,'READ SALES CREDIT ERROR ' || l_msg_data );
            END LOOP;

            RAISE g_exception_halt_validation;
         END IF;


         -- If the line level credit sales credit is not specified for an order line
         -- in OM, then default the header sales credits to the line as well

         IF l_salescredit_tbl_in.count = 0 THEN
            oks_extwar_util_pvt.salescredit_header
                                (p_order_hdr_id         => p_reproc_line_rec.order_id,
                                 x_salescredit_tbl      => l_salescredit_tbl_in,
                                 x_return_status        => l_return_status
                                );
            fnd_file.put_line (fnd_file.LOG,
                               'OC INTERFACE :- SalesCredit at Header - defaulting for order line id = '
                               ||p_reproc_line_rec.order_id || l_return_status );

            IF NOT (l_return_status = fnd_api.g_ret_sts_success) THEN
               FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
                  fnd_msg_pub.get (p_msg_index          => -1,
                                p_encoded            => 'F',
                                p_data               => l_msg_data,
                                p_msg_index_out      => l_index
                               );
                  fnd_file.put_line (fnd_file.LOG, 'READ SALES CREDIT ERROR IN HEADER' || l_msg_data );
               END LOOP;

               RAISE g_exception_halt_validation;
            END IF;
         END IF;

         fnd_file.put_line (fnd_file.LOG,'OC_INT ...... Cov Temp Id = '
                            || NVL (l_k_line_rec.coverage_schd_id, -12345) );
         l_line_rec.k_id := l_chrid;
         l_line_rec.k_line_number := okc_api.g_miss_char;
         -- l_line_rec.line_sts_code               := 'ACTIVE';
         l_line_rec.cust_account := l_k_line_rec.customer_acct_id;
         l_line_rec.org_id := l_k_header_rec.authoring_org_id;
         -- mmadhavi should change to org_id for MOAC
         l_line_rec.srv_id := l_k_line_rec.srv_id;
         l_line_rec.object_name := l_k_line_rec.srv_desc;
         l_line_rec.srv_segment1 := l_k_line_rec.srv_segment1;
         l_line_rec.srv_desc := l_k_line_rec.srv_desc;
         l_line_rec.srv_sdt := l_k_line_rec.srv_sdt;
         l_line_rec.srv_edt := l_k_line_rec.srv_edt;
         l_line_rec.bill_to_id := l_k_line_rec.bill_to_id;
         l_line_rec.ship_to_id := l_k_line_rec.ship_to_id;
         l_line_rec.order_line_id := p_reproc_line_rec.order_line_id;
         --l_line_rec.warranty_flag             := 'E';
         l_line_rec.coverage_template_id := l_k_line_rec.coverage_schd_id;
         l_line_rec.currency := l_k_header_rec.currency;
         l_line_rec.line_renewal_type := l_renewal_rec.line_renewal_type;
         l_line_rec.accounting_rule_id := NVL (l_k_line_rec.accounting_rule_id, 1);
         l_line_rec.invoicing_rule_id := NVL (l_k_line_rec.invoicing_rule_id, -2);
         l_line_rec.SOURCE := 'NEW';
         l_line_rec.upg_orig_system_ref := 'ORDER';
         l_line_rec.upg_orig_system_ref_id := NULL;
         l_line_rec.commitment_id := l_k_line_rec.commitment_id;
         --l_line_rec.tax_amount                  := l_k_line_rec.tax_amount;
         l_line_rec.ln_price_list_id := l_k_line_rec.ln_price_list_id;
         --22-NOV-2005 mchoudha PPC
         l_line_rec.price_uom := l_price_uom;

         --End PPC
         IF l_line_rec.srv_sdt > SYSDATE  THEN
            oks_extwarprgm_pvt.get_sts_code ('SIGNED',
                                             NULL,
                                             l_ste_code,
                                             l_sts_code
                                            );
         ELSE
            oks_extwarprgm_pvt.get_sts_code ('ACTIVE',
                                             NULL,
                                             l_ste_code,
                                             l_sts_code
                                            );
         END IF;

         l_line_rec.line_sts_code := l_sts_code;
         -- Added by JVARGHES for 12.0 enhancements
         l_line_rec.standard_cov_yn := 'Y';
         --
         -- Added as part of bug fix 5008188
         l_line_rec.tax_classification_code := l_k_line_rec.tax_classification_code;
         l_line_rec.exemption_certificate_number := l_k_line_rec.exemption_certificate_number;
         l_line_rec.exemption_reason_code := l_k_line_rec.exemption_reason_code;
         l_line_rec.tax_status := l_k_line_rec.tax_status;
         --
         oks_extwarprgm_pvt.create_k_service_lines
                                (p_k_line_rec              => l_line_rec,
                                 p_contact_tbl             => l_contact_tbl,
                                 p_salescredit_tbl_in      => l_salescredit_tbl_in,
                                 p_caller                  => 'OC',
                                 x_order_error             => l_order_error,
                                 x_service_line_id         => l_lineid,
                                 x_return_status           => l_return_status,
                                 x_msg_count               => l_msg_count,
                                 x_msg_data                => l_msg_data
                                );
         fnd_file.put_line (fnd_file.LOG, 'OC INTERFACE :- Create K Line ID =  ' || NVL (l_lineid, -1234));
         fnd_file.put_line (fnd_file.LOG, 'OC INTERFACE :- Create K Line status ' || l_return_status );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success)  THEN
            IF l_order_error IS NULL  THEN
               l_order_error := '#';

               FOR i IN 1 .. fnd_msg_pub.count_msg  LOOP
                  fnd_msg_pub.get (p_msg_index          => i,
                                   p_encoded            => 'T',
                                   p_data               => l_msg_data,
                                   p_msg_index_out      => l_index
                                  );
                  l_order_error := l_order_error || l_msg_data || '#';
                  fnd_message.set_encoded (l_msg_data);
                  l_msg_data := fnd_message.get;
                  fnd_file.put_line (fnd_file.LOG, 'Create_k_service_line FAILURE '|| l_msg_data );
               END LOOP;
            END IF;

            x_upd_tbl (1).ERROR_TEXT := l_order_error;
            x_upd_tbl (1).success_flag := 'E';
            x_upd_tbl (1).order_line_id := p_reproc_line_rec.order_line_id;
            x_upd_tbl (1).ID := p_reproc_line_rec.ID;
            fnd_file.put_line (fnd_file.LOG,  'Inserting error msg ...' || x_upd_tbl (1).ERROR_TEXT );
            RAISE g_exception_halt_validation;
         END IF;

--Copy line id for Reprocessing
         x_upd_tbl (1).contract_line_id := l_lineid;
         l_error := 'N';

         FOR cp_ctr IN 1 .. l_cp_tbl.COUNT LOOP
            IF (l_error <> 'Y') THEN
               OPEN l_cp_csr (l_cp_tbl (cp_ctr).cp_id);
               FETCH l_cp_csr INTO l_cp_id, l_cp_inventory, l_cp_name, l_cp_desc, l_cp_qty, l_cp_uom;
               CLOSE l_cp_csr;

               oks_extwar_util_pvt.get_pricing_attributes
                         (p_order_line_id      => p_reproc_line_rec.order_line_id,
                          x_pricing_att        => l_pricing_attributes_in,
                          x_return_status      => l_return_status
                         );

               IF NOT (l_return_status = fnd_api.g_ret_sts_success)  THEN
                  FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
                     fnd_msg_pub.get (p_msg_index          => -1,
                                      p_encoded            => 'F',
                                      p_data               => l_msg_data,
                                      p_msg_index_out      => l_index
                                     );
                     fnd_file.put_line (fnd_file.LOG,  'READ PRICING ATTRIBS ERROR ' || l_msg_data );
                  END LOOP;

                  RAISE g_exception_halt_validation;
               END IF;

               IF fnd_profile.VALUE ('OKS_ITEM_DISPLAY_PREFERENCE') = 'DISPLAY_NAME'  THEN
                  l_covd_rec.product_segment1 := l_cp_desc;
                  l_covd_rec.product_desc := l_cp_name;
               ELSE
                  l_covd_rec.product_segment1 := l_cp_name;
                  l_covd_rec.product_desc := l_cp_desc;
               END IF;

                 -- rty_code has been added (Extwarranty consolidation) vigandhi
----mmadhavi added bom_explosion
               OPEN l_serv_ref_csr (p_reproc_line_rec.order_line_id);
               FETCH l_serv_ref_csr INTO l_serv_ref_rec;
               CLOSE l_serv_ref_csr;

               IF l_serv_ref_rec.service_reference_type_code = 'ORDER'  THEN
                  OPEN l_inv_csr (l_serv_ref_rec.service_reference_line_id);
                  FETCH l_inv_csr INTO l_inv_item_id;
                  CLOSE l_inv_csr;

                  IF l_inv_item_id = l_cp_inventory  THEN
                     l_covd_rec.negotiated_amount := l_k_line_rec.unit_selling_price * l_cp_qty;
                     l_covd_rec.list_price := l_k_line_rec.unit_selling_price;
                     l_covd_rec.tax_amount := l_k_line_rec.tax_amount;   -- Bug# 5274971
                     l_BOM_instance_flag   := 'Y';                       -- Bug# 5165947

                  ELSE
                     l_covd_rec.negotiated_amount := 0;
                     l_covd_rec.list_price := 0;
                     l_covd_rec.tax_amount := 0;                         -- Bug# 5274971
                     l_BOM_instance_flag   := 'N';                       -- Bug# 5165947

                  END IF;
               ELSE
                  l_covd_rec.negotiated_amount := l_k_line_rec.unit_selling_price * l_cp_qty;
                  l_covd_rec.list_price := l_k_line_rec.unit_selling_price;
                  l_covd_rec.tax_amount := l_k_line_rec.tax_amount;   -- Bug# 5274971
                  l_BOM_instance_flag   := 'Y';                       -- Bug# 5165947

               END IF;

-- mmadhavi end of BOM explosion
               l_covd_rec.k_id := l_chrid;
               l_covd_rec.attach_2_line_id := l_lineid;
               l_covd_rec.line_number := okc_api.g_miss_char;
               --l_covd_rec.product_sts_code      := 'ACTIVE';
               l_covd_rec.customer_product_id := l_cp_tbl (cp_ctr).cp_id;
               --l_covd_rec.Product_Segment1      := l_cp_name;
               --l_covd_rec.Product_Desc          := l_cp_desc;
--bug 3761489
               l_covd_rec.prod_item_id := l_cp_inventory;
--bug 3761489
               l_covd_rec.product_start_date := l_k_line_rec.srv_sdt;
               l_covd_rec.product_end_date := l_k_line_rec.srv_edt;
               l_covd_rec.quantity := l_cp_qty;
               l_covd_rec.uom_code := l_cp_uom;
               --l_covd_rec.negotiated_amount     := l_k_line_rec.unit_selling_price * l_cp_qty;
               --l_covd_rec.warranty_flag       := 'E';
               l_covd_rec.line_renewal_type := l_renewal_rec.line_renewal_type;
               --l_covd_rec.list_price            := l_k_line_rec.unit_selling_price;
               l_covd_rec.currency_code := l_k_header_rec.currency;
               l_covd_rec.order_line_id := p_reproc_line_rec.order_line_id;
               l_covd_rec.attach_2_line_desc := l_k_line_rec.srv_desc;
               l_covd_rec.rty_code := 'CONTRACTSERVICESORDER';
               l_covd_rec.upg_orig_system_ref := 'ORDER_LINE';
               l_covd_rec.upg_orig_system_ref_id := p_reproc_line_rec.order_line_id;

        -- Bug# 5274971
        --     l_covd_rec.tax_amount := l_k_line_rec.tax_amount;
        --
               --22-NOV-2005 mchoudha PPC
               l_covd_rec.toplvl_uom_code := l_k_line_rec.pricing_quantity_uom;
               l_covd_rec.price_uom := l_k_line_rec.order_quantity_uom;
               --mchoudha added for bug#5233956
               l_covd_rec.toplvl_price_qty := l_k_line_rec.pricing_quantity;

               --End PPC
               IF l_covd_rec.product_start_date > SYSDATE THEN
                  oks_extwarprgm_pvt.get_sts_code ('SIGNED',
                                                   NULL,
                                                   l_ste_code,
                                                   l_sts_code
                                                  );
               ELSE
                  oks_extwarprgm_pvt.get_sts_code ('ACTIVE',
                                                   NULL,
                                                   l_ste_code,
                                                   l_sts_code
                                                  );
               END IF;

               l_covd_rec.product_sts_code := l_sts_code;
               oks_extwarprgm_pvt.create_k_covered_levels
                                  (p_k_covd_rec         => l_covd_rec,
                                   p_price_attribs      => l_pricing_attributes_in,
                                   p_caller             => 'OC',
                                   x_order_error        => l_order_error,
                                   x_covlvl_id          => l_covlvl_id,
                                   x_update_line        => l_update_line,
                                   x_return_status      => l_return_status,
                                   x_msg_count          => l_msg_count,
                                   x_msg_data           => l_msg_data
                                  );

               -- Added for fix of bug# 5165947

               fnd_file.put_line(fnd_file.LOG,'l_BOM_instance_flag = '|| l_BOM_instance_flag  );

               IF l_BOM_instance_flag = 'Y' THEN
                  l_BOM_instance_id := l_covlvl_id;

                   fnd_file.put_line (fnd_file.LOG,'l_BOM_CovLvl_id = '|| TO_CHAR (l_BOM_instance_id));

               END IF;

               IF l_update_line = 'Y' THEN
                  l_eff_line_upd_flag := 'Y';
                  fnd_file.put_line (fnd_file.LOG, 'l_eff_line_upd_flag = '|| l_eff_line_upd_flag );
               END IF;

               -- Added for fix of bug# 5165947

               fnd_file.put_line (fnd_file.LOG,'OC INTERFACE :- Create K Covd Line Subline ID = ' || TO_CHAR (l_covlvl_id));
               fnd_file.put_line (fnd_file.LOG,'OC INTERFACE :- Create K Covd Line status ' || l_return_status );

               IF NOT (l_return_status = fnd_api.g_ret_sts_success) THEN
                  IF l_order_error IS NULL THEN
                     l_order_error := '#';

                     FOR i IN 1 .. fnd_msg_pub.count_msg LOOP
                        fnd_msg_pub.get (p_msg_index          => i,
                                         p_encoded            => 'T',
                                         p_data               => l_msg_data,
                                         p_msg_index_out      => l_index
                                        );
                        l_order_error := l_order_error || l_msg_data || '#';
                        fnd_message.set_encoded (l_msg_data);
                        l_msg_data := fnd_message.get;
                        fnd_file.put_line (fnd_file.LOG, 'Create_K_Covered_levels FAILURE '  || l_msg_data );
                     END LOOP;
                  END IF;

                  x_upd_tbl (1).ERROR_TEXT := l_order_error;
                  x_upd_tbl (1).success_flag := 'E';
                  x_upd_tbl (1).order_line_id := p_reproc_line_rec.order_line_id;
                  x_upd_tbl (1).ID := p_reproc_line_rec.ID;
                  l_error := 'Y';
                  RAISE g_exception_halt_validation;
               END IF;

               x_upd_tbl (cp_ctr).subline_id := l_covlvl_id;
               x_upd_tbl (cp_ctr).contract_line_id := l_lineid;
               x_upd_tbl (cp_ctr).contract_id := l_chrid;

               OPEN l_lndates_csr (l_lineid);
               FETCH l_lndates_csr INTO l_lndates_rec;
               CLOSE l_lndates_csr;

               OPEN l_hdrdates_csr (l_chrid);
               FETCH l_hdrdates_csr INTO l_hdrdates_rec;
               CLOSE l_hdrdates_csr;

               OPEN l_refnum_csr (l_cp_tbl (cp_ctr).cp_id);
               FETCH l_refnum_csr INTO l_ref_num;
               CLOSE l_refnum_csr;

               l_insthist_rec.instance_id := l_cp_tbl (cp_ctr).cp_id;
               l_insthist_rec.transaction_type := 'NEW';
               l_insthist_rec.transaction_date := SYSDATE;
               l_insthist_rec.reference_number := l_ref_num;
               oks_ins_pvt.insert_row (p_api_version        => 1.0,
                                       p_init_msg_list      => 'T',
                                       x_return_status      => l_return_status,
                                       x_msg_count          => l_msg_count,
                                       x_msg_data           => l_msg_data,
                                       p_insv_rec           => l_insthist_rec,
                                       x_insv_rec           => x_insthist_rec
                                      );
               fnd_file.put_line (fnd_file.LOG, ' instance history Status  : '  || l_return_status );
               x_return_status := l_return_status;

               IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                  x_return_status := l_return_status;
                  RAISE g_exception_halt_validation;
               END IF;

               l_inst_dtls_rec.ins_id := x_insthist_rec.ID;
               l_inst_dtls_rec.transaction_date := SYSDATE;
               l_inst_dtls_rec.transaction_type := 'NEW';
               l_inst_dtls_rec.instance_id_new := l_cp_tbl (cp_ctr).cp_id;
               l_inst_dtls_rec.instance_amt_new :=
                                                  l_covd_rec.negotiated_amount;
               --l_k_line_rec.unit_selling_price * l_cp_qty;
               l_inst_dtls_rec.instance_qty_new := l_cp_qty;
               l_inst_dtls_rec.new_contract_id := l_chrid;
               l_inst_dtls_rec.new_contact_start_date :=  l_hdrdates_rec.start_date;
               l_inst_dtls_rec.new_contract_end_date := l_hdrdates_rec.end_date;
               l_inst_dtls_rec.new_service_line_id := l_lineid;
               l_inst_dtls_rec.new_service_start_date := l_lndates_rec.start_date;
               l_inst_dtls_rec.new_service_end_date := l_lndates_rec.end_date;
               l_inst_dtls_rec.new_subline_id := l_covlvl_id;
               l_inst_dtls_rec.new_subline_start_date := l_k_line_rec.srv_sdt;
               l_inst_dtls_rec.new_subline_end_date := l_k_line_rec.srv_edt;
               l_inst_dtls_rec.new_customer := l_k_line_rec.customer_acct_id;
               l_inst_dtls_rec.new_k_status := l_hdrdates_rec.sts_code;
               oks_ihd_pvt.insert_row (p_api_version        => 1.0,
                                       p_init_msg_list      => 'T',
                                       x_return_status      => l_return_status,
                                       x_msg_count          => l_msg_count,
                                       x_msg_data           => l_msg_data,
                                       p_ihdv_rec           => l_inst_dtls_rec,
                                       x_ihdv_rec           => x_inst_dtls_rec
                                      );
               fnd_file.put_line (fnd_file.LOG, ' instance history details Status  : '|| l_return_status );
               x_return_status := l_return_status;

               IF NOT l_return_status = okc_api.g_ret_sts_success THEN
                  x_return_status := l_return_status;
                  RAISE g_exception_halt_validation;
               END IF;
            ELSE
               EXIT;
            END IF;
         END LOOP;

--Added for fix of bug# 5165947

         fnd_file.put_line (fnd_file.LOG, 'l_eff_line_upd_flag : '||l_eff_line_upd_flag );

         IF l_eff_line_upd_flag = 'Y' THEN
            NULL;
         ELSE
            open c_line_ammt_ckeck(c_line_id => l_lineid);
            fetch c_line_ammt_ckeck into l_prev_line_amt;
            close c_line_ammt_ckeck;

            fnd_file.put_line (fnd_file.LOG,  'l_prev_line_amt  : '||to_char(l_prev_line_amt) );
         END IF;

--Added for fix of bug# 5165947


--Added for fix of bug# 5274971

         UPDATE okc_k_lines_b
            SET price_negotiated =
                           (SELECT NVL (SUM (NVL (price_negotiated, 0)), 0)
                              FROM okc_k_lines_b
                             WHERE cle_id = l_lineid AND dnz_chr_id = l_chrid)
          WHERE ID = l_lineid;

         UPDATE okc_k_headers_all_b                   --mmadhavi _all for MOAC
            SET estimated_amount =
                           (SELECT NVL (SUM (NVL (price_negotiated, 0)), 0)
                              FROM okc_k_lines_b
                             WHERE dnz_chr_id = l_chrid AND lse_id IN (1, 19))
          WHERE ID = l_chrid;


      -- Rollup the subline tax amount to topline
      OPEN c_extwar_line_amount(l_chrid, l_lineid);
      FETCH c_extwar_line_amount INTO l_line_tax_amount;
      CLOSE c_extwar_line_amount;

      -- Update the topline with the tax amount
      UPDATE oks_k_lines_b
      SET tax_amount = l_line_tax_amount
      WHERE cle_id = l_lineid;

      -- Rollup the topline tax amount to header
      OPEN c_extwar_hdr_amount(l_chrid);
      FETCH c_extwar_hdr_amount INTO l_header_tax_amount;
      CLOSE c_extwar_hdr_amount;

      -- Update the header with the tax amount
      UPDATE oks_k_headers_b
      SET tax_amount = l_header_tax_amount
      WHERE chr_id = l_chrid;

--Added for fix of bug# 5274971

         -- create billing schedule
         l_strmlvl_id := check_strmlvl_exists (l_lineid);

         IF l_strmlvl_id IS NULL THEN
            l_sll_tbl (1).cle_id := l_lineid;
            --l_sll_tbl(1).billing_type                  := 'T';
            l_sll_tbl (1).sequence_no := '1';
            l_sll_tbl (1).level_periods := '1';
            l_sll_tbl (1).start_date := l_k_line_rec.srv_sdt;
            l_sll_tbl (1).advance_periods := NULL;
            l_sll_tbl (1).level_amount := NULL;
            l_sll_tbl (1).invoice_offset_days := NULL;
            l_sll_tbl (1).interface_offset_days := NULL;

            --22-NOV-2005 mchoudha added for PPC
            IF l_period_start IS NOT NULL AND l_period_type IS NOT NULL AND l_period_start = 'CALENDAR' THEN
               l_sll_tbl (1).uom_code := 'DAY';
               l_sll_tbl (1).uom_per_period :=  l_k_line_rec.srv_edt - l_k_line_rec.srv_sdt + 1;
            ELSE
               okc_time_util_pub.get_duration
                                       (p_start_date         => l_k_line_rec.srv_sdt,
                                        p_end_date           => l_k_line_rec.srv_edt,
                                        x_duration           => l_duration,
                                        x_timeunit           => l_timeunits,
                                        x_return_status      => l_return_status
                                       );

               --OKS_RENEW_PVT.DEBUG_LOG( '(OKS_EXTWARPRGM_PVT).Create_Billing_Schd :: Get_Duration Status  : '|| l_return_status );
               --OKS_RENEW_PVT.DEBUG_LOG( '(OKS_EXTWARPRGM_PVT).Create_Billing_Schd :: Duration             : '|| l_duration );
               --OKS_RENEW_PVT.DEBUG_LOG( '(OKS_EXTWARPRGM_PVT).Create_Billing_Schd :: Time Unit            : '|| l_timeunits );
               IF (fnd_log.level_event >= fnd_log.g_current_runtime_level)  THEN
                  fnd_log.STRING
                       (fnd_log.level_event,
                        g_module_current || '.ORDER_REPROCESS.CREATE_CONTRACT',
                           ' Okc_time_util_pub.get_duration(Return status = '
                        || l_return_status
                        || ' ,Duration = '
                        || l_duration
                        || ' ,Time Unit = '
                        || l_timeunits
                        || ')'
                       );
               END IF;

               IF NOT l_return_status = 'S'
               THEN
                  RAISE g_exception_halt_validation;
               END IF;

               l_sll_tbl (1).uom_code := l_timeunits;
               l_sll_tbl (1).uom_per_period := l_duration;
            END IF;

            oks_bill_sch.create_bill_sch_rules
                           (p_billing_type         => 'T',
                            p_sll_tbl              => l_sll_tbl,
                            p_invoice_rule_id      => l_line_rec.invoicing_rule_id,
                            x_bil_sch_out_tbl      => l_bil_sch_out,
                            x_return_status        => l_return_status
                           );
            fnd_file.put_line
                     (fnd_file.LOG, 'OKS_BILL_SCH.Create_Bill_Sch_Rules(Return status = '
                      || l_return_status || ')' );

            IF (fnd_log.level_event >= fnd_log.g_current_runtime_level)  THEN
               fnd_log.STRING
                   (fnd_log.level_event,
                    g_module_current || '.ORDER_REPROCESS.CREATE_CONTRACT',
                       ' OKS_BILL_SCH.Create_Bill_Sch_Rules(Return status = '|| l_return_status|| ')' );
            END IF;

            --OKS_RENEW_PVT.DEBUG_LOG( '(OKS_EXTWARPRGM_PVT).Create_Billing_Schd :: Create_Bill_Sch_Rules Status  : '|| l_return_status );
            IF l_return_status <> okc_api.g_ret_sts_success THEN
               okc_api.set_message (g_app_name,
                                    g_required_value,
                                    g_col_name_token,
                                    'Sched Billing Rule (LINE)'
                                   );
               RAISE g_exception_halt_validation;
            END IF;

            oks_bill_util_pub.create_bcl_for_om
                                           (p_line_id            => l_lineid,
                                            x_return_status      => l_return_status
                                           );
            fnd_file.put_line (fnd_file.LOG,'Create_Contract :- CREATE_BCL_FOR_OM '|| l_return_status);

            IF (fnd_log.level_event >= fnd_log.g_current_runtime_level) THEN
               fnd_log.STRING
                  (fnd_log.level_event,
                   g_module_current || '.ORDER_REPROCESS.CREATE_CONTRACT',
                      ' OKS_BILL_UTIL_PUB.CREATE_BCL_FOR_OM(Return status = ' || l_return_status || ')' );
            END IF;

            --OKS_RENEW_PVT.DEBUG_LOG( '(OKS_EXTWARPRGM_PVT).Create_contract_Ibnew :: CREATE_BCL_FOR_OM '|| l_return_status);
            IF NOT l_return_status = 'S' THEN
               RAISE g_exception_halt_validation;
            END IF;
         ELSE
            IF check_lvlelements_exists (l_lineid) THEN

--Added for fix of bug# 5165947

         fnd_file.put_line (fnd_file.LOG,'l_eff_line_upd_flag : '||l_eff_line_upd_flag );

         IF l_eff_line_upd_flag = 'Y' THEN
            NULL;
         ELSE
            open c_line_ammt_ckeck(c_line_id => l_lineid);
            fetch c_line_ammt_ckeck into l_curr_line_amt;
            close c_line_ammt_ckeck;

            fnd_file.put_line (fnd_file.LOG,  'l_curr_line_amt  : '||to_char(l_curr_line_amt));

            if nvl(l_curr_line_amt,0) <> nvl(l_prev_line_amt,0) THEN
              l_eff_line_upd_flag := 'Y';
              fnd_file.put_line (fnd_file.LOG, 'l_eff_line_upd_flag (final)  : '||l_eff_line_upd_flag );
            end if;
         END IF;

        l_update_line  :=  NVL(l_eff_line_upd_flag,l_update_line);

 --Added for fix of bug# 5165947
               IF l_update_line = 'Y' THEN
                  oks_bill_sch.update_om_sll_date
                                         (p_top_line_id        => l_lineid,
                                          x_return_status      => l_return_status,
                                          x_msg_count          => x_msg_count,
                                          x_msg_data           => x_msg_data
                                         );
                  fnd_file.put_line (fnd_file.LOG,'IBNEW :- Update_OM_SLL_Date '|| l_return_status );

                  IF (fnd_log.level_event >= fnd_log.g_current_runtime_level ) THEN
                     fnd_log.STRING
                        (fnd_log.level_event,  g_module_current
                         || '.ORDER_REPROCESS.CREATE_CONTRACT',
                            ' OKS_BILL_SCH.UPDATE_OM_SLL_DATE(Return status = ' || l_return_status || ')' );
                  END IF;

                  --OKS_RENEW_PVT.DEBUG_LOG('(OKS_EXTWARPRGM_PVT).Create_contract_Ibnew :: Update_OM_SLL_Date ' || l_return_status);
                  IF NOT l_return_status = 'S' THEN
                     RAISE g_exception_halt_validation;
                  END IF;
               ELSE
                  oks_bill_sch.create_bill_sch_cp
                                         (p_top_line_id        => l_lineid,
                                          p_cp_line_id         => l_covlvl_id,
                                          p_cp_new             => 'Y',
                                          x_return_status      => l_return_status,
                                          x_msg_count          => x_msg_count,
                                          x_msg_data           => x_msg_data
                                         );
                  fnd_file.put_line
                                  (fnd_file.LOG, 'Create_Contract :- Create_Bill_Sch_CP ' || l_return_status);

                  IF (fnd_log.level_event >= fnd_log.g_current_runtime_level ) THEN
                     fnd_log.STRING
                        (fnd_log.level_event, g_module_current
                         || '.ORDER_REPROCESS.CREATE_CONTRACT', ' OKS_BILL_SCH.CREATE_BILL_SCH_CP(Return status = '
                         || l_return_status || ' ,'|| TO_CHAR (SYSDATE, 'dd-mon-yyyy  HH24:MI:SS')|| ')' );
                  END IF;

                  /*
                                 OKS_RENEW_PVT.DEBUG_LOG(TO_CHAR( SYSDATE, 'dd-mon-yyyy  HH24:MI:SS')
                                      || '(OKS_EXTWARPRGM_PVT).Create_contract_Ibnew :: Create_Bill_Sch_CP '
                                      || l_return_status
                                  ); */
                  IF NOT l_return_status = 'S' THEN
                     RAISE g_exception_halt_validation;
                  END IF;
               END IF;

               oks_bill_util_pub.create_bcl_for_om
                                           (p_line_id            => l_lineid,
                                            x_return_status      => l_return_status
                                           );
               fnd_file.put_line (fnd_file.LOG, 'Create_Contract :- CREATE_BCL_FOR_OM ' || l_return_status );

               IF (fnd_log.level_event >= fnd_log.g_current_runtime_level) THEN
                  fnd_log.STRING
                     (fnd_log.level_event,
                      g_module_current || '.ORDER_REPROCESS.CREATE_CONTRACT',
                         ' OKS_BILL_UTIL_PUB.CREATE_BCL_FOR_OM(Return status = '|| l_return_status || ')' );
               END IF;

               --OKS_RENEW_PVT.DEBUG_LOG( '(OKS_EXTWARPRGM_PVT).Create_contract_Ibnew :: CREATE_BCL_FOR_OM '|| l_return_status);
               IF NOT l_return_status = 'S'  THEN
                  RAISE g_exception_halt_validation;
               END IF;
            ELSE
               okc_api.set_message (g_app_name,
                                    g_required_value,
                                    g_col_name_token,
                                    'level elements NOT EXIST'
                                   );
               RAISE g_exception_halt_validation;
            END IF;
         END IF;

-- Commented out for fix of bug# 5274971
--
--         UPDATE okc_k_lines_b
--            SET price_negotiated =
--                           (SELECT NVL (SUM (NVL (price_negotiated, 0)), 0)
--                              FROM okc_k_lines_b
--                             WHERE cle_id = l_lineid AND dnz_chr_id = l_chrid)
--          WHERE ID = l_lineid;
--
--         UPDATE okc_k_headers_all_b                   --mmadhavi _all for MOAC
--            SET estimated_amount =
--                           (SELECT NVL (SUM (NVL (price_negotiated, 0)), 0)
--                              FROM okc_k_lines_b
--                             WHERE dnz_chr_id = l_chrid AND lse_id IN (1, 19))
--          WHERE ID = l_chrid;
--
--
--      -- Rollup the subline tax amount to topline
--      OPEN c_extwar_line_amount(l_chrid, l_lineid);
--      FETCH c_extwar_line_amount INTO l_line_tax_amount;
--      CLOSE c_extwar_line_amount;
--
--      -- Update the topline with the tax amount
--      UPDATE oks_k_lines_b
--      SET tax_amount = l_line_tax_amount
--      WHERE cle_id = l_lineid;
--
--      -- Rollup the topline tax amount to header
--      OPEN c_extwar_hdr_amount(l_chrid);
--      FETCH c_extwar_hdr_amount INTO l_header_tax_amount;
--      CLOSE c_extwar_hdr_amount;
--
--      -- Update the header with the tax amount
--      UPDATE oks_k_headers_b
--      SET tax_amount = l_header_tax_amount
--      WHERE chr_id = l_chrid;
--
-- Commented out for fix of bug# 5274971

      EXCEPTION
         WHEN g_exception_halt_validation THEN
            x_return_status := l_return_status;
            IF c_extwar_line_amount%ISOPEN THEN
               CLOSE c_extwar_line_amount;
            END IF;
            IF c_extwar_hdr_amount%ISOPEN THEN
               CLOSE c_extwar_hdr_amount;
            END IF;
         WHEN OTHERS THEN
            x_return_status := okc_api.g_ret_sts_unexp_error;
            IF c_extwar_line_amount%ISOPEN THEN
               CLOSE c_extwar_line_amount;
            END IF;
            IF c_extwar_hdr_amount%ISOPEN THEN
               CLOSE c_extwar_hdr_amount;
            END IF;
            fnd_file.put_line (fnd_file.LOG, 'Oracle Error Code is -' || TO_CHAR (SQLCODE) );
            fnd_file.put_line (fnd_file.LOG, 'Oracle Error Message is -'|| SUBSTR (SQLERRM, 1, 512) );
      END create_contract;

      PROCEDURE get_order_details (
         p_option          IN              VARCHAR2,
         p_source          IN              VARCHAR2,
         x_return_status   OUT NOCOPY      VARCHAR2,
         x_repv_tbl        OUT NOCOPY      oks_rep_pvt.repv_tbl_type
      )
      IS
--mmadhavi modified cursors for MOAC
         CURSOR l_order_line_sub_csr
         IS
            SELECT ID, order_id, order_line_id, success_flag, source_flag,
                   rep.order_number
              FROM oks_reprocessing_v rep, oe_order_headers oh
             WHERE success_flag = 'R'
               AND rep.order_id = oh.header_id
               AND conc_request_id IS NULL;

         CURSOR l_order_line_sel_csr
         IS
            SELECT ID, order_id, order_line_id, success_flag, source_flag,
                   rep.order_number
              FROM oks_reprocessing_v rep, oe_order_headers oh
             WHERE reprocess_yn = 'Y'              --success_flag IN ('R','N')
               AND rep.order_id = oh.header_id
               AND conc_request_id IS NULL;

         CURSOR l_order_line_all_csr
         IS
            SELECT ID, order_id, order_line_id, success_flag, source_flag,
                   rep.order_number
              FROM oks_reprocessing_v rep, oe_order_headers oh
             WHERE NVL (success_flag, 'E') IN ('E', 'N')   ---IN ('R','N','E')
               AND rep.order_id = oh.header_id
               AND conc_request_id IS NULL;

         l_repv_tbl        oks_rep_pvt.repv_tbl_type;
         l_return_status   VARCHAR2 (1)           := okc_api.g_ret_sts_success;
         l_ordline_rec     oks_rep_pvt.repv_rec_type;
         l_ptr             NUMBER;
         l_source          VARCHAR2 (30);

         PROCEDURE get_order_lines (
            p_id              IN              NUMBER,
            p_order_id        IN              NUMBER,
            p_ord_num         IN              NUMBER,
            p_success_flag    IN              VARCHAR2,
            p_source_flag     IN              VARCHAR2,
            x_repv_tbl        OUT NOCOPY      oks_rep_pvt.repv_tbl_type,
            x_return_status   OUT NOCOPY      VARCHAR2
         )
         IS
            CURSOR get_order_lines_csr (p_ord_num NUMBER)
            IS
               SELECT ol.line_id, NVL (fulfilled_quantity, 0),
                      service_reference_type_code, service_reference_line_id
                 FROM oe_order_lines_all ol, oe_order_headers oh
                WHERE oh.header_id = ol.header_id
                  AND oh.order_number = p_ord_num;

--and  Oh.org_id = okc_context.get_okc_org_id;

            /*
            Cursor get_ordlines_dtls_csr(p_ord_line_id NUMBER)
            Is
            Select Nvl(FULFILLED_QUANTITY,0),SERVICE_REFERENCE_TYPE_CODE,SERVICE_REFERENCE_LINE_ID
            From oe_order_lines_all
            Where line_id = p_ord_line_id
            and header_id IN (select header_id from oe_order_headers_all where org_id = okc_context.get_okc_org_id);
            */

            --mmadhavi modified the cursor for MOAC
            CURSOR check_duplicate_csr (p_ordline_id NUMBER)
            IS
               SELECT 'x'
                 FROM oks_reprocessing rep, oe_order_headers hdr
                WHERE rep.order_line_id = p_ordline_id
                  AND rep.order_id = hdr.header_id;

            l_ord_line_id        NUMBER;
            serv_ref_type        VARCHAR2 (30);
            serv_ref_id          NUMBER;
            l_fulfilled_qty      NUMBER;
            l_exists             VARCHAR2 (1)              := 'Y';
            l_ptr1               NUMBER;
            l_first_order_line   NUMBER;
            l_init_msg_list      VARCHAR2 (1)              := okc_api.g_false;
            l_return_status      VARCHAR2 (1)     := okc_api.g_ret_sts_success;
            l_msg_count          NUMBER                    := 0;
            l_msg_data           VARCHAR2 (2000);
            l_repv_rec           oks_rep_pvt.repv_rec_type;
            l_out_repv_rec       oks_rep_pvt.repv_rec_type;
         BEGIN
            fnd_file.put_line (fnd_file.LOG,
                               'Inside procedure Get Order Lines'
                              );
            l_first_order_line := NULL;
            l_ptr1 := 0;

-- mmadhavi commenting for MOAC
--FND_FILE.PUT_LINE (FND_FILE.LOG, ' Okc_context = ' || nvl(okc_context.get_okc_org_id,-999));
            OPEN get_order_lines_csr (p_ord_num);

            LOOP
               FETCH get_order_lines_csr
                INTO l_ord_line_id, l_fulfilled_qty, serv_ref_type,
                     serv_ref_id;

               EXIT WHEN get_order_lines_csr%NOTFOUND;
               l_exists := 'y';

               OPEN check_duplicate_csr (l_ord_line_id);

               FETCH check_duplicate_csr
                INTO l_exists;

               CLOSE check_duplicate_csr;

               IF (l_exists <> 'x')
               THEN
                  fnd_file.put_line (fnd_file.LOG, 'No duplicate line..');

                  /*
                  Open get_ordlines_dtls_csr(l_ord_line_id);
                  Fetch get_ordlines_dtls_csr into l_fulfilled_qty,serv_ref_type, serv_ref_id;
                  Close get_ordlines_dtls_csr;
                  */
                  IF (    NVL (serv_ref_type, 'REF_TYPE') IN
                                                ('CUSTOMER_PRODUCT', 'ORDER')
                      AND serv_ref_id IS NOT NULL
                     )
                  THEN
                     fnd_file.put_line (fnd_file.LOG, 'Valid line...');

                     IF (p_source_flag = 'ASO')
                     THEN
                        IF (l_fulfilled_qty > 0)
                        THEN
                           l_ptr1 := l_ptr1 + 1;
                           fnd_file.put_line (fnd_file.LOG,
                                              'From ASO ..Fulfilled..'
                                             );

                           IF (l_ptr1 = 1)
                           THEN
                              l_first_order_line := l_ord_line_id;
                              fnd_file.put_line (fnd_file.LOG,
                                                 'First Order line..'
                                                );
                           ELSE
                              fnd_file.put_line (fnd_file.LOG,
                                                 'More lines ..Inserting..'
                                                );
                              l_repv_rec.order_id := p_order_id;
                              l_repv_rec.order_line_id := l_ord_line_id;
                              l_repv_rec.success_flag := p_success_flag;
                              l_repv_rec.source_flag := p_source_flag;
                              l_repv_rec.order_number := p_ord_num;
                              l_repv_rec.reprocess_yn := 'N';
                              oks_rep_pub.insert_row
                                          (p_api_version        => 1.0,
                                           p_init_msg_list      => l_init_msg_list,
                                           x_return_status      => l_return_status,
                                           x_msg_count          => l_msg_count,
                                           x_msg_data           => l_msg_data,
                                           p_repv_rec           => l_repv_rec,
                                           x_repv_rec           => l_out_repv_rec
                                          );
                              fnd_file.put_line (fnd_file.LOG,
                                                    'Return status = '
                                                 || l_return_status
                                                );

                              IF (l_return_status <> 'S')
                              THEN
                                 x_return_status := l_return_status;
                                 RAISE g_exception_halt_validation;
                              END IF;

                              fnd_file.put_line (fnd_file.LOG,
                                                    'Insert status = '
                                                 || l_return_status
                                                );
                              x_repv_tbl (l_ptr1).ID := l_out_repv_rec.ID;
                              x_repv_tbl (l_ptr1).order_id :=
                                                       l_out_repv_rec.order_id;
                              x_repv_tbl (l_ptr1).order_line_id :=
                                                  l_out_repv_rec.order_line_id;
                              x_repv_tbl (l_ptr1).success_flag :=
                                                   l_out_repv_rec.success_flag;
                              x_repv_tbl (l_ptr1).source_flag :=
                                                    l_out_repv_rec.source_flag;
                              x_repv_tbl (l_ptr1).order_number :=
                                                   l_out_repv_rec.order_number;
                           END IF;
                        END IF;
                     ELSE
                        fnd_file.put_line (fnd_file.LOG, 'Source = MANUAL');
                        l_ptr1 := l_ptr1 + 1;

                        IF (l_ptr1 = 1)
                        THEN
                           l_first_order_line := l_ord_line_id;
                           fnd_file.put_line (fnd_file.LOG,
                                              'First Order Line...'
                                             );
                        ELSE
                           fnd_file.put_line (fnd_file.LOG,
                                              'Next Order lines...'
                                             );
                           l_repv_rec.order_id := p_order_id;
                           l_repv_rec.order_line_id := l_ord_line_id;
                           l_repv_rec.success_flag := p_success_flag;
                           l_repv_rec.source_flag := p_source_flag;
                           l_repv_rec.order_number := p_ord_num;
                           l_repv_rec.reprocess_yn := 'N';
                           oks_rep_pub.insert_row
                                          (p_api_version        => 1.0,
                                           p_init_msg_list      => l_init_msg_list,
                                           x_return_status      => l_return_status,
                                           x_msg_count          => l_msg_count,
                                           x_msg_data           => l_msg_data,
                                           p_repv_rec           => l_repv_rec,
                                           x_repv_rec           => l_out_repv_rec
                                          );
                           fnd_file.put_line
                              (fnd_file.LOG,
                                  'oks_rep_pub.insert_row : return status => '
                               || l_return_status
                              );

                           IF (l_return_status <> 'S')
                           THEN
                              x_return_status := l_return_status;
                              RAISE g_exception_halt_validation;
                           END IF;

                           fnd_file.put_line (fnd_file.LOG,
                                                 'Insert status ...'
                                              || l_return_status
                                             );
                           x_repv_tbl (l_ptr1).ID := l_out_repv_rec.ID;
                           x_repv_tbl (l_ptr1).order_id :=
                                                       l_out_repv_rec.order_id;
                           x_repv_tbl (l_ptr1).order_line_id :=
                                                  l_out_repv_rec.order_line_id;
                           x_repv_tbl (l_ptr1).success_flag :=
                                                   l_out_repv_rec.success_flag;
                           x_repv_tbl (l_ptr1).source_flag :=
                                                    l_out_repv_rec.source_flag;
                           x_repv_tbl (l_ptr1).order_number :=
                                                   l_out_repv_rec.order_number;
                        END IF;
                     END IF;                                   -- Source = ASO
                  END IF;                                      -- Service line
               END IF;                                       -- duplicate line
            END LOOP;

            fnd_file.put_line (fnd_file.LOG, 'End of Loop...');

            IF (l_first_order_line IS NOT NULL)
            THEN
               x_repv_tbl (1).ID := p_id;
               x_repv_tbl (1).order_id := p_order_id;
               x_repv_tbl (1).order_line_id := l_first_order_line;
               x_repv_tbl (1).success_flag := p_success_flag;
               x_repv_tbl (1).source_flag := p_source_flag;
               x_repv_tbl (1).order_number := p_ord_num;
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'Exiting Get Order lines');
         EXCEPTION
            WHEN g_exception_halt_validation
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                     ' Error in Get_Order_lines : '
                                  || SQLCODE
                                  || ':'
                                  || SQLERRM
                                 );
               okc_api.set_message (g_app_name,
                                    g_unexpected_error,
                                    g_sqlcode_token,
                                    SQLCODE,
                                    g_sqlerrm_token,
                                    SQLERRM
                                   );
            WHEN OTHERS
            THEN
               x_return_status := okc_api.g_ret_sts_unexp_error;
               fnd_file.put_line (fnd_file.LOG,
                                     ' Error in Get_Order_lines : '
                                  || SQLCODE
                                  || ':'
                                  || SQLERRM
                                 );
               okc_api.set_message (g_app_name,
                                    g_unexpected_error,
                                    g_sqlcode_token,
                                    SQLCODE,
                                    g_sqlerrm_token,
                                    SQLERRM
                                   );
         END get_order_lines;
      BEGIN
         fnd_file.put_line (fnd_file.LOG,
                            'Inside procedure Get Order Details'
                           );
         l_source := NVL (p_source, 'Auto');

         IF (l_source <> 'FORM')
         THEN
            l_ptr := 0;

            IF p_option = 'SEL'
            THEN
               FOR l_ordline_rec IN l_order_line_sel_csr
               LOOP
                  l_ptr := l_ptr + 1;

                  IF (l_ordline_rec.order_line_id IS NULL)
                  THEN
                     get_order_lines
                               (p_id                 => l_ordline_rec.ID,
                                p_order_id           => l_ordline_rec.order_id,
                                p_ord_num            => l_ordline_rec.order_number,
                                p_success_flag       => l_ordline_rec.success_flag,
                                p_source_flag        => l_ordline_rec.source_flag,
                                x_repv_tbl           => l_repv_tbl,
                                x_return_status      => l_return_status
                               );

                     IF (l_return_status <> 'S')
                     THEN
                        x_return_status := l_return_status;
                        RAISE g_exception_halt_validation;
                     END IF;

                     FOR i IN 1 .. l_repv_tbl.COUNT
                     LOOP
                        x_repv_tbl (l_ptr).ID := l_repv_tbl (i).ID;
                        x_repv_tbl (l_ptr).order_id :=
                                                      l_repv_tbl (i).order_id;
                        x_repv_tbl (l_ptr).order_line_id :=
                                                 l_repv_tbl (i).order_line_id;
                        x_repv_tbl (l_ptr).success_flag :=
                                                  l_repv_tbl (i).success_flag;
                        x_repv_tbl (l_ptr).source_flag :=
                                                   l_repv_tbl (i).source_flag;
                        x_repv_tbl (l_ptr).order_number :=
                                                  l_repv_tbl (i).order_number;
                        l_ptr := l_ptr + 1;
                     END LOOP;

                     l_ptr := l_ptr - 1;
                  ELSE
                     x_repv_tbl (l_ptr).ID := l_ordline_rec.ID;
                     x_repv_tbl (l_ptr).order_id := l_ordline_rec.order_id;
                     x_repv_tbl (l_ptr).order_line_id :=
                                                  l_ordline_rec.order_line_id;
                     x_repv_tbl (l_ptr).success_flag :=
                                                   l_ordline_rec.success_flag;
                     x_repv_tbl (l_ptr).source_flag :=
                                                    l_ordline_rec.source_flag;
                     x_repv_tbl (l_ptr).order_number :=
                                                   l_ordline_rec.order_number;
                  END IF;
               END LOOP;
            ELSE
               FOR l_ordline_rec IN l_order_line_all_csr
               LOOP
                  l_ptr := l_ptr + 1;

                  IF (l_ordline_rec.order_line_id IS NULL)
                  THEN
                     get_order_lines
                               (p_id                 => l_ordline_rec.ID,
                                p_order_id           => l_ordline_rec.order_id,
                                p_ord_num            => l_ordline_rec.order_number,
                                p_success_flag       => l_ordline_rec.success_flag,
                                p_source_flag        => l_ordline_rec.source_flag,
                                x_repv_tbl           => l_repv_tbl,
                                x_return_status      => l_return_status
                               );

                     IF (l_return_status <> 'S')
                     THEN
                        x_return_status := l_return_status;
                        RAISE g_exception_halt_validation;
                     END IF;

                     FOR i IN 1 .. l_repv_tbl.COUNT
                     LOOP
                        x_repv_tbl (l_ptr).ID := l_repv_tbl (i).ID;
                        x_repv_tbl (l_ptr).order_id :=
                                                      l_repv_tbl (i).order_id;
                        x_repv_tbl (l_ptr).order_line_id :=
                                                 l_repv_tbl (i).order_line_id;
                        x_repv_tbl (l_ptr).success_flag :=
                                                  l_repv_tbl (i).success_flag;
                        x_repv_tbl (l_ptr).source_flag :=
                                                   l_repv_tbl (i).source_flag;
                        x_repv_tbl (l_ptr).order_number :=
                                                  l_repv_tbl (i).order_number;
                        l_ptr := l_ptr + 1;
                     END LOOP;

                     l_ptr := l_ptr - 1;
                  ELSE
                     x_repv_tbl (l_ptr).ID := l_ordline_rec.ID;
                     x_repv_tbl (l_ptr).order_id := l_ordline_rec.order_id;
                     x_repv_tbl (l_ptr).order_line_id :=
                                                  l_ordline_rec.order_line_id;
                     x_repv_tbl (l_ptr).success_flag :=
                                                   l_ordline_rec.success_flag;
                     x_repv_tbl (l_ptr).source_flag :=
                                                    l_ordline_rec.source_flag;
                     x_repv_tbl (l_ptr).order_number :=
                                                   l_ordline_rec.order_number;
                  END IF;
               END LOOP;
            END IF;
         ELSE
            fnd_file.put_line (fnd_file.LOG, 'Choice - Submitted');
            l_ptr := 0;

            FOR l_ordline_rec IN l_order_line_sub_csr
            LOOP
               l_ptr := l_ptr + 1;

               IF (l_ordline_rec.order_line_id IS NULL)
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                     'Calling get_order_lines...'
                                    );
                  get_order_lines
                                (p_id                 => l_ordline_rec.ID,
                                 p_order_id           => l_ordline_rec.order_id,
                                 p_ord_num            => l_ordline_rec.order_number,
                                 p_success_flag       => l_ordline_rec.success_flag,
                                 p_source_flag        => l_ordline_rec.source_flag,
                                 x_repv_tbl           => l_repv_tbl,
                                 x_return_status      => l_return_status
                                );

                  IF (l_return_status <> 'S')
                  THEN
                     x_return_status := l_return_status;
                     RAISE g_exception_halt_validation;
                  END IF;

                  FOR i IN 1 .. l_repv_tbl.COUNT
                  LOOP
                     x_repv_tbl (l_ptr).ID := l_repv_tbl (i).ID;
                     x_repv_tbl (l_ptr).order_id := l_repv_tbl (i).order_id;
                     x_repv_tbl (l_ptr).order_line_id :=
                                                 l_repv_tbl (i).order_line_id;
                     x_repv_tbl (l_ptr).success_flag :=
                                                  l_repv_tbl (i).success_flag;
                     x_repv_tbl (l_ptr).source_flag :=
                                                   l_repv_tbl (i).source_flag;
                     x_repv_tbl (l_ptr).order_number :=
                                                  l_repv_tbl (i).order_number;
                     l_ptr := l_ptr + 1;
                  END LOOP;

                  l_ptr := l_ptr - 1;
               ELSE
                  x_repv_tbl (l_ptr).ID := l_ordline_rec.ID;
                  x_repv_tbl (l_ptr).order_id := l_ordline_rec.order_id;
                  x_repv_tbl (l_ptr).order_line_id :=
                                                  l_ordline_rec.order_line_id;
                  x_repv_tbl (l_ptr).success_flag :=
                                                   l_ordline_rec.success_flag;
                  x_repv_tbl (l_ptr).source_flag := l_ordline_rec.source_flag;
                  x_repv_tbl (l_ptr).order_number :=
                                                   l_ordline_rec.order_number;
               END IF;
            END LOOP;
         END IF;

         x_return_status := l_return_status;
         fnd_file.put_line (fnd_file.LOG, 'Exiting Get Order Details');
      EXCEPTION
         WHEN g_exception_halt_validation
         THEN
            fnd_file.put_line (fnd_file.LOG,
                                  ' Error in Get_Order_details : '
                               || SQLCODE
                               || ':'
                               || SQLERRM
                              );
            okc_api.set_message (g_app_name,
                                 g_unexpected_error,
                                 g_sqlcode_token,
                                 SQLCODE,
                                 g_sqlerrm_token,
                                 SQLERRM
                                );
         WHEN OTHERS
         THEN
            x_return_status := okc_api.g_ret_sts_unexp_error;
            fnd_file.put_line (fnd_file.LOG,
                                  ' Error in Get_Order_Details : '
                               || SQLCODE
                               || ':'
                               || SQLERRM
                              );
            okc_api.set_message (g_app_name,
                                 g_unexpected_error,
                                 g_sqlcode_token,
                                 SQLCODE,
                                 g_sqlerrm_token,
                                 SQLERRM
                                );
      END get_order_details;
   BEGIN
      --Okc_context.set_okc_org_context (l_order_rec.org_id, NULL ); --mmadhavi commenting for MOAC
      l_prog_id := fnd_global.conc_program_id;
      l_req_id := fnd_global.conc_request_id;
      fnd_file.put_line (fnd_file.LOG, 'conc_prog_id = ' || l_prog_id);
      fnd_file.put_line (fnd_file.LOG, 'conc_req_id = ' || l_req_id);
      fnd_file.put_line (fnd_file.LOG, 'Source = ' || NVL (p_source, 'Auto'));
      SAVEPOINT oks_reprocessing;
      fnd_file.put_line (fnd_file.LOG, 'Start of Reprocessing.....');
      fnd_file.put_line (fnd_file.LOG,
                         'The parameter value is ..' || p_option
                        );
      fnd_file.put_line (fnd_file.LOG, 'Calling Get Order Details....');
      get_order_details (p_option             => p_option,
                         p_source             => p_source,
                         x_return_status      => l_return_status,
                         x_repv_tbl           => l_repv_tbl
                        );
      fnd_file.put_line (fnd_file.LOG,
                            'Get Order Details : l_return_status = '
                         || l_return_status
                        );
      l_line_count := l_repv_tbl.COUNT;

      IF (l_line_count <= 0)
      THEN
         fnd_file.put_line (fnd_file.LOG, 'No lines to Reprocess..');
      ELSE
         fnd_file.put_line (fnd_file.LOG,
                               'ReProcessing Order Lines... Line count = '
                            || l_line_count
                           );

         FOR l_count IN 1 .. l_line_count
         LOOP

--OM INT User Hook Start  Bug# 4462061

                  --Call out to Pre-Integration
                  --This is done as part of License Migration
                  --Call out starts here
                  IF fnd_log.level_statement >= fnd_log.g_current_runtime_level
                  THEN
                    fnd_log.string(FND_LOG.LEVEL_STATEMENT
                                  ,G_MODULE_CURRENT||'.ORDER_REPROCES'
           				   ,'Before OKS_OMIB_EXTNS_PUB.pre_integration call: ' ||
                                ' ,p_api_version = '|| '1.0' ||
                                ' ,p_init_msg_list = ' || 'T' ||
                                ' ,p_from_integration = OREP' ||
                                ' ,p_transaction_type = ' || NULL ||
                                ' ,p_transaction_date = ' || NULL ||
                                ' ,p_order_line_id = ' || l_repv_tbl(l_count).order_line_id ||
                                ' ,p_old_instance_id = ' || NULL ||
                                ' ,p_new_instance_id = ' || NULL);
                  END IF;

                  OKS_OMIB_INT_EXTNS_PUB.pre_integration
           	     (p_api_version      => 1.0
                     ,p_init_msg_list    => 'T'
                     ,p_from_integration => 'OREP'
                     ,p_transaction_type => NULL
                     ,p_transaction_date => NULL
                     ,p_order_line_id    => l_repv_tbl(l_count).order_line_id
                     ,p_old_instance_id  => NULL
                     ,p_new_instance_id  => NULL
				 ,x_process_status   => l_process_status
                     ,x_return_status    => x_return_status
                     ,x_msg_count        => x_msg_count
                     ,x_msg_data         => x_msg_data);

                  IF fnd_log.level_event >= fnd_log.g_current_runtime_level
                  THEN
                    fnd_log.string(FND_LOG.LEVEL_EVENT
                                  ,G_MODULE_CURRENT||'.IB_INTERFACE'
                                  ,'After OKS_OMIB_INT_EXTNS_PUB.pre_integration Call: ' ||
                                ' ,x_process_status = ' || l_process_status ||
                                ' ,x_return_status = ' || x_return_status);
                  END IF;
                  IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                  THEN
                    RAISE G_EXCEPTION_HALT_VALIDATION;
	             END IF;
                  --Call out ends here

        IF l_process_status = 'C'
		THEN

--OM INT User Hook End

            l_upd_tbl.DELETE;
            l_conc_rec.conc_request_id := l_req_id;
            l_conc_rec.order_line_id := l_repv_tbl (l_count).order_line_id;
            l_conc_rec.ID := l_repv_tbl (l_count).ID;
            fnd_file.put_line (fnd_file.LOG,
                               'Updating record with Conc req id'
                              );
            handle_order_error (x_return_status      => l_return_status,
                                p_upd_rec            => l_conc_rec
                               );
            fnd_file.put_line (fnd_file.LOG,
                               'l_return_status = ' || l_return_status
                              );

            IF NOT (l_return_status = fnd_api.g_ret_sts_success)
            THEN
               RAISE g_exception_halt_validation;
            END IF;

            l_fulfill := 'Y';
            l_order_rec.fqty := 0;
            l_order_rec.rolineid := NULL;
            l_order_rec.header_id := NULL;

            OPEN l_order_csr (l_repv_tbl (l_count).order_line_id);

            FETCH l_order_csr
             INTO l_order_rec;

            IF l_order_csr%NOTFOUND
            THEN
               fnd_file.put_line (fnd_file.LOG, 'l_order_csr not found ');
               l_order_rec.fqty := 0;
            END IF;

            CLOSE l_order_csr;

            okc_context.set_okc_org_context (l_order_rec.org_id, NULL);

            --FND_FILE.PUT_LINE (FND_FILE.LOG, 'success_flag = '||NVL(l_repv_tbl(l_count).success_flag,'S'));
            IF (NVL (l_repv_tbl (l_count).source_flag, 'S') = 'MANUAL')
            THEN
               fnd_file.put_line (fnd_file.LOG,
                                  'Order line entered from Reprocesing UI'
                                 );

               IF (l_order_rec.fqty <= 0)
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                        'Order line '
                                     || l_repv_tbl (l_count).order_line_id
                                     || ' not fulfilled'
                                    );
                  l_upd_tbl (1).ID := l_repv_tbl (l_count).ID;
                  l_upd_tbl (1).ERROR_TEXT := '#';
                  fnd_message.set_name ('OKS', 'OKS_REQUEST');
                  fnd_message.set_token (token => 'ID', VALUE => l_req_id);
                  l_upd_tbl (1).ERROR_TEXT :=
                     l_upd_tbl (1).ERROR_TEXT || fnd_message.get_encoded
                     || '#';
                  fnd_message.set_name ('OKS', 'OKS_LINE_NOT_FULFILLED');
                  fnd_message.set_token
                                   (token      => 'ORD_LINE',
                                    VALUE      => l_repv_tbl (l_count).order_line_id
                                   );
                  l_upd_tbl (1).ERROR_TEXT :=
                     l_upd_tbl (1).ERROR_TEXT || fnd_message.get_encoded
                     || '#';
                  l_upd_tbl (1).success_flag := 'E';
                  l_upd_tbl (1).conc_request_id := NULL;
                  handle_order_error (x_return_status      => l_return_status,
                                      p_upd_rec            => l_upd_tbl (1)
                                     );

                  IF NOT (l_return_status = fnd_api.g_ret_sts_success)
                  THEN
                     RAISE g_exception_halt_validation;
                  END IF;

                  l_fulfill := 'N';
               END IF;
            END IF;

            IF (l_fulfill <> 'N')
            THEN
               fnd_file.put_line (fnd_file.LOG, 'Order line fulfilled..');

               OPEN l_serv_ref_csr (l_repv_tbl (l_count).order_line_id);

               FETCH l_serv_ref_csr
                INTO l_serv_ref_rec;

               CLOSE l_serv_ref_csr;

               fnd_file.put_line (fnd_file.LOG,
                                     'Processing Order Line '
                                  || l_repv_tbl (l_count).order_line_id
                                 );
               fnd_file.put_line (fnd_file.LOG,
                                     'Service Ref Type Code '
                                  || l_serv_ref_rec.service_reference_type_code
                                 );
               fnd_file.put_line (fnd_file.LOG,
                                     'Service line Id       '
                                  || l_serv_ref_rec.service_reference_line_id
                                 );
               --FND_FILE.PUT_LINE (FND_FILE.LOG, 'Profile option value  ' || Fnd_Profile.Value('OKS_CONTRACTS_VALIDATION_SOURCE') );

               /*
               If Fnd_Profile.Value('OKS_CONTRACTS_VALIDATION_SOURCE') IN ('IB', 'MO')  OR
                         Fnd_Profile.Value('OKS_CONTRACTS_VALIDATION_SOURCE') Is NULL Then

                                 Okc_context.set_okc_org_context (l_order_rec.org_id, NULL );

               Elsif Fnd_Profile.Value('OKS_CONTRACTS_VALIDATION_SOURCE') = 'SO' Then

                                 l_organization_id := Null;
                                 If l_order_rec.sold_from_org_id Is Not Null Then
                                         Open l_organization_csr(l_order_rec.sold_from_org_id);
                                         Fetch l_organization_csr into l_organization_id;
                                         Close l_organization_csr;
                                 Else
                                         l_organization_id := Null;
                                 End If;

                                 Okc_context.set_okc_org_context (l_order_rec.org_id, l_organization_id);

               Elsif Fnd_Profile.Value('OKS_CONTRACTS_VALIDATION_SOURCE') = 'SH' Then

                                 Okc_context.set_okc_org_context (l_order_rec.org_id, l_order_rec.ship_from_org_id);

               End If;
               */
               l_cp_tbl.DELETE;

               IF NVL (l_serv_ref_rec.service_reference_type_code, 'REF_TYPE') =
                                                                       'ORDER'
               THEN                                       ------REF TYPE ORDER
                  OPEN l_order_csr (l_order_rec.rolineid);

                  FETCH l_order_csr
                   INTO l_ref_order_rec;

                  IF l_order_csr%NOTFOUND
                  THEN
                     l_order_rec.fqty := 0;
                  END IF;

                  CLOSE l_order_csr;

                  fnd_file.put_line (fnd_file.LOG, 'ORDER : L_ORDER_CSR ');

                  IF l_order_rec.header_id = l_ref_order_rec.header_id
                  THEN                               -----ORDER HEADER ID EQLS
                     fnd_file.put_line
                                    (fnd_file.LOG,
                                     'ORDER HEADER ID EQLS : L_PROCESS TRUE '
                                    );
                     l_process := TRUE;
                     l_cp_ctr := 1;

		     /*modified for bug6181908 --fp bug6006309*/
                     FOR rec IN
                        l_custprod_csr
                                     (l_serv_ref_rec.service_reference_line_id, okc_context.get_okc_organization_id)
                     LOOP
                        fnd_file.put_line (fnd_file.LOG,
                                              'L_CP_TBL CP ID '
                                           || rec.cp_id
                                           || ' Cnt '
                                           || l_cp_ctr
                                          );
                        l_cp_tbl (l_cp_ctr).cp_id := rec.cp_id;
                        l_cp_ctr := l_cp_ctr + 1;
                     END LOOP;

                     IF l_cp_ctr = 1
                     THEN
                        l_process := FALSE;
                     END IF;
                  ELSE
                     l_process := TRUE;
                     fnd_file.put_line
                                    (fnd_file.LOG,
                                     'ORDER HEADER ID NOT EQLS : L_CUSTPROD '
                                    );
                     l_cp_ctr := 1;

		     /*modified for bug6181908 -- fp bug6006309*/
                     FOR rec IN
                        l_custprod_csr
                                     (l_serv_ref_rec.service_reference_line_id, okc_context.get_okc_organization_id)
                     LOOP
                        fnd_file.put_line (fnd_file.LOG,
                                              'L_CP_TBL CP ID '
                                           || rec.cp_id
                                           || ' Cnt '
                                           || l_cp_ctr
                                          );
                        l_cp_tbl (l_cp_ctr).cp_id := rec.cp_id;
                        l_cp_ctr := l_cp_ctr + 1;
                     END LOOP;

                     IF l_cp_ctr = 1
                     THEN
                        l_process := FALSE;
                     END IF;
                  END IF;                            -----ORDER HEADER ID EQLS
               ELSE                                   ------REF TYPE CUST PROD
                  fnd_file.put_line (fnd_file.LOG, 'ElSE L_PROCESS TRUE ');
                  l_cp_tbl (1).cp_id :=
                                     l_serv_ref_rec.service_reference_line_id;
                  l_process := TRUE;
               END IF;                                    ------REF TYPE ORDER

               /* Bug 2324668
               In case Order Capture Integration is run when SFM is down then
               Customer product would not exist, and the Service line will
               get processed without creating any Contract.Now in case SFM is up
               and running , but still if there is a timing issue for fulfillment
               of lines then no contract will get created.So the next time
               Order Capture is run, the line does'nt get picked and no Contract
               is created at all.
               To fix this issue, populating the exception queue when the product
               is not in IB, so that the line will be picked again.

               */
               IF NOT l_process
               THEN
                  fnd_file.put_line (fnd_file.LOG, 'Cannot process line ...');
                  l_upd_tbl (1).ID := l_repv_tbl (l_count).ID;
                  l_upd_tbl (1).ERROR_TEXT := '#';
                  fnd_message.set_name ('OKS', 'OKS_REQUEST');
                  fnd_message.set_token (token => 'ID', VALUE => l_req_id);
                  l_upd_tbl (1).ERROR_TEXT :=
                     l_upd_tbl (1).ERROR_TEXT || fnd_message.get_encoded
                     || '#';
                  fnd_message.set_name ('OKS', 'OKS_PRODUCT_NOT_FOUND');
                  l_upd_tbl (1).ERROR_TEXT :=
                     l_upd_tbl (1).ERROR_TEXT || fnd_message.get_encoded
                     || '#';
                  --'Referenced Product not present in the Installed Base';
                  l_upd_tbl (1).success_flag := 'E';
                  l_upd_tbl (1).conc_request_id := NULL;
                  handle_order_error (x_return_status      => l_return_status,
                                      p_upd_rec            => l_upd_tbl (1)
                                     );

                  IF NOT (l_return_status = fnd_api.g_ret_sts_success)
                  THEN
                     RAISE g_exception_halt_validation;
                  END IF;
               END IF;

               IF l_process
               THEN
                  l_k_line_id := NULL;
                  l_ctr1 := 0;
                  l_upd_tbl (1).subline_id := NULL;

                  OPEN l_contract_csr (l_repv_tbl (l_count).order_line_id);

                  LOOP
                     l_ctr1 := l_ctr1 + 1;

                     FETCH l_contract_csr
                      INTO l_upd_tbl (l_ctr1).subline_id,
                           l_upd_tbl (l_ctr1).contract_id;

                     --FND_FILE.PUT_LINE (FND_FILE.LOG, 'cov_id = '||l_upd_tbl(l_ctr1).subline_id);
                     EXIT WHEN l_contract_csr%NOTFOUND;
                  END LOOP;

                  CLOSE l_contract_csr;

                  fnd_file.put_line (fnd_file.LOG, 'l_ctr1 = ' || l_ctr1);
                  fnd_file.put_line (fnd_file.LOG,
                                        'DUPLICATE CHECK l_K_LINE_ID '
                                     || NVL (l_upd_tbl (1).subline_id, -12345)
                                    );

                  IF l_upd_tbl (1).subline_id IS NULL
                  THEN                                     --Duplication Check
                     DBMS_TRANSACTION.SAVEPOINT ('OKS_REPROC');
                     l_reproc_line_rec := l_repv_tbl (l_count);
                     create_contract (p_reproc_line_rec      => l_reproc_line_rec,
                                      x_upd_tbl              => l_upd_tbl,
                                      x_return_status        => l_return_status
                                     );
                     fnd_file.put_line (fnd_file.LOG,
                                           'Create_Contract status ::'
                                        || l_return_status
                                       );

                     IF NOT (l_return_status = fnd_api.g_ret_sts_success)
                     THEN
                        l_error_msg := '#';

                        FOR i IN 1 .. fnd_msg_pub.count_msg
                        LOOP
                           fnd_msg_pub.get (p_msg_index          => i,
                                            p_encoded            => 'T',
                                            p_data               => l_msg_data,
                                            p_msg_index_out      => l_index
                                           );
                           l_error_msg := l_error_msg || l_msg_data || '#';
                           fnd_message.set_encoded (l_msg_data);
                           l_msg_data := fnd_message.get;
                           fnd_file.put_line (fnd_file.LOG,
                                                 'GET ORDER LINE FAILURE '
                                              || l_msg_data
                                             );
                        END LOOP;

                        DBMS_TRANSACTION.rollback_savepoint ('OKS_REPROC');
                        l_error_temp := '#';
                        fnd_message.set_name ('OKS', 'OKS_REQUEST');
                        fnd_message.set_token (token      => 'ID',
                                               VALUE      => l_req_id
                                              );
                        l_error_temp :=
                                       l_error_temp || fnd_message.get_encoded;

                        IF (l_upd_tbl (1).ERROR_TEXT = okc_api.g_miss_char)
                        THEN
                           l_upd_tbl (1).ERROR_TEXT :=
                                                  l_error_temp || l_error_msg;
                           l_upd_tbl (1).success_flag := 'E';
                        ELSE
                           l_upd_tbl (1).ERROR_TEXT :=
                                     l_error_temp || l_upd_tbl (1).ERROR_TEXT;
                        END IF;

                        l_upd_tbl (1).ID := l_repv_tbl (l_count).ID;
                        l_upd_tbl (1).contract_id := NULL;
                        l_upd_tbl (1).subline_id := NULL;
                        l_upd_tbl (1).contract_line_id := NULL;
                        l_upd_tbl (1).conc_request_id := NULL;
                        handle_order_error
                                          (x_return_status      => l_return_status,
                                           p_upd_rec            => l_upd_tbl
                                                                           (1)
                                          );

                        IF NOT (l_return_status = fnd_api.g_ret_sts_success)
                        THEN
                           RAISE g_exception_halt_validation;
                        END IF;
                     ELSE

-- OM INT User Hook Start Bug# 4462061

                 --Add Post_integration call out as part of code re-structuring for
 				 --license migrations.
                 --call out starts here

                                   IF fnd_log.level_statement >= fnd_log.g_current_runtime_level
                                   THEN
                                     fnd_log.string(FND_LOG.LEVEL_STATEMENT
                                                   ,G_MODULE_CURRENT||'.ORDER_REPROCESS'
                                                   ,'Before OKS_OMIB_EXTNS_PUB.post_integration call: ' ||
                                                 ' ,p_transaction_type = ' || NULL ||
                                                 ' ,p_transaction_date = ' || NULL ||
                                                 ' ,p_order_line_id = ' || l_upd_tbl(1).order_line_id ||
                                                 ' ,p_old_instance_id = ' || NULL ||
                                                 ' ,p_new_instance_id = ' || NULL ||
									    ' ,p_chr_id = ' || l_upd_tbl(1).contract_id ||
									    ' ,p_topline_id = ' || l_upd_tbl(1).contract_line_id ||
									    ' ,p_subline_id = ' || l_upd_tbl(1).subline_id);
                                   END IF;
                                   OKS_OMIB_INT_EXTNS_PUB.post_integration
                                       (p_api_version      => 1.0
                                       ,p_init_msg_list    => 'T'
                                       ,p_from_integration => 'OREP'
                                       ,p_transaction_type => NULL
                                       ,p_transaction_date => NULL
                                       ,p_order_line_id    => l_upd_tbl(1).order_line_id
                                       ,p_old_instance_id  => NULL
                                       ,p_new_instance_id  => NULL
                               	    ,p_chr_id           => l_upd_tbl(1).contract_id
                               	    ,p_topline_id       => l_upd_tbl(1).contract_line_id
                               	    ,p_subline_id       => l_upd_tbl(1).subline_id
                                       ,x_return_status    => x_return_status
                                       ,x_msg_count        => x_msg_count
                                       ,x_msg_data         => x_msg_data);
                                   IF fnd_log.level_event >= fnd_log.g_current_runtime_level
                                   THEN
                                     fnd_log.string(FND_LOG.LEVEL_EVENT
                                                   ,G_MODULE_CURRENT||'.IB_INTERFACE'
                                                   ,'After OKS_OMIB_INT_EXTNS_PUB.post_integration Call: ' ||
                                                 ' ,x_return_status = ' || x_return_status);
                                   END IF;
                                   IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                                   THEN
                                     RAISE G_EXCEPTION_HALT_VALIDATION;
                	               END IF;

                     --call out ends here

-- OM INT User Hook End

                        l_error_temp := '#';
                        fnd_message.set_name ('OKS', 'OKS_REQUEST');
                        fnd_message.set_token (token      => 'ID',
                                               VALUE      => l_req_id
                                              );
                        l_error_temp :=
                                l_error_temp || fnd_message.get_encoded || '#';
                        l_upd_tbl (1).ID := l_repv_tbl (l_count).ID;
                        fnd_message.set_name ('OKS', 'OKS_CONTRACT_SUCCESS');
                        l_upd_tbl (1).ERROR_TEXT := fnd_message.get_encoded;
                        --'Contract Successfully created';
                        l_upd_tbl (1).ERROR_TEXT :=
                               l_error_temp || l_upd_tbl (1).ERROR_TEXT || '#';
                        l_upd_tbl (1).success_flag := 'S';
                        l_upd_tbl (1).conc_request_id := NULL;
                        handle_order_error
                                          (x_return_status      => l_return_status,
                                           p_upd_rec            => l_upd_tbl
                                                                           (1)
                                          );

                        IF NOT (l_return_status = fnd_api.g_ret_sts_success)
                        THEN
                           RAISE g_exception_halt_validation;
                        END IF;

                        FOR i IN 2 .. l_upd_tbl.LAST
                        LOOP
                           fnd_message.set_name ('OKS', 'OKS_REQUEST');
                           fnd_message.set_token (token      => 'ID',
                                                  VALUE      => l_req_id
                                                 );
                           l_upd_tbl (i).ERROR_TEXT :=
                                         '#' || fnd_message.get_encoded || '#';
                           fnd_message.set_name ('OKS',
                                                 'OKS_CONTRACT_SUCCESS');
                           l_upd_tbl (i).ERROR_TEXT :=
                                 l_upd_tbl (i).ERROR_TEXT
                              || fnd_message.get_encoded
                              || '#';       --'Contract Successfully created';
                           l_upd_tbl (i).success_flag := 'S';
                           l_upd_tbl (i).conc_request_id := NULL;
                           l_upd_tbl (i).order_line_id :=
                                            l_repv_tbl (l_count).order_line_id;
                           l_upd_tbl (i).order_number :=
                                             l_repv_tbl (l_count).order_number;
                           l_upd_tbl (i).order_id :=
                                                 l_repv_tbl (l_count).order_id;
                           l_upd_tbl (i).source_flag :=
                                              l_repv_tbl (l_count).source_flag;
                           --'ASO';
                           l_upd_tbl (i).reprocess_yn := 'N';
                           oks_rep_pub.insert_row
                                          (p_api_version        => 1.0,
                                           p_init_msg_list      => l_init_msg_list,
                                           x_return_status      => l_return_status,
                                           x_msg_count          => l_msg_count,
                                           x_msg_data           => l_msg_data,
                                           p_repv_rec           => l_upd_tbl
                                                                           (i),
                                           x_repv_rec           => l_out_repv_rec
                                          );
                           fnd_file.put_line (fnd_file.LOG,
                                                 'L_return_status :'
                                              || l_return_status
                                             );

                           IF NOT (l_return_status = fnd_api.g_ret_sts_success
                                  )
                           THEN
                              FOR i IN 1 .. fnd_msg_pub.count_msg
                              LOOP
                                 fnd_msg_pub.get (p_msg_index          => -1,
                                                  p_encoded            => 'F',
                                                  p_data               => l_msg_data,
                                                  p_msg_index_out      => l_index
                                                 );
                                 fnd_file.put_line
                                              (fnd_file.LOG,
                                                  'ORDER_REPROCESS.Insert_row'
                                               || l_msg_data
                                              );
                              END LOOP;
                           END IF;
                        END LOOP;
                     END IF;
                  ELSE                                      /* If Duplicate */
                     l_ctr1 := l_ctr1 - 1;

                     OPEN l_contract_line_csr (l_upd_tbl (1).subline_id);

                     FETCH l_contract_line_csr
                      INTO l_cont_line_id;

                     CLOSE l_contract_line_csr;

                     l_upd_tbl (1).contract_line_id := l_cont_line_id;
                     l_upd_tbl (1).success_flag := 'S';
                     fnd_message.set_name ('OKS', 'OKS_REQUEST');
                     fnd_message.set_token (token      => 'ID',
                                            VALUE      => l_req_id);
                     l_upd_tbl (1).ERROR_TEXT :=
                                        '#' || fnd_message.get_encoded || '#';
                     fnd_message.set_name ('OKS', 'OKS_DUPLICATE_ORD_LINE');
                     l_upd_tbl (1).ERROR_TEXT :=
                           l_upd_tbl (1).ERROR_TEXT
                        || fnd_message.get_encoded
                        || '#';
                     l_upd_tbl (1).order_line_id :=
                                            l_repv_tbl (l_count).order_line_id;
                     l_upd_tbl (1).ID := l_repv_tbl (l_count).ID;
                     l_upd_tbl (1).conc_request_id := NULL;
                     handle_order_error (x_return_status      => l_return_status,
                                         p_upd_rec            => l_upd_tbl (1)
                                        );

                     IF NOT (l_return_status = fnd_api.g_ret_sts_success)
                     THEN
                        RAISE g_exception_halt_validation;
                     END IF;

                     --FND_FILE.PUT_LINE (FND_FILE.LOG, 'l_ctr1 = '||l_ctr1);
                     IF (l_ctr1 > 1)
                     THEN
                        FOR i IN 2 .. l_ctr1
                        LOOP
                           l_upd_tbl (i).contract_line_id := l_cont_line_id;
                           l_upd_tbl (i).success_flag := 'S';
                           fnd_message.set_name ('OKS', 'OKS_REQUEST');
                           fnd_message.set_token (token      => 'ID',
                                                  VALUE      => l_req_id
                                                 );
                           l_upd_tbl (i).ERROR_TEXT :=
                                         '#' || fnd_message.get_encoded || '#';
                           fnd_message.set_name ('OKS',
                                                 'OKS_DUPLICATE_ORD_LINE'
                                                );
                           l_upd_tbl (i).ERROR_TEXT :=
                                 l_upd_tbl (i).ERROR_TEXT
                              || fnd_message.get_encoded
                              || '#';
                           l_upd_tbl (i).order_line_id :=
                                            l_repv_tbl (l_count).order_line_id;
                           l_upd_tbl (i).order_number :=
                                             l_repv_tbl (l_count).order_number;
                           l_upd_tbl (i).order_id :=
                                                 l_repv_tbl (l_count).order_id;
                           l_upd_tbl (i).source_flag :=
                                              l_repv_tbl (l_count).source_flag;
                           l_upd_tbl (i).conc_request_id := NULL;
                           l_upd_tbl (i).reprocess_yn := 'N';
                           oks_rep_pub.insert_row
                                          (p_api_version        => 1.0,
                                           p_init_msg_list      => l_init_msg_list,
                                           x_return_status      => l_return_status,
                                           x_msg_count          => l_msg_count,
                                           x_msg_data           => l_msg_data,
                                           p_repv_rec           => l_upd_tbl
                                                                           (i),
                                           x_repv_rec           => l_out_repv_rec
                                          );
                           fnd_file.put_line (fnd_file.LOG,
                                                 'L_return_status :'
                                              || l_return_status
                                             );

                           IF NOT (l_return_status = fnd_api.g_ret_sts_success
                                  )
                           THEN
                              FOR i IN 1 .. fnd_msg_pub.count_msg
                              LOOP
                                 fnd_msg_pub.get (p_msg_index          => -1,
                                                  p_encoded            => 'F',
                                                  p_data               => l_msg_data,
                                                  p_msg_index_out      => l_index
                                                 );
                                 fnd_file.put_line
                                              (fnd_file.LOG,
                                                  'ORDER_REPROCESS.Insert_row'
                                               || l_msg_data
                                              );
                              END LOOP;
                           END IF;
                        END LOOP;
                     END IF;
                  END IF;                                   -- Duplicate Check
               END IF;                                    -- l_process is true
            END IF;

-- OM INT USER HOOK START Bug# 4462061

                   ELSE -- else of l_process_status from pre_integration

                     --Call out to Post starts here if l_process_status <> 'C'(dont want to continue with
			      --the existing logic above
                       IF fnd_log.level_statement >= fnd_log.g_current_runtime_level
                       THEN
                         fnd_log.string(FND_LOG.LEVEL_STATEMENT
                                       ,G_MODULE_CURRENT||'.ORDER_REPROCESS'
                                       ,'Before OKS_OMIB_EXTNS_PUB.post_integration call: ' ||
                                     ' ,p_transaction_type = ' || NULL ||
                                     ' ,p_transaction_date = ' || NULL ||
                                     ' ,p_order_line_id = ' || l_repv_tbl(l_count).order_line_id ||
                                     ' ,p_old_instance_id = ' || NULL ||
                                     ' ,p_new_instance_id = ' || NULL ||
                                     ' ,p_chr_id = '  || NULL ||
                                     ' ,p_topline_id = ' || NULL ||
                                     ' ,p_subline_id = ' || NULL);
                       END IF;

                       OKS_OMIB_INT_EXTNS_PUB.post_integration
                           (p_api_version      => 1.0
                           ,p_init_msg_list    => 'T'
                           ,p_from_integration => 'OREP'
                           ,p_transaction_type => NULL
                           ,p_transaction_date => NULL
                           ,p_order_line_id    => l_repv_tbl(l_count).order_line_id
                           ,p_old_instance_id  => NULL
                           ,p_new_instance_id  => NULL
                           ,p_chr_id           => NULL
                           ,p_topline_id       => NULL
                           ,p_subline_id       => NULL
                           ,x_return_status    => x_return_status
                           ,x_msg_count        => x_msg_count
                           ,x_msg_data         => x_msg_data);
                       IF fnd_log.level_event >= fnd_log.g_current_runtime_level
                       THEN
                         fnd_log.string(FND_LOG.LEVEL_EVENT
                                       ,G_MODULE_CURRENT||'.IB_INTERFACE'
                                       ,'After OKS_OMIB_INT_EXTNS_PUB.post_integration Call: ' ||
                                     ' ,x_return_status = ' || x_return_status);
                       END IF;
                       IF x_return_status <> FND_API.G_RET_STS_SUCCESS
                       THEN
                         RAISE G_EXCEPTION_HALT_VALIDATION;
	                  END IF;
                     END IF; --IF of l_process status check
                     --Call out to Post ends here
-- OM INT USER HOOK END

         END LOOP;   -- end loop on l_line_count tbl
      END IF;  -- For l_line_count

   EXCEPTION
      WHEN g_exception_halt_validation
      THEN
         x_return_status := l_return_status;
         fnd_file.put_line
                         (fnd_file.LOG,
                             ' Error in Order Reprocess - l_return_status = '
                          || l_return_status
                         );
      WHEN OTHERS
      THEN
         fnd_file.put_line (fnd_file.LOG,
                            'In OTHERS Exception of Order_Reprocess'
                           );
         x_return_status := okc_api.g_ret_sts_unexp_error;
         fnd_file.put_line (fnd_file.LOG,
                               ' Error in Order Reprocess : '
                            || SQLCODE
                            || ':'
                            || SQLERRM
                           );
         okc_api.set_message (g_app_name,
                              g_unexpected_error,
                              g_sqlcode_token,
                              SQLCODE,
                              g_sqlerrm_token,
                              SQLERRM
                             );
   END order_reprocess;

   PROCEDURE oks_order_purge (
      errbuf    OUT NOCOPY   VARCHAR2,
      retcode   OUT NOCOPY   NUMBER
   )
   IS
      l_return_status          VARCHAR2 (1)      := okc_api.g_ret_sts_success;
      l_msg_count              NUMBER;
      l_msg_data               VARCHAR2 (2000);
      l_user_id                NUMBER;
      l_del_rec                oks_rep_pvt.repv_rec_type;
      l_repv_tbl               oks_rep_pvt.repv_tbl_type;
      l_index                  NUMBER;
      l_line_count             NUMBER;
      l_api_version   CONSTANT NUMBER                    := 1.0;
      l_init_msg_list          VARCHAR2 (1)           DEFAULT fnd_api.g_false;

      PROCEDURE get_order_lines (
         x_return_status   OUT NOCOPY   VARCHAR2,
         x_msg_count       OUT NOCOPY   NUMBER,
         x_msg_data        OUT NOCOPY   VARCHAR2,
         x_repv_tbl        OUT NOCOPY   oks_rep_pvt.repv_tbl_type
      )
      IS
         CURSOR l_order_line_csr
         IS
            SELECT ID
              FROM oks_reprocessing_v
             WHERE success_flag = 'S';

         l_repv_tbl        oks_rep_pvt.repv_tbl_type;
         l_return_status   VARCHAR2 (1)          := okc_api.g_ret_sts_success;
         l_ordline_rec     oks_rep_pvt.repv_rec_type;
         l_ptr             NUMBER;
      BEGIN
         fnd_file.put_line (fnd_file.LOG, 'Inside procedure Get Order lines');
         l_ptr := 0;

         FOR l_ordline_rec IN l_order_line_csr
         LOOP
            l_ptr := l_ptr + 1;
            x_repv_tbl (l_ptr).ID := l_ordline_rec.ID;
         --X_Repv_tbl(l_ptr).order_line_id   := l_ordline_rec.order_line_id;
         END LOOP;

         x_return_status := l_return_status;
         fnd_file.put_line (fnd_file.LOG, 'Exiting Get Order Details');
      EXCEPTION
         WHEN OTHERS
         THEN
            x_return_status := okc_api.g_ret_sts_unexp_error;
            fnd_file.put_line (fnd_file.LOG,
                                  ' Error in Get_Order_Details : '
                               || SQLCODE
                               || ':'
                               || SQLERRM
                              );
            okc_api.set_message (g_app_name,
                                 g_unexpected_error,
                                 g_sqlcode_token,
                                 SQLCODE,
                                 g_sqlerrm_token,
                                 SQLERRM
                                );
      END get_order_lines;
   BEGIN
      fnd_file.put_line (fnd_file.LOG, 'Start of OKS_ORDER_PURGE_PVT...');
      l_user_id := fnd_global.user_id;
      fnd_file.put_line (fnd_file.LOG, 'User Id : ' || TO_CHAR (l_user_id));
      get_order_lines (x_return_status      => l_return_status,
                       x_msg_count          => l_msg_count,
                       x_msg_data           => l_msg_data,
                       x_repv_tbl           => l_repv_tbl
                      );
      fnd_file.put_line (fnd_file.LOG,
                            'Get Order Lines: l_return_status = '
                         || l_return_status
                        );

      IF NOT (l_return_status = fnd_api.g_ret_sts_success)
      THEN
         FOR i IN 1 .. fnd_msg_pub.count_msg
         LOOP
            fnd_msg_pub.get (p_msg_index          => -1,
                             p_encoded            => 'F',
                             p_data               => l_msg_data,
                             p_msg_index_out      => l_index
                            );
            fnd_file.put_line (fnd_file.LOG,
                               'GET ORDER LINES: ' || l_msg_data);
         END LOOP;

         RAISE g_exception_halt_validation;
      END IF;

      l_line_count := l_repv_tbl.COUNT;

      IF (l_line_count <= 0)
      THEN
         fnd_file.put_line (fnd_file.LOG, 'No lines to Purge..');
      ELSE
         fnd_file.put_line (fnd_file.LOG,
                               'Purging Order Lines... Line count = '
                            || l_line_count
                           );

         FOR l_count IN 1 .. l_line_count
         LOOP
            l_del_rec.ID := l_repv_tbl (l_count).ID;
            oks_rep_pub.delete_row (p_api_version        => l_api_version,
                                    p_init_msg_list      => l_init_msg_list,
                                    x_return_status      => l_return_status,
                                    x_msg_count          => l_msg_count,
                                    x_msg_data           => l_msg_data,
                                    p_repv_rec           => l_del_rec
                                   );
         END LOOP;
      END IF;

      errbuf := '';
      retcode := 0;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         -- Retrieve error message into errbuf
         errbuf := SQLERRM;
         retcode := 2;
         fnd_file.put_line (fnd_file.LOG,
                            'Oracle Error Code is -' || TO_CHAR (SQLCODE)
                           );
         fnd_file.put_line (fnd_file.LOG,
                               'Oracle Error Message is -'
                            || SUBSTR (SQLERRM, 1, 512)
                           );
   END oks_order_purge;

   PROCEDURE migrate_aso_queue (
      errbuf    OUT NOCOPY   VARCHAR2,
      retcode   OUT NOCOPY   NUMBER
   )
   IS
      l_init_msg_list              VARCHAR2 (1)       DEFAULT fnd_api.g_false;
      l_commit                     VARCHAR2 (1)       DEFAULT fnd_api.g_false;
      l_return_status              VARCHAR2 (1);
      l_msg_count                  NUMBER;
      l_msg_data                   VARCHAR2 (2000);
      l_wait                       NUMBER             DEFAULT DBMS_AQ.no_wait;
      l_no_more_messages           VARCHAR2 (240);
      l_header_rec                 oe_order_pub.header_rec_type;
      l_old_header_rec             oe_order_pub.header_rec_type;
      l_header_adj_tbl             oe_order_pub.header_adj_tbl_type;
      l_old_header_adj_tbl         oe_order_pub.header_adj_tbl_type;
      l_header_price_att_tbl       oe_order_pub.header_price_att_tbl_type;
      l_old_header_price_att_tbl   oe_order_pub.header_price_att_tbl_type;
      l_header_adj_att_tbl         oe_order_pub.header_adj_att_tbl_type;
      l_old_header_adj_att_tbl     oe_order_pub.header_adj_att_tbl_type;
      l_header_adj_assoc_tbl       oe_order_pub.header_adj_assoc_tbl_type;
      l_old_header_adj_assoc_tbl   oe_order_pub.header_adj_assoc_tbl_type;
      l_header_scredit_tbl         oe_order_pub.header_scredit_tbl_type;
      l_old_header_scredit_tbl     oe_order_pub.header_scredit_tbl_type;
      l_line_tbl                   oe_order_pub.line_tbl_type;
      l_old_line_tbl               oe_order_pub.line_tbl_type;
      l_line_adj_tbl               oe_order_pub.line_adj_tbl_type;
      l_old_line_adj_tbl           oe_order_pub.line_adj_tbl_type;
      l_line_price_att_tbl         oe_order_pub.line_price_att_tbl_type;
      l_old_line_price_att_tbl     oe_order_pub.line_price_att_tbl_type;
      l_line_adj_att_tbl           oe_order_pub.line_adj_att_tbl_type;
      l_old_line_adj_att_tbl       oe_order_pub.line_adj_att_tbl_type;
      l_line_adj_assoc_tbl         oe_order_pub.line_adj_assoc_tbl_type;
      l_old_line_adj_assoc_tbl     oe_order_pub.line_adj_assoc_tbl_type;
      l_line_scredit_tbl           oe_order_pub.line_scredit_tbl_type;
      l_old_line_scredit_tbl       oe_order_pub.line_scredit_tbl_type;
      l_lot_serial_tbl             oe_order_pub.lot_serial_tbl_type;
      l_old_lot_serial_tbl         oe_order_pub.lot_serial_tbl_type;
      l_action_request_tbl         oe_order_pub.request_tbl_type;
      l_oe_line_rec                oe_order_pub.line_rec_type;
      l_dequeue_mode               VARCHAR2 (240)      DEFAULT DBMS_AQ.remove;
      l_navigation                 VARCHAR2 (240)
                                                 DEFAULT DBMS_AQ.next_message;
      l_repv_rec                   oks_rep_pvt.repv_rec_type;
      l_out_repv_rec               oks_rep_pvt.repv_rec_type;
      l_request_id                 NUMBER;
--General Variables
      l_ctr                        NUMBER;
      l_oldline_count              NUMBER;
      l_newline_count              NUMBER;
      l_user_id                    NUMBER;
      l_index                      NUMBER;
      index1                       NUMBER;
      err_msg                      VARCHAR2 (1000)                      := '';
      l_hdrid                      NUMBER                             := NULL;
      dup_val                      VARCHAR2 (1)                         := '';
      l_ord_num                    NUMBER;
      l_exists                     VARCHAR2 (1);

      CURSOR l_order_hdr_csr (p_ordlineid NUMBER)
      IS
         SELECT oh.header_id, oh.order_number
           FROM oe_order_lines_all ol, oe_order_headers_all oh
          WHERE ol.line_id = (p_ordlineid)
            AND oh.org_id = okc_context.get_okc_org_id
            AND oh.header_id = ol.header_id;

      CURSOR l_order_csr (p_ordlineid NUMBER)
      IS
         SELECT org_id, ship_from_org_id, sold_from_org_id,
                NVL (fulfilled_quantity, 0) fqty,
                service_reference_line_id rolineid, header_id
           FROM okx_order_lines_v
          WHERE id1 = (p_ordlineid);

      CURSOR check_ordline_exists (p_ordlineid NUMBER)
      IS
         SELECT 'x'
           FROM oks_reprocessing
          WHERE order_line_id = p_ordlineid;

--Fix for bug 3492335
      CURSOR is_ib_trackable (
         l_ref_order_line_id   NUMBER,
         l_organization_id     NUMBER
      )
      IS
         SELECT comms_nl_trackable_flag
           FROM mtl_system_items_b
          WHERE inventory_item_id = (SELECT inventory_item_id
                                       FROM oe_order_lines_all
                                      WHERE line_id = l_ref_order_line_id)
            AND organization_id = l_organization_id;

      l_order_rec                  l_order_csr%ROWTYPE;
      l_api_version       CONSTANT NUMBER                               := 1.0;
      x_msg_count                  NUMBER;
      x_msg_data                   VARCHAR2 (2000);
      ib_flag                      VARCHAR2 (1);
--
      aso_handle_exception         EXCEPTION;
      aso_handle_normal            EXCEPTION;
   BEGIN
      SAVEPOINT oks_migrate_aso_queue;
      fnd_file.put_line (fnd_file.LOG, 'Start of OC_interface...');
      l_user_id := fnd_global.user_id;
      fnd_file.put_line (fnd_file.LOG, 'User Id : ' || TO_CHAR (l_user_id));
-- Set policy context to ALL
      mo_global.set_policy_context ('B', NULL);

      LOOP
         l_oldline_count := 0;
         l_newline_count := 0;
         aso_order_feedback_pub.get_notice
                   (p_api_version                   => 1.0,
                    p_init_msg_list                 => l_init_msg_list,
                    p_commit                        => l_commit,
                    x_return_status                 => l_return_status,
                    x_msg_count                     => l_msg_count,
                    x_msg_data                      => l_msg_data,
                    p_app_short_name                => 'OKS',
                    p_wait                          => l_wait,
                    x_no_more_messages              => l_no_more_messages,
                    x_header_rec                    => l_header_rec,
                    x_old_header_rec                => l_old_header_rec,
                    x_header_adj_tbl                => l_header_adj_tbl,
                    x_old_header_adj_tbl            => l_old_header_adj_tbl,
                    x_header_price_att_tbl          => l_header_price_att_tbl,
                    x_old_header_price_att_tbl      => l_old_header_price_att_tbl,
                    x_header_adj_att_tbl            => l_header_adj_att_tbl,
                    x_old_header_adj_att_tbl        => l_old_header_adj_att_tbl,
                    x_header_adj_assoc_tbl          => l_header_adj_assoc_tbl,
                    x_old_header_adj_assoc_tbl      => l_old_header_adj_assoc_tbl,
                    x_header_scredit_tbl            => l_header_scredit_tbl,
                    x_old_header_scredit_tbl        => l_old_header_scredit_tbl,
                    x_line_tbl                      => l_line_tbl,
                    x_old_line_tbl                  => l_old_line_tbl,
                    x_line_adj_tbl                  => l_line_adj_tbl,
                    x_old_line_adj_tbl              => l_old_line_adj_tbl,
                    x_line_price_att_tbl            => l_line_price_att_tbl,
                    x_old_line_price_att_tbl        => l_old_line_price_att_tbl,
                    x_line_adj_att_tbl              => l_line_adj_att_tbl,
                    x_old_line_adj_att_tbl          => l_old_line_adj_att_tbl,
                    x_line_adj_assoc_tbl            => l_line_adj_assoc_tbl,
                    x_old_line_adj_assoc_tbl        => l_old_line_adj_assoc_tbl,
                    x_line_scredit_tbl              => l_line_scredit_tbl,
                    x_old_line_scredit_tbl          => l_old_line_scredit_tbl,
                    x_lot_serial_tbl                => l_lot_serial_tbl,
                    x_old_lot_serial_tbl            => l_old_lot_serial_tbl,
                    x_action_request_tbl            => l_action_request_tbl
                   );

         IF NOT (l_return_status = fnd_api.g_ret_sts_success)
         THEN
            FOR i IN 1 .. fnd_msg_pub.count_msg
            LOOP
               fnd_msg_pub.get (p_msg_index          => -1,
                                p_encoded            => 'F',
                                p_data               => l_msg_data,
                                p_msg_index_out      => l_index
                               );
               fnd_file.put_line (fnd_file.LOG, l_msg_data);
            END LOOP;

            ROLLBACK TO oks_migrate_aso_queue;
            RETURN;
         END IF;

         l_newline_count := l_line_tbl.COUNT;
         fnd_file.put_line (fnd_file.LOG,
                            'Lines to process = ' || l_newline_count
                           );
         EXIT WHEN l_no_more_messages = fnd_api.g_true;

         IF l_newline_count <= 0
         THEN                                        --Order Line Record Found
            fnd_file.put_line (fnd_file.LOG, 'No lines to insert');
         ELSE
            fnd_file.put_line (fnd_file.LOG,
                                  'Processing the order lines... line count='
                               || TO_CHAR (l_newline_count)
                              );

            FOR l_count IN 1 .. l_newline_count
            LOOP
               l_exists := 'y';
               fnd_file.put_line (fnd_file.LOG,
                                     'Processing Order Line '
                                  || l_line_tbl (l_count).line_id
                                 );
               fnd_file.put_line
                              (fnd_file.LOG,
                                  'Service Ref Type Code '
                               || l_line_tbl (l_count).service_reference_type_code
                              );
               fnd_file.put_line
                                (fnd_file.LOG,
                                    'Service line Id       '
                                 || l_line_tbl (l_count).service_reference_line_id
                                );
               fnd_file.put_line
                         (fnd_file.LOG,
                             'Profile option value  '
                          || fnd_profile.VALUE
                                            ('OKS_CONTRACTS_VALIDATION_SOURCE')
                         );

               OPEN check_ordline_exists (l_line_tbl (l_count).line_id);

               FETCH check_ordline_exists
                INTO l_exists;

               IF check_ordline_exists%NOTFOUND
               THEN
                  l_exists := 'y';
               END IF;

               CLOSE check_ordline_exists;

               --Check Delayed Service
               IF (l_exists <> 'x')
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                     'Order line not present already...'
                                    );

                  IF     NVL (l_line_tbl (l_count).service_reference_type_code,
                              'REF_TYPE'
                             ) IN ('CUSTOMER_PRODUCT', 'ORDER')
                     AND l_line_tbl (l_count).service_reference_line_id IS NOT NULL
                  THEN                              --Checking Delayed Service
                     --Check Fulfillment
                     l_order_rec.fqty := 0;
                     l_order_rec.rolineid := NULL;
                     l_order_rec.header_id := NULL;

                     OPEN l_order_csr (l_line_tbl (l_count).line_id);

                     FETCH l_order_csr
                      INTO l_order_rec;

                     IF l_order_csr%NOTFOUND
                     THEN
                        l_order_rec.fqty := 0;
                     END IF;

                     CLOSE l_order_csr;

                     fnd_file.put_line (fnd_file.LOG,
                                           'Fulfillment Quantity  '
                                        || l_order_rec.fqty
                                       );
                     fnd_file.put_line (fnd_file.LOG,
                                           'Order Org Id          '
                                        || l_order_rec.org_id
                                       );
                     fnd_file.put_line (fnd_file.LOG,
                                           'Order Organization Id '
                                        || l_order_rec.ship_from_org_id
                                       );
                     fnd_file.put_line (fnd_file.LOG,
                                           'Sold from Org Id      '
                                        || l_order_rec.sold_from_org_id
                                       );
                     okc_context.set_okc_org_context (l_order_rec.org_id,
                                                      NULL);
                     fnd_file.put_line (fnd_file.LOG,
                                           'org_context - '
                                        || TO_CHAR (okc_context.get_okc_org_id)
                                       );
                     fnd_file.put_line
                                 (fnd_file.LOG,
                                     'organization_context - '
                                  || TO_CHAR
                                          (okc_context.get_okc_organization_id)
                                 );

--Check IB Trackable flag
                     IF NVL (l_line_tbl (l_count).service_reference_type_code,
                             'REF_TYPE'
                            ) = 'ORDER'
                     THEN
                        OPEN is_ib_trackable
                               (l_line_tbl (l_count).service_reference_line_id,
                                okc_context.get_okc_organization_id
                               );

                        FETCH is_ib_trackable
                         INTO ib_flag;

                        CLOSE is_ib_trackable;
                     ELSE
                        ib_flag := 'Y';
                     END IF;

                     IF NVL (ib_flag, 'N') = 'Y'
                     THEN
                        IF l_order_rec.fqty > 0
                        THEN
                           OPEN l_order_hdr_csr (l_line_tbl (l_count).line_id);

                           FETCH l_order_hdr_csr
                            INTO l_hdrid, l_ord_num;

                           IF l_order_hdr_csr%NOTFOUND
                           THEN
                              fnd_file.put_line (fnd_file.LOG,
                                                 ' Invalid Order line ID'
                                                );

                              CLOSE l_order_hdr_csr;
                           ELSE
                              CLOSE l_order_hdr_csr;

                              fnd_file.put_line (fnd_file.LOG,
                                                 'Order Header ID ' || l_hdrid
                                                );
                              l_repv_rec.order_id := l_hdrid;
                              l_repv_rec.order_line_id :=
                                                  l_line_tbl (l_count).line_id;
                              l_repv_rec.order_number := l_ord_num;
                              l_repv_rec.success_flag := 'N';
                              l_repv_rec.source_flag := 'ASO';
                              l_repv_rec.reprocess_yn := 'Y';
                              SAVEPOINT before_insert;
                              oks_rep_pub.insert_row
                                          (p_api_version        => 1.0,
                                           p_init_msg_list      => l_init_msg_list,
                                           x_return_status      => l_return_status,
                                           x_msg_count          => l_msg_count,
                                           x_msg_data           => l_msg_data,
                                           p_repv_rec           => l_repv_rec,
                                           x_repv_rec           => l_out_repv_rec
                                          );
                              fnd_file.put_line
                                          (fnd_file.LOG,
                                              'OKS_REP_PUB - RETURN STATUS : '
                                           || l_return_status
                                          );

                              IF NOT (l_return_status =
                                                     fnd_api.g_ret_sts_success
                                     )
                              THEN
                                 FOR i IN 1 .. fnd_msg_pub.count_msg
                                 LOOP
                                    fnd_msg_pub.get
                                                  (p_msg_index          => -1,
                                                   p_encoded            => 'F',
                                                   p_data               => l_msg_data,
                                                   p_msg_index_out      => l_index
                                                  );

                                    SELECT INSTR (l_msg_data,
                                                  'ORA-00001',
                                                  1,
                                                  1
                                                 )
                                      INTO index1
                                      FROM DUAL;

                                    IF (index1 > 0)
                                    THEN
                                       dup_val := 'Y';
                                       EXIT;
                                    END IF;

                                    fnd_file.put_line
                                                (fnd_file.LOG,
                                                    'oks_rep_pub.insert_row: '
                                                 || l_msg_data
                                                );
                                 END LOOP;

                                 IF (dup_val <> 'Y')
                                 THEN
                                    RAISE g_exception_halt_validation;
                                 END IF;

                                 l_return_status := fnd_api.g_ret_sts_success;
                              END IF;
                           END IF;
                        END IF;
                     END IF;
                  END IF;
               ELSE
                  fnd_file.put_line (fnd_file.LOG, 'Duplicate Order Line');
               END IF;
            END LOOP;
         END IF;
      END LOOP;

      errbuf := '';
      retcode := 0;
      COMMIT WORK;
      fnd_file.put_line (fnd_file.LOG, 'Order Capture INT Program finished.');
   EXCEPTION
      WHEN g_exception_halt_validation
      THEN
         ROLLBACK TO before_insert;
      WHEN OTHERS
      THEN
         ROLLBACK TO before_insert;
         -- Retrieve error message into errbuf
         errbuf := SQLERRM;
         retcode := 2;
         fnd_file.put_line (fnd_file.LOG,
                            'Oracle Error Code is -' || TO_CHAR (SQLCODE)
                           );
         fnd_file.put_line (fnd_file.LOG,
                               'Oracle Error Message is -'
                            || SUBSTR (SQLERRM, 1, 512)
                           );
   END migrate_aso_queue;
END xxoks_ocint_pub;
/
