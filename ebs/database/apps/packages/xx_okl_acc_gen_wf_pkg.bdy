/*
** File Name: xx_okl_acc_gen_wf_pkg.pkb
** Created by: Devendra Singh 
** Revision: 1.0
** Creation Date: 13/01/2014
--------------------------------------------------
** Purpose : Package defined to derive the account
--------------------------------------------------
** Version    Date        Name           Desc
--------------------------------------------------
** 1.0     13/01/2014 Devendra Singh Initial build for CR-1242
*/
CREATE OR REPLACE PACKAGE BODY apps.xx_okl_acc_gen_wf_pkg
AS
   /*
   ** Procedure Name: set_ccid
   ** Created by: Devendra Singh 
   ** Revision: 1.0
   ** Creation Date: 13/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Procedure will be called from the Account Generator API to 
   **           invoke the workflow to generate the ccid
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     13/01/2014 Devendra Singh Initial build
   */
   PROCEDURE set_ccid (
      itemtype   IN              VARCHAR2,
      itemkey    IN              VARCHAR2,
      actid      IN              NUMBER,
      funcmode   IN              VARCHAR2,
      RESULT     OUT NOCOPY      VARCHAR2
   )
   AS
      l_pl_account      VARCHAR2 (10);
      l_pl_account1     VARCHAR2 (10);
      l_source_id       NUMBER;
      lc_tmpt_name      okl_ae_templates_all.NAME%TYPE;
      ln_ccid           NUMBER;
      lc_ae_line_type   okl_ae_tmpt_lnes.ae_line_type%TYPE;
      l_atl_id          NUMBER;
      lc_comb_segment   VARCHAR2 (200);

      CURSOR get_pl_account (p_source_id NUMBER)
      IS
         SELECT khr.attribute1, khr.attribute3
           FROM okl_txd_ar_ln_dtls_b tld,
                okl_trx_ar_invoices_b tai,
                okl_txl_ar_inv_lns_b til,
                okl_k_headers khr
          WHERE tld.ID = p_source_id
            AND til.tai_id = tai.ID
            AND tld.til_id_details = til.ID
            AND khr.ID = tai.khr_id;

      CURSOR check_ele_csr (p_atl_id NUMBER)
      IS
         SELECT avl.NAME, atl.code_combination_id, ae_line_type
           FROM okl_ae_templates_all avl,
                okl_ae_tmpt_lnes atl,
                okl_ae_tmpt_sets_all aes,
                okl_products prd,
                okl_pdt_pqy_vals_uv pqv
          WHERE avl.ID = atl.avl_id
            AND aes.ID = avl.aes_id
            AND prd.aes_id = aes.ID
            AND pqv.pdt_id = prd.ID
            AND pqv.NAME = 'LEASE'
            AND pqv.VALUE ='LEASEOP'
            AND atl.ID = p_atl_id
            AND atl.crd_code = 'C';

      CURSOR get_segments_csr (p_ae_line_type VARCHAR2)
      IS
         SELECT   ae_line_type, oagrl.ID, oagrl.SEGMENT, oagrl.segment_number,
                  oagrl.agr_id, oagrl.SOURCE, oagrl.constants
             FROM okl_acc_gen_rules_all oagr, okl_acc_gen_rul_lns oagrl
            WHERE oagr.ID = oagrl.agr_id AND ae_line_type = p_ae_line_type
         ORDER BY segment_number ASC;

      lcr_segments      get_segments_csr%ROWTYPE;
   BEGIN
      --dp_debug_p ('in custom pkg');
      IF (funcmode = 'RUN')
      THEN
         l_atl_id :=
            wf_engine.getitemattrnumber (itemtype,
                                         itemkey,
                                         'TEMPLATE_LINE_ID'
                                        );
         l_source_id :=
                  wf_engine.getitemattrnumber (itemtype, itemkey, 'SOURCE_ID');

         --dp_debug_p ('l_atl_id' || l_atl_id);
         --dp_debug_p ('l_source_id' || l_source_id);
         OPEN get_pl_account (l_source_id);

         FETCH get_pl_account
          INTO l_pl_account, l_pl_account1;

         CLOSE get_pl_account;

         --dp_debug_p ('pl account' || l_pl_account);
         IF l_pl_account IS NOT NULL OR l_pl_account1 IS NOT NULL
         THEN
            OPEN check_ele_csr (l_atl_id);

            FETCH check_ele_csr
             INTO lc_tmpt_name, ln_ccid, lc_ae_line_type;

            CLOSE check_ele_csr;

            --dp_debug_p ('lc_tmpt_name' || lc_tmpt_name);
            IF lc_tmpt_name IN ('BILLING - MAINTENANCE', 'BILLING - RENT')
            THEN
               OPEN get_segments_csr (lc_ae_line_type);

               --dp_debug_p ('lc_ae_line_type' || lc_ae_line_type);
               LOOP
                  FETCH get_segments_csr
                   INTO lcr_segments;

                  IF get_segments_csr%NOTFOUND
                  THEN
                     EXIT;
                  END IF;

                  IF lcr_segments.constants IS NOT NULL
                  THEN
                     IF lcr_segments.segment_number = 1
                     THEN
                        lc_comb_segment := lcr_segments.constants;
                     ELSE
                        lc_comb_segment :=
                             lc_comb_segment || '.' || lcr_segments.constants;
                     END IF;
                  ELSE
                     IF lc_tmpt_name IN ('BILLING - MAINTENANCE')
                     THEN
                        lc_comb_segment :=
                                       lc_comb_segment || '.' || l_pl_account;
                     ELSIF lc_tmpt_name IN ('BILLING - RENT')
                     THEN
                        lc_comb_segment :=
                                      lc_comb_segment || '.' || l_pl_account1;
                     END IF;
                  END IF;
               END LOOP;

               CLOSE get_segments_csr;
            END IF;
         END IF;

         --dp_debug_p ('lc_comb_segment custom ' || lc_comb_segment);
         ln_ccid :=
            fnd_flex_ext.get_ccid
               (application_short_name      => 'SQLGL',
                key_flex_code               => 'GL#',
                structure_number            => okl_accounting_util.get_chart_of_accounts_id,
                validation_date             => fnd_date.date_to_canonical
                                                                      (SYSDATE),
                concatenated_segments       => lc_comb_segment
               );
         --dp_debug_p ('ccid in custom ' || ln_ccid);
         wf_engine.setitemattrnumber (itemtype      => itemtype,
                                      itemkey       => itemkey,
                                      aname         => 'TEMPLATE_LINE_CCID',
                                      avalue        => ln_ccid
                                     );
         --dp_debug_p ('success');
         RESULT := 'COMPLETE:';
         RETURN;
      ELSIF (funcmode = 'CANCEL')
      THEN
         RESULT := 'COMPLETE:';
      ELSE
         RETURN;
      END IF;
   --dp_debug_p ('end');
   END set_ccid;
END xx_okl_acc_gen_wf_pkg;
/