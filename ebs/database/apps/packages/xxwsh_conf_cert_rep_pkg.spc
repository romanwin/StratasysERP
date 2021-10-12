create or replace package XXWSH_CONF_CERT_REP_PKG is

  Procedure PRINT_CERTIFICATES(errbuf            out varchar2,
                               retcode           out number,
                               p_organization_id in number,
                               p_delivery_id     in number
                               --p_item_id         in number
                               );

End XXWSH_CONF_CERT_REP_PKG;
/

