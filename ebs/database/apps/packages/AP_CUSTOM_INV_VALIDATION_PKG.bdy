create or replace PACKAGE BODY AP_CUSTOM_INV_VALIDATION_PKG AS
/*$Header: apcsvalb.pls 120.0.12000000.1 2009/02/10 09:53:13 subehera noship $*/

  -- Logging Infra
  G_CURRENT_RUNTIME_LEVEL       NUMBER := FND_LOG.G_CURRENT_RUNTIME_LEVEL;
  G_LEVEL_UNEXPECTED   CONSTANT NUMBER := FND_LOG.LEVEL_UNEXPECTED;
  G_LEVEL_ERROR        CONSTANT NUMBER := FND_LOG.LEVEL_ERROR;
  G_LEVEL_EXCEPTION    CONSTANT NUMBER := FND_LOG.LEVEL_EXCEPTION;
  G_LEVEL_UNEXPECTED   CONSTANT NUMBER := FND_LOG.LEVEL_UNEXPECTED;
  G_LEVEL_EVENT        CONSTANT NUMBER := FND_LOG.LEVEL_EVENT;
  G_LEVEL_PROCEDURE    CONSTANT NUMBER := FND_LOG.LEVEL_PROCEDURE;
  G_LEVEL_STATEMENT    CONSTANT NUMBER := FND_LOG.LEVEL_STATEMENT;
  G_MODULE_NAME        CONSTANT VARCHAR2(50) := 'AP.PLSQL.AP_CUSTOM_INV_VALIDATION_PKG.';
  G_LEVEL_LOG_DISABLED CONSTANT NUMBER := 99;
  --1-STATEMENT, 2-PROCEDURE, 3-EVENT, 4-EXCEPTION, 5-ERROR, 6-UNEXPECTED


PROCEDURE AP_Custom_Validation_Hook(
   P_Invoice_ID                     IN   NUMBER,
   P_Calling_Sequence               IN   VARCHAR2) IS

  l_curr_calling_sequence       VARCHAR2(2000);
  l_debug_info                  VARCHAR2(1000);
  l_debug_loc                   VARCHAR2(30);
  l_log_msg                     FND_LOG_MESSAGES.MESSAGE_TEXT%TYPE;

BEGIN

  -- Update the calling sequence --

  l_debug_loc := 'AP_Custom_Validation_Hook';
  l_curr_calling_sequence := 'AP_CUSTOM_INV_VALIDATION_PKG.'||
                             l_debug_loc||'<-'||
                             p_calling_sequence;

  IF (G_LEVEL_PROCEDURE >= G_CURRENT_RUNTIME_LEVEL  ) THEN
      l_log_msg := 'Begin of procedure '|| l_debug_loc;
      FND_LOG.STRING(G_LEVEL_PROCEDURE, G_MODULE_NAME||
                     l_debug_loc, l_log_msg);
  END IF;

 -- Added Call to Package which will check if Invoice is eligible for hold. If the Invoice is eligible then a hold is applied 
 -- Added 13-OCT-2015 SAkula CHG0036487
  XXAP_HOLDS_PKG.validate_invoice
            (p_invoice_id  => p_invoice_id,
             p_user_id     => FND_GLOBAL.USER_ID 
            );
  
  
  IF (G_LEVEL_PROCEDURE >= G_CURRENT_RUNTIME_LEVEL  ) THEN
      l_log_msg := 'End of procedure '|| l_debug_loc;
      FND_LOG.STRING(G_LEVEL_PROCEDURE, G_MODULE_NAME||
                     l_debug_loc, l_log_msg);
  END IF;

EXCEPTION

  WHEN OTHERS THEN
    IF (SQLCODE <> -20001) THEN
      FND_MESSAGE.SET_NAME('SQLAP','AP_DEBUG');
      FND_MESSAGE.SET_TOKEN('ERROR',SQLERRM);
      FND_MESSAGE.SET_TOKEN('CALLING_SEQUENCE', l_curr_calling_sequence);
      FND_MESSAGE.SET_TOKEN('PARAMETERS',
                  'Invoice_id  = '|| to_char(p_invoice_id));
    END IF;
    APP_EXCEPTION.RAISE_EXCEPTION;

END AP_Custom_Validation_Hook;

END AP_CUSTOM_INV_VALIDATION_PKG;
/

