CREATE OR REPLACE PACKAGE BODY xxobjt_wf_mail AS
  ---------------------------------------
  -- GLOBALS
  ---------------------------------------

  g_item_type        VARCHAR2(50) := 'XXMAIL';
  g_workflow_process VARCHAR2(50) := 'SENDMAIL';
  -------------------------------------------------
  -- send_mail
  --------------------------------------------------
  PROCEDURE send_mail(p_to_role     VARCHAR2,
                      p_cc_mail     VARCHAR2 DEFAULT NULL,
                      p_bcc_mail    VARCHAR2 DEFAULT NULL,
                      p_subject     VARCHAR2,
                      p_body_text   VARCHAR2 DEFAULT NULL,
                      p_body_html   VARCHAR2 DEFAULT NULL,
                      p_body_proc   VARCHAR2 DEFAULT NULL,
                      p_att1_proc   VARCHAR2 DEFAULT NULL,
                      p_att2_proc   VARCHAR2 DEFAULT NULL,
                      p_att3_proc   VARCHAR2 DEFAULT NULL,
                      p_err_code    OUT NUMBER,
                      p_err_message OUT VARCHAR2) IS

    PRAGMA AUTONOMOUS_TRANSACTION;

    l_itemkey wf_items.item_key%TYPE;

  BEGIN

    p_err_code    := 0;
    p_err_message := NULL;

    SELECT xxobjt_wf_mail_seq.NEXTVAL INTO l_itemkey FROM dual;

    wf_engine.createprocess(itemtype => g_item_type,
                            itemkey  => l_itemkey,
                            process  => g_workflow_process);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => l_itemkey,
                              aname    => 'SEND_TO',
                              avalue   => upper(p_to_role));

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => l_itemkey,
                              aname    => 'SUBJECT',
                              avalue   => p_subject);

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => l_itemkey,
                              aname    => 'XX_BODY_TEXT',
                              avalue   => p_body_text);

    -- Dalit A. Raviv 22/07/2012
    -- add repalce that maill if get separate as "," it will be
    -- replace with ";" this is the separator WorkFlow can get.
    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => l_itemkey,
                              aname    => '#WFM_CC',
                              avalue   => replace(p_cc_mail,',',';'));  -- Dalit A. Raviv 22/07/2012

    wf_engine.setitemattrtext(itemtype => g_item_type,
                              itemkey  => l_itemkey,
                              aname    => '#WFM_BCC',
                              avalue   => replace(p_bcc_mail,',',';')); -- Dalit A. Raviv 22/07/2012

    -- check body text
    IF p_body_proc IS NOT NULL THEN

      wf_engine.setitemattrdocument(itemtype   => g_item_type,
                                    itemkey    => l_itemkey,
                                    aname      => 'XX_CLOB_BODY',
                                    documentid => 'plsqlclob:' ||
                                                  p_body_proc);
    END IF;
    IF p_body_html IS NOT NULL THEN

      -- INSERT HTML TO TEMP TABLE;

      INSERT INTO xxobjt_wf_mail_param
        (item_key, body_html)
      VALUES
        (l_itemkey, p_body_html);
      COMMIT;

      wf_engine.setitemattrdocument(itemtype   => g_item_type,
                                    itemkey    => l_itemkey,
                                    aname      => 'XX_BODY_HTML',
                                    documentid => 'plsqlclob:xxobjt_wf_mail_support.get_body_html/' ||
                                                  l_itemkey);

    END IF;

    IF p_att1_proc IS NOT NULL THEN
      wf_engine.setitemattrdocument(itemtype   => g_item_type,
                                    itemkey    => l_itemkey,
                                    aname      => 'XX_BLOB_ATTACHMENT1',
                                    documentid => 'plsqlblob:' ||
                                                  p_att1_proc);
    END IF;

    IF p_att2_proc IS NOT NULL THEN
      wf_engine.setitemattrdocument(itemtype   => g_item_type,
                                    itemkey    => l_itemkey,
                                    aname      => 'XX_BLOB_ATTACHMENT2',
                                    documentid => 'PLSQLBLOB:' ||
                                                  p_att2_proc);
    END IF;

    IF p_att3_proc IS NOT NULL THEN
      wf_engine.setitemattrdocument(itemtype   => g_item_type,
                                    itemkey    => l_itemkey,
                                    aname      => 'XX_BLOB_ATTACHMENT3',
                                    documentid => 'PLSQLBLOB:' ||
                                                  p_att3_proc);
    END IF;

    -- START PROCESS

    wf_engine.startprocess(itemtype => g_item_type, itemkey => l_itemkey);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code    := 1;
      p_err_message := 'xxobjt_wf_mail.SEND_MAIL:' || SQLERRM;

  END;
  -------------------------------------------------
  -- send_mail_html
  --------------------------------------------------

  PROCEDURE send_mail_html(p_to_role     VARCHAR2,
                           p_cc_mail     VARCHAR2 DEFAULT NULL,
                           p_bcc_mail    VARCHAR2 DEFAULT NULL,
                           p_subject     VARCHAR2,
                           p_body_html   VARCHAR2 DEFAULT NULL,
                           p_att1_proc   VARCHAR2 DEFAULT NULL,
                           p_att2_proc   VARCHAR2 DEFAULT NULL,
                           p_att3_proc   VARCHAR2 DEFAULT NULL,
                           p_err_code    OUT NUMBER,
                           p_err_message OUT VARCHAR2) IS
  BEGIN

    send_mail(p_to_role,
              p_cc_mail,
              p_bcc_mail,
              p_subject,
              NULL,
              p_body_html,
              NULL,
              p_att1_proc,
              p_att2_proc,
              p_att3_proc,
              p_err_code,
              p_err_message);

  END;
  -------------------------------------------------
  -- send_mail_text
  --------------------------------------------------

  PROCEDURE send_mail_text(p_to_role     VARCHAR2,
                           p_cc_mail     VARCHAR2 DEFAULT NULL,
                           p_bcc_mail    VARCHAR2 DEFAULT NULL,
                           p_subject     VARCHAR2,
                           p_body_text   VARCHAR2 DEFAULT NULL,
                           p_att1_proc   VARCHAR2 DEFAULT NULL,
                           p_att2_proc   VARCHAR2 DEFAULT NULL,
                           p_att3_proc   VARCHAR2 DEFAULT NULL,
                           p_err_code    OUT NUMBER,
                           p_err_message OUT VARCHAR2) IS
  BEGIN
    send_mail(p_to_role,
              p_cc_mail,
              p_bcc_mail,
              p_subject,
              p_body_text,
              NULL,
              NULL,
              p_att1_proc,
              p_att2_proc,
              p_att3_proc,
              p_err_code,
              p_err_message);

  END;
  ----------------------------------------------------------
  -- send_mail_body_proc
  ----------------------------------------------------------
  PROCEDURE send_mail_body_proc(p_to_role     VARCHAR2,
                                p_cc_mail     VARCHAR2 DEFAULT NULL,
                                p_bcc_mail    VARCHAR2 DEFAULT NULL,
                                p_subject     VARCHAR2,
                                p_body_proc   VARCHAR2 DEFAULT NULL,
                                p_att1_proc   VARCHAR2 DEFAULT NULL,
                                p_att2_proc   VARCHAR2 DEFAULT NULL,
                                p_att3_proc   VARCHAR2 DEFAULT NULL,
                                p_err_code    OUT NUMBER,
                                p_err_message OUT VARCHAR2) IS

  BEGIN
    send_mail(p_to_role,
              p_cc_mail,
              p_bcc_mail,
              p_subject,
              NULL,
              NULL,
              p_body_proc,
              p_att1_proc,
              p_att2_proc,
              p_att3_proc,
              p_err_code,
              p_err_message);

  END;
  ------------------------------------------------------------
  -- get_header_html
  -----------------------------------------------------------
  FUNCTION get_header_html RETURN VARCHAR2 IS
  BEGIN
    fnd_message.set_name('XXOBJT', 'XXOBJT_MAIL_HEADER');
    RETURN fnd_message.get;
  END;

  ------------------------------------------------------------
  -- get_footer_html
  -----------------------------------------------------------

  FUNCTION get_footer_html RETURN VARCHAR2 IS
  BEGIN
    fnd_message.set_name('XXOBJT', 'XXOBJT_MAIL_FOOTER');
    RETURN fnd_message.get;
  END;

END;
/
