CREATE OR REPLACE PACKAGE ZX_AVALARA_TAX_SERVICE_PKG AUTHID CURRENT_USER as
--==========================================================================
-- Program Name         -       ZX_AVALARA_TAX_SERVICE_PKG
-- Source File          -       ZX_AVALARA_TAX_SERVICE_PKG.sql
-- Description          -       Procedures/Functions used for transmitting transaction information and
--                              getting tax amounts from Avalara Tax system
--===========================================================================
--      Modification History
--===========================================================================
-- Date         Version         Who           Description
--3-Oct-13      2               TT(OAC)      Invoice Num update on Auto Invoice
--29-Oct-13		3				TT(OAC)		 restrict customer code text to 50 chars 
--16-Dec-13		4				TT			 handle no lines in lines cursor (free clob)
--21-Dec-13		4				TT			 handle null line qty (default to 1 if null)
--14-Mar-14		7				TT			 handle for contracts, set DFF value to N
--===========================================================================

   G_MESSAGES_TBL          ZX_TAX_PARTNER_PKG.messages_tbl_type;
   err_count       number :=0;

PROCEDURE CALCULATE_TAX_API
       (p_currency_tab        IN OUT NOCOPY ZX_TAX_PARTNER_PKG.tax_currencies_tbl_type,
  x_tax_lines_tbl          OUT NOCOPY ZX_TAX_PARTNER_PKG.tax_lines_tbl_type,
  x_error_status           OUT NOCOPY VARCHAR2,
  x_messages_tbl           OUT NOCOPY ZX_TAX_PARTNER_PKG.messages_tbl_type);

--============================
-- test avalara connection
PROCEDURE TEST_CONNECTION ( errbuf    OUT NOCOPY   VARCHAR2,
                                retcode OUT NOCOPY   VARCHAR2 );
---============================
-- Address validation
PROCEDURE ADDRESS_VALIDATION (   p_addrval_doc IN OUT NOCOPY NCLOB,
                                 p_loc_id IN NUMBER,
                                 x_return_status OUT NOCOPY VARCHAR2
                             );
--===============================
-- Auto Invoice resubmit with Invoice Num
PROCEDURE AUTO_INV_RESUB_INVNUM ( errbuf    OUT NOCOPY   VARCHAR2,
                                retcode OUT NOCOPY   VARCHAR2 );
---============================
END ZX_AVALARA_TAX_SERVICE_PKG;
/
show err
