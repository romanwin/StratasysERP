CREATE OR REPLACE PACKAGE XXPUR_ONHAND_REP_PKG is

  Procedure PRINT_CERTIFICATES(errbuf            out varchar2,
                               retcode           out number,
                               p_organization_id in number,
                               --p_delivery_id     in number -- CHG0041294 on 15/02/2018 for delivery id to name change
                               p_delivery_name   in varchar2 -- CHG0041294 on 15/02/2018 for delivery id to name change
                               --p_item_id         in number
                               );

End XXPUR_ONHAND_REP_PKG;
/