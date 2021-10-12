CREATE OR REPLACE PACKAGE BODY xxpo_po_linkage_pkg IS

  --------------------------------------------------------------------
  --  name:            XXPO_PO_LINKAGE_PKG
  --  create by:       ELLA.MALCHI
  --  Revision:        1.1
  --  creation date:   02/09/2009 13:25:06
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/09/2009  Ella Malchi       initial build
  --  1.1  27/10/2013  Dalit A. Raviv    Procedure delete_po_linkage - Add parameter of release_num
  --------------------------------------------------------------------

  PROCEDURE get_catalog_price(t_order_header          po_order_header_rec_type,
                              t_order_line            po_order_line_rec_type,
                              t_selected_quote        quotation_rec_type,
                              t_quotations            quotation_tbl_type,
                              x_base_unit_price       OUT NOCOPY NUMBER,
                              x_from_line_location_id OUT NOCOPY NUMBER,
                              x_price                 OUT NOCOPY NUMBER,
                              x_return_status         OUT NOCOPY VARCHAR2) IS
  
    l_quotation_price NUMBER;
    --l_po_price          number;
    l_linkage_rate      NUMBER := NULL;
    l_linkage_currency  VARCHAR2(3) := NULL;
    l_linkage_date      DATE := NULL;
    l_linkage_conv_type VARCHAR2(20) := NULL;
    l_rate              NUMBER := NULL;
  
  BEGIN
  
    x_return_status := fnd_api.g_ret_sts_success;
    x_price         := NULL;
  
    l_quotation_price := nvl(t_selected_quote.price_break_curr_price,
                             t_selected_quote.line_curr_price);
  
    /*************************************************************************************************
      # if linkage does not exists we need to convert quotation currency to po currency through
        quotation to functional (quotation rate date) and functional to po (po rate date).
      # if linkage does exists we need to convert quotation currency to po currency through quotation
        to linkage (quotation rate date) and then linkage to po (linkage rate date).
    /************************************************************************************************/
    xxpo_utils_pkg.get_linkage_plus(t_order_header.po_number,
                                    l_linkage_rate,
                                    l_linkage_currency,
                                    l_linkage_date,
                                    l_linkage_conv_type);
  
    IF l_linkage_rate IS NULL THEN
      IF t_selected_quote.currency_code = t_order_header.currency_code THEN
        x_price := round(l_quotation_price, 4);
      ELSE
        x_price := round((l_quotation_price * nvl(t_selected_quote.rate, 1)) /
                         nvl(t_order_header.rate, 1),
                         4);
      
      END IF;
    ELSE
      l_rate := gl_currency_api.get_closest_rate(x_from_currency   => t_selected_quote.currency_code,
                                                 x_to_currency     => l_linkage_currency,
                                                 x_conversion_date => nvl(t_selected_quote.rate_date,
                                                                          l_linkage_date),
                                                 x_conversion_type => 'Corporate',
                                                 x_max_roll_days   => 7);
    
      x_price := round((l_quotation_price * nvl(l_rate, 1)) *
                       nvl(l_linkage_rate, 1),
                       4);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
    
      fnd_message.set_name('XXOBJT', 'XXPO_LINKAGE_CONVERSION_ERROR');
      fnd_message.set_token('ERR', SQLERRM);
      x_return_status := fnd_api.g_ret_sts_error;
    
  END get_catalog_price;

  --------------------------------------------------------------------
  --  name:            delete_po_linkage
  --  create by:       Ella Malchi
  --  Revision:        1.0
  --  creation date:   02/09/2009 13:25:06
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  02/09/2009  Ella Malchi       initial build
  --  1.1  27/10/2013  Dalit A. Raviv    add parameter of p_release_num
  --------------------------------------------------------------------
  PROCEDURE delete_po_linkage(errbuf        OUT VARCHAR2,
                              retcode       OUT VARCHAR2,
                              po_number     IN clef062_po_index_esc_set.document_id%TYPE,
                              p_release_num IN NUMBER) IS
  
    l_temp NUMBER := 0;
    --lv_error_code varchar2(10);
    --lv_error_msg  varchar2(1000);
  
  BEGIN
  
    BEGIN
      -- 27/10/2013 Dalit A. Raviv add parameter of p_Release_num
      IF p_release_num IS NULL THEN
        SELECT 1
          INTO l_temp
          FROM po_line_locations_all pll, po_headers_all pha
         WHERE (nvl(pll.closed_code, 'OPEN') = 'CLOSED' OR
               nvl(pll.closed_flag, 'N') = 'Y' OR
               nvl(pll.quantity_received, 0) > 0)
           AND nvl(pll.cancel_flag, 'N') = 'N'
           AND pll.po_header_id = pha.po_header_id
           AND pha.segment1 = po_number
           AND rownum < 2;
      
        errbuf  := 'Linkage for PO ' || po_number || ' can not be deleted';
        retcode := 1;
      ELSE
        -- 27/10/2013 Dalit A. Raviv add parameter of p_Release_num
        SELECT 1
          INTO l_temp
          FROM po_line_locations_all pll,
               po_headers_all        pha,
               po_releases_all       por
         WHERE (nvl(pll.closed_code, 'OPEN') = 'CLOSED' OR
               nvl(pll.closed_flag, 'N') = 'Y' OR
               nvl(pll.quantity_received, 0) > 0)
           AND nvl(pll.cancel_flag, 'N') = 'N'
           AND pll.po_header_id = pha.po_header_id
           AND pha.segment1 = po_number
              --
           AND por.po_release_id = pll.po_release_id
           AND por.po_header_id = pha.po_header_id
           AND por.release_num = p_release_num
              --
           AND rownum < 2;
      
        errbuf  := 'Linkage for PO ' || po_number || ' Release ' ||
                   p_release_num || ' can not be deleted';
        retcode := 1;
      END IF;
    
    EXCEPTION
      WHEN no_data_found THEN
        IF p_release_num IS NULL THEN
          DELETE FROM clef062_po_index_esc_set cs
           WHERE cs.module = 'PO'
             AND cs.document_id = po_number;
          COMMIT;
        
          fnd_file.put_line(fnd_file.log,
                            'Linkage for PO ' || po_number ||
                            ' was deleted successfully');
        ELSE
          DELETE FROM clef062_po_index_esc_set cs
           WHERE cs.module = 'PO'
             AND cs.document_id = po_number
             AND cs.release_num = p_release_num;
          COMMIT;
        
          fnd_file.put_line(fnd_file.log,
                            'Linkage for PO ' || po_number || ' Release ' ||
                            p_release_num || ' was deleted successfully');
        END IF;
    END;
  
  END delete_po_linkage;
  --------------------------------------------------------------------
  --  name:            update_header_id
  --  create by:       Vitaly
  --  Revision:        1.0
  --  creation date:   21/01/2014
  --------------------------------------------------------------------
  --  purpose : CUST-6  CR-1254 - Populate PO Header ID for Standard linked PO
  --------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  21/01/2014  Vitaly         initial build
  --------------------------------------------------------------------
  PROCEDURE update_header_id(errbuf      OUT VARCHAR2,
                             retcode     OUT VARCHAR2,
                             p_days_back IN NUMBER) IS
    l_records_updated NUMBER;
  BEGIN
    errbuf  := 'Success';
    retcode := '0';
  
    IF p_days_back IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log,
                        '============================================================================================');
      fnd_file.put_line(fnd_file.log,
                        '============= parameter P_DAYS_BACK=' ||
                        p_days_back ||
                        ' ====================================================');
    END IF;
  
    UPDATE clef062_po_index_esc_set l
       SET l.po_header_id =
           (SELECT po.po_header_id
              FROM po_headers_all po
             WHERE po.segment1 = l.document_id
               AND po.org_id = 81)
     WHERE l.po_header_id IS NULL
       AND l.creation_date >= SYSDATE - nvl(p_days_back, 0);
  
    l_records_updated := SQL%ROWCOUNT;
    COMMIT;
  
    IF l_records_updated > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        '============================================================================================');
      fnd_file.put_line(fnd_file.log,
                        '========= ' || l_records_updated ||
                        ' records in table CLEF062_PO_INDEX_ESC_SET.PO_HEADER_ID were UPDATED ==========');
      fnd_file.put_line(fnd_file.log,
                        '============================================================================================');
    ELSE
      fnd_file.put_line(fnd_file.log,
                        '============================================================================================');
      fnd_file.put_line(fnd_file.log,
                        '============= NO RECORDS UPDATED in table CLEF062_PO_INDEX_ESC_SET.PO_HEADER_ID ! ==========');
      fnd_file.put_line(fnd_file.log,
                        '============================================================================================');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Unexpected Error in procedure xxpo_po_linkage_pkg.update_header_id : ' ||
                 SQLERRM;
      retcode := '2';
      ROLLBACK;
  END update_header_id;
  --------------------------------------------------------------------------------------------------

END xxpo_po_linkage_pkg;
/
