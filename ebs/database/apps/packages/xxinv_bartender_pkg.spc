CREATE OR REPLACE PACKAGE "XXINV_BARTENDER_PKG" AUTHID CURRENT_USER IS

  --------------------------------------------------------------------
  --  name:            XXINV_BARTENDER_PKG
  --  create by:       Eli.Ivanir
  --  Revision:        1.11
  --  creation date:   7/8/2009
  --------------------------------------------------------------------
  --  purpose :        REP354 - Receiving Stickers
  --                   Handle BarTender Printings
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    07/08/09    Eli.Ivanir       Initial Build
  --  1.1    5.9.10      yuval tal        change/add  revision logic  at procedures :
  --                                      print_transaction
  --                                      print_rcv_pack
  --  1.2    5.5.11      yuval tal        add print_general_stiker
  --  1.3    29.4.12     yuval tal        add  print_dangerous_mat_stiker CR404
  --  1.4    11.11.12    yuval tal        print_dangerous_mat_stiker: modify param order in
  --                                      in case of quantity null : get quantity by select
  --  1.5    12.12.12    yuval tal        cust612/cr618 Send Formulations Lot data to Inkjet printerSend Formulations Lot data to Inkjet printer
  --                                      add set_ink_printer and    call_printer_tcp
  --  1.6    29.08.13    yuval tal        rep 354 cr 980 add  print_rcv_pack_w
  --  1.7    01.09.13    yuval tal        rep 354 cr 981 add  print_Inspection_Release
  --  1.8    07/10/2013  Dalit A. Raviv   add print_wpi_inspection_release (CR1022)
  --  1.9    05.11.13    yuval tal        cr 1079  add print_subinventory_locator
  --  1.10   25/11/2013  Dalit A. Raviv   add print_ssys_rcv (CR1116 EP Project)
  --  1.11   22/01/2014  Dalit A. Raviv   new procedure print_auto_label_lot_bottling CR 1259
  --  1.12   29/05/2014  Dalit A. Raviv   CHG0032329 - XX: Print Kanban Label Sticker program support printing multi labels
  --  1.13   28/09/2014  Dalit A. Raviv   CHG0032719 - Release inspection stickers add locator parameter
  --  1.14   16/03/2015  Dalit A. Raviv   CHG0034195 - add procedure print_dft_med
  --  1.15   28/09/2014  yuval tal        CHG0032574 add print_ato_hasp_lbl
  --  1.16   14/02/2018  bellona banerjee CHG0041294 - Added P_Delivery_Name to print_dangerous_mat_stiker as part of delivery_id to delivery_name conversion
  --  1.3    26/02/2019  Roman W.         CHG0045071 - Tavor pack of 7 - add Pack QTY as parameter to XX: Print Bottling lot job sticker
  --  1.31   26/02/2019  Roman W.         CHG0044871 - added parameter "p_job_fg" to xxinv_bartender_pkg.print_resin_pack
  --  1.4    27/02/2019  Roman W.         CHG0045832 - Change sticker -XX:Print bottling sticker after hamara
  --                                           created new procedure : print_resin_pack_small_hamara
  --  1.5    16/7/2019   yuval tal        CHG0046031 - modify print_rcv_pack_w
  --  1.6    13/01/2019  Roman W.         CHG0047181 - New Inkjet printer in Resin plant
  --                                             ValueSet : XXINV_INKJET_PRINTERS
  --                                          1) XX: Send Formulations Lot to Desktop Inkjet
  --                                                    XXINV_BARTENDER_PKG.print_resin_pack_ink
  --
  --                                          2) XX: Send Formulations Lot to Desktop Inkjet after Hamara
  --                                                    XXINV_BARTENDER_pkg.print_resin_pack_hamara_ink
  --------------------------------------------------------------------------------------------------------

  --   v_bartender_txt_location VARCHAR2(20) := 'B:\';
  v_bartender_txt_location VARCHAR2(50) := '"%Trigger File Name%"';

  PROCEDURE call_printer_tcp(errbuf       OUT VARCHAR2,
                             retcode      OUT VARCHAR2,
                             p_printer_ip VARCHAR2,
                             p_port       NUMBER,
                             p_string     VARCHAR2);

  PROCEDURE print_rcv_pack_w(errbuf           OUT VARCHAR2,
                             retcode          OUT VARCHAR2,
                             p_stiker_name    IN VARCHAR2,
                             p_printer_name   IN VARCHAR2,
                             p_fm_receipt_num IN NUMBER,
                             p_to_receipt_num IN NUMBER,
                             p_org_id         IN NUMBER,
                             p_copies         IN NUMBER,
                             p_item           IN VARCHAR2,
                             p_location       IN VARCHAR2,
                             p_quantity       NUMBER);
  --------------------------------------------------------------------------------
  -- Ver     When          Who           Description
  -- ------  ------------  ------------  -----------------------------------------
  -- 1.0     26/02/2019    Roman W.       CHG0044871
  --                                         Concurrent       : XXWIPFLSTCK
  --                                         Barcode Template : Resin_Small
  -- 1.1     16/09/2020    Roman W.       CHG0048593 - Change formulation sticker and desktop inkjet
  --------------------------------------------------------------------------------
  PROCEDURE print_resin_pack(errbuf         OUT VARCHAR2,
                             retcode        OUT VARCHAR2,
                             p_stiker_name  IN VARCHAR2,
                             p_printer_name IN VARCHAR2,
                             p_bot_lot      IN VARCHAR2, -- Added by Roman W. 16/09/2020 CHG0048593
                             p_org_id       IN NUMBER,
                             p_quantity     IN NUMBER,
                             p_location     IN VARCHAR2,
                             p_job_fg       IN VARCHAR2 -- CHG0044871
                             );

  PROCEDURE print_rcv_pack(errbuf           OUT VARCHAR2,
                           retcode          OUT VARCHAR2,
                           p_stiker_name    IN VARCHAR2,
                           p_printer_name   IN VARCHAR2,
                           p_fm_receipt_num IN NUMBER,
                           p_to_receipt_num IN NUMBER,
                           p_org_id         IN NUMBER,
                           p_quantity       IN NUMBER,
                           p_item           IN VARCHAR2,
                           p_location       IN VARCHAR2);

  PROCEDURE print_whtrans_big_pack(errbuf         OUT VARCHAR2,
                                   retcode        OUT VARCHAR2,
                                   p_stiker_name  IN VARCHAR2,
                                   p_printer_name IN VARCHAR2,
                                   p_job_name     IN VARCHAR2,
                                   p_org_id       IN NUMBER,
                                   p_copies       IN NUMBER,
                                   p_location     IN VARCHAR2,
                                   p_qty          NUMBER);

  PROCEDURE print_whtrans_components(errbuf         OUT VARCHAR2,
                                     retcode        OUT VARCHAR2,
                                     p_stiker_name  IN VARCHAR2,
                                     p_printer_name IN VARCHAR2,
                                     p_job_name     IN VARCHAR2,
                                     p_org_id       IN NUMBER,
                                     p_quantity     IN NUMBER,
                                     p_location     IN VARCHAR2);

  PROCEDURE print_prodcompissue(errbuf         OUT VARCHAR2,
                                retcode        OUT VARCHAR2,
                                p_stiker_name  IN VARCHAR2,
                                p_printer_name IN VARCHAR2,
                                p_job_name     IN VARCHAR2,
                                p_org_id       IN NUMBER,
                                p_quantity     IN NUMBER,
                                p_location     IN VARCHAR2);
  --------------------------------------------------------------------
  --  name:            print_dft
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   XX/XX/XXXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/XXXXX XXXXXx            initial build
  --  1.1  29/05/2014  Dalit A. Raviv    CHG0032329 - Adjust XX: Print Kanban Label Sticker program
  --                                     to support printing multi labels
  --                                     add parameter p_kanban_num_to
  --------------------------------------------------------------------
  PROCEDURE print_dft(errbuf          OUT VARCHAR2,
                      retcode         OUT VARCHAR2,
                      p_stiker_name   IN VARCHAR2,
                      p_printer_name  IN VARCHAR2,
                      p_is_full       IN VARCHAR2,
                      p_org_id        IN NUMBER,
                      p_kanban_number IN VARCHAR2,
                      p_kanban_num_to IN VARCHAR2,
                      p_quantity      IN NUMBER,
                      p_location      IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            print_dft_med
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/03/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034195 - Sam population as print_dft but want to have medium
  --                   label and suplier info.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/03/2015  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE print_dft_med(errbuf          OUT VARCHAR2,
                          retcode         OUT VARCHAR2,
                          p_stiker_name   IN VARCHAR2,
                          p_printer_name  IN VARCHAR2,
                          p_is_full       IN VARCHAR2,
                          p_org_id        IN NUMBER,
                          p_kanban_number IN VARCHAR2,
                          p_kanban_num_to IN VARCHAR2,
                          p_quantity      IN NUMBER,
                          p_location      IN VARCHAR2);

  PROCEDURE print_parts(errbuf         OUT VARCHAR2,
                        retcode        OUT VARCHAR2,
                        p_stiker_name  IN VARCHAR2,
                        p_printer_name IN VARCHAR2,
                        p_segment      IN VARCHAR2,
                        p_org_id       IN NUMBER,
                        p_quantity     IN NUMBER,
                        p_location     IN VARCHAR2);

  PROCEDURE print_transaction(errbuf             OUT VARCHAR2,
                              retcode            OUT VARCHAR2,
                              p_stiker_name      IN VARCHAR2,
                              p_printer_name     IN VARCHAR2,
                              p_item             IN VARCHAR2,
                              p_item_revision_id NUMBER,
                              p_transqty         IN NUMBER,
                              p_org_id           IN NUMBER,
                              p_quantity         IN NUMBER,
                              p_location         IN VARCHAR2);

  PROCEDURE print_head_serial_pack(errbuf         OUT VARCHAR2,
                                   retcode        OUT VARCHAR2,
                                   p_stiker_name  IN VARCHAR2,
                                   p_printer_name IN VARCHAR2,
                                   p_item         IN VARCHAR2,
                                   p_serial       IN VARCHAR2,
                                   p_location     IN VARCHAR2);

  PROCEDURE print_head_serial_file(errbuf         OUT VARCHAR2,
                                   retcode        OUT VARCHAR2,
                                   p_printer_name IN VARCHAR2,
                                   p_item         IN VARCHAR2,
                                   p_location     IN VARCHAR2,
                                   p_file_name    IN VARCHAR2);
  --------------------------------------------------------------------------------
  -- Ver     When        Who           Description
  -- ------  ----------  ------------  -------------------------------------------
  -- 1.0     25/02/2019  Roman W.      CHG0045071
  --------------------------------------------------------------------------------
  PROCEDURE print_resin_pack_new(errbuf         OUT VARCHAR2,
                                 retcode        OUT VARCHAR2,
                                 p_stiker_name  IN VARCHAR2,
                                 p_printer_name IN VARCHAR2,
                                 p_bot_lot      IN VARCHAR2,
                                 p_org_id       IN NUMBER,
                                 p_quantity     IN NUMBER,
                                 p_location     IN VARCHAR2,
                                 p_pack_qty     IN NUMBER -- CHG0045071
                                 );

  ------------------------------------------------------------------------------------
  -- Ver     When          Who           Description
  -- ------  ------------  ------------  ---------------------------------------------
  -- 1.0     27/02/2019    Roman W.      CHG0045832
  --                                        Concurrent : XX:Print Small Sticker after Hamara
  --                                        Exequtable : XXWIPSTCKSMSMALLHAMARA
  --                                        Template   : Resin_Small
  ------------------------------------------------------------------------------------
  PROCEDURE print_resin_pack_small_hamara(errbuf         OUT VARCHAR2,
                                          retcode        OUT VARCHAR2,
                                          p_stiker_name  IN VARCHAR2,
                                          p_printer_name IN VARCHAR2,
                                          p_lot          IN VARCHAR2,
                                          p_comp_lot     IN VARCHAR2,
                                          p_org_id       IN NUMBER,
                                          p_quantity     IN NUMBER,
                                          p_location     IN VARCHAR2,
                                          p_job_fg       IN VARCHAR2 -- added CHG0044871
                                          );
  -------------------------------------------------------------------------------
  -- Ver      When         Who           Description
  -- -------  -----------  ------------  ----------------------------------------
  -- 1.0      27/02/2019   Roman W.      CHG0044871
  -- 1.1      27/02/2019   Roman W.      CHG0045832
  --                                        Concurrent : XX:Print bottling sticker after hamara
  --                                        Exequtable : XXWIPSTCKBTHAMARA
  --                                        Template   : Resin_Pack_Kg
  -------------------------------------------------------------------------------
  PROCEDURE print_resin_pack_hamara(errbuf         OUT VARCHAR2,
                                    retcode        OUT VARCHAR2,
                                    p_stiker_name  IN VARCHAR2,
                                    p_printer_name IN VARCHAR2,
                                    p_lot          IN VARCHAR2,
                                    p_comp_lot     IN VARCHAR2,
                                    p_org_id       IN NUMBER,
                                    p_quantity     IN NUMBER,
                                    p_location     IN VARCHAR2,
                                    --p_job_fg       IN VARCHAR2 -- added CHG0044871 -- rem by Roman W 12/06/2019 CHG0045832
                                    p_pack_qty IN NUMBER -- added by Roman W. 12/06/2019 CHG0045832
                                    );

  PROCEDURE print_rcv_pack_e(errbuf           OUT VARCHAR2,
                             retcode          OUT VARCHAR2,
                             p_stiker_name    IN VARCHAR2,
                             p_printer_name   IN VARCHAR2,
                             p_fm_receipt_num IN NUMBER,
                             p_to_receipt_num IN NUMBER,
                             p_org_id         IN NUMBER,
                             p_quantity       IN NUMBER,
                             p_location       IN VARCHAR2);

  PROCEDURE print_general_stiker(errbuf         OUT VARCHAR2,
                                 retcode        OUT VARCHAR2,
                                 p_stiker_name  IN VARCHAR2,
                                 p_printer_name IN VARCHAR2,
                                 p_location     IN VARCHAR2,
                                 p_copies       IN NUMBER,
                                 p_item_code    IN VARCHAR2,
                                 p_att1         IN VARCHAR2,
                                 p_att2         IN VARCHAR2,
                                 p_att3         IN VARCHAR2,
                                 p_att4         IN VARCHAR2,
                                 p_att5         IN VARCHAR2);

  PROCEDURE print_dangerous_mat_stiker(errbuf         OUT VARCHAR2,
                                       retcode        OUT VARCHAR2,
                                       p_stiker_name  IN VARCHAR2,
                                       p_printer_name IN VARCHAR2,
                                       p_location     IN VARCHAR2,
                                       -- p_delivery_id  IN VARCHAR2,  -- CHG0041294 -- on 14/02/2018 for delivery id to name change
                                       p_delivery_name IN VARCHAR2, -- CHG0041294 -- on 14/02/2018 for delivery id to name change
                                       p_copies        IN NUMBER);

  ----------------------------------------------------------------------------------------
  -- Ver    When          Who         Descr
  -- -----  ------------  ----------  ----------------------------------------------
  -- 1.0    13/01/2020    Roman W.    CHG0047181 - New Inkjet printer in Resin plant
  -- 1.1    17/09/2020    Roman W.    CHG0048593 - Print sticker -duplicate LOT causing to error
  ----------------------------------------------------------------------------------------
  PROCEDURE print_resin_pack_ink(errbuf         OUT VARCHAR2,
                                 retcode        OUT VARCHAR2,
                                 p_printer_name IN VARCHAR2,
                                 --p_job_name      IN VARCHAR2,
                                 p_bot_lot       IN VARCHAR2,
                                 p_org_id        IN NUMBER,
                                 p_component_lot IN VARCHAR2,
                                 --p_template      IN VARCHAR2, -- rem by Roman W. CHG0047181
                                 p_job_fg IN VARCHAR2 -- CHG0047181
                                 );

  ----------------------------------------------------------------------------------------------------
  -- Ver   When         Who             Descr
  -- ----  -----------  --------------  --------------------------------------------------------------
  -- 1.2   13/01/2020   Roman W.        CHG0047181 - New Inkjet printer in Resin plant
  ----------------------------------------------------------------------------------------------------
  PROCEDURE print_resin_pack_hamara_ink(errbuf         OUT VARCHAR2,
                                        retcode        OUT VARCHAR2,
                                        p_printer_name IN VARCHAR2,
                                        p_lot          IN VARCHAR2,
                                        p_comp_lot     IN VARCHAR2,
                                        p_org_id       IN NUMBER,
                                        -- p_template     VARCHAR2 --Rem by Roman W.
                                        p_job_fg IN VARCHAR2 -- CHG0047181
                                        );

  --------------------------------------------------------------------
  --  name:              print_inspection_release
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     29.08.13
  --------------------------------------------------------------------
  --  purpose :          cr981 Create WRI Inspection Release Sticker
  --------------------------------------------------------------------
  --  ver   date          name              desc
  --  1.0   29.08.13      yuval tal         initial Build
  --  1.1   28/09/2014    Dalit A. Raviv    CHG0032719 - add locator parameter
  --------------------------------------------------------------------
  PROCEDURE print_inspection_release(errbuf           OUT VARCHAR2,
                                     retcode          OUT VARCHAR2,
                                     p_stiker_name    IN VARCHAR2,
                                     p_printer_name   IN VARCHAR2,
                                     p_fm_receipt_num IN NUMBER,
                                     p_to_receipt_num IN NUMBER,
                                     p_org_id         IN NUMBER,
                                     p_quantity       IN NUMBER,
                                     p_item           IN VARCHAR2,
                                     p_location       IN VARCHAR2,
                                     p_plan_id        IN NUMBER,
                                     p_lot            IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            print_inspection_release_m_r
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/10/2013
  --------------------------------------------------------------------
  --  purpose :        REP354 - Receiving Stickers - CR1050
  --                   During the Receiving process in the System Plan in Rehovot,
  --                   after the material pass quality check, there is a need to
  --                   issue Inspection Release Sticker.
  --                   The sticker is printed by the QC worker after entering the
  --                   inspection data to the collection plan in Oracle
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/10/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE print_inspection_release_m_r(errbuf           OUT VARCHAR2,
                                         retcode          OUT VARCHAR2,
                                         p_stiker_name    IN VARCHAR2,
                                         p_printer_name   IN VARCHAR2,
                                         p_fm_receipt_num IN NUMBER,
                                         p_to_receipt_num IN NUMBER,
                                         --p_org_id         in number,
                                         p_quantity IN NUMBER,
                                         p_item     IN VARCHAR2,
                                         p_location IN VARCHAR2,
                                         p_plan_id  IN NUMBER);

  PROCEDURE print_subinventory_locator(errbuf            OUT VARCHAR2,
                                       retcode           OUT VARCHAR2,
                                       p_stiker_name     IN VARCHAR2,
                                       p_printer_name    IN VARCHAR2,
                                       p_location        IN VARCHAR2,
                                       p_copies          IN NUMBER,
                                       p_organization_id IN NUMBER,
                                       p_subinventory    IN VARCHAR2,
                                       p_locator_id      IN VARCHAR2
                                       
                                       );

  --------------------------------------------------------------------
  --  name:            print_ssys_rcv
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/11/2013
  --------------------------------------------------------------------
  --  purpose :

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25/11/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE print_ssys_rcv(errbuf         OUT VARCHAR2,
                           retcode        OUT VARCHAR2,
                           p_stikcer_name IN VARCHAR2,
                           p_printer_name IN VARCHAR2,
                           p_location     IN VARCHAR2,
                           p_copies       IN NUMBER,
                           p_rec_num      IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            print_auto_label_lot_bottling
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/01/2014
  --------------------------------------------------------------------
  --  purpose :        CR 1259  print_auto_label_lot_bottling
  --                   Build a new concurrent request that will print the sticker
  --                   through the new auto labeling machine.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/01/2014  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE print_auto_label_lot_bottling(errbuf            OUT VARCHAR2,
                                          retcode           OUT VARCHAR2,
                                          p_stikcer_name    IN VARCHAR2,
                                          p_printer_ip      IN VARCHAR2,
                                          p_botteling_lot   IN VARCHAR2,
                                          p_organization_id IN NUMBER);

  --------------------------------------------------------------------
  --  name:            print_ato_hasp_lbl
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   03.09.14

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05/11/2013  yuval tal         CHG0032574 Development ATO Hasp Label - initial build
  --------------------------------------------------------------------

  PROCEDURE print_ato_hasp_lbl(errbuf         OUT VARCHAR2,
                               retcode        OUT VARCHAR2,
                               p_stiker_name  IN VARCHAR2,
                               p_printer_name IN VARCHAR2,
                               p_location     IN VARCHAR2,
                               p_copies       IN NUMBER,
                               p_item_code    IN VARCHAR2,
                               p_job_number   IN VARCHAR2);

END xxinv_bartender_pkg;
/
