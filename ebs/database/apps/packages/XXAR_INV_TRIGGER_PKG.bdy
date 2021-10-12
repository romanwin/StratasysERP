CREATE OR REPLACE PACKAGE BODY XXAR_INV_TRIGGER_PKG IS

 -- =============================================================================
  -- Copyright (C) 2013  TCS, India
  -- All rights Reserved
  -- Program Name: XXAR_INV_TRIGGER_PKG
  -- Parameters  : None
  -- Description : Package contains the procedures required for SSYS to raise
  --                Business Event
  --
  --
  -- Notes       : None
  -- History     :
  -- Creation Date : 02-SEP-2016
  -- Created/Updated By  : TCS
  -- Version: 1.0
 -- ============================================================================

  -- ------------------------------------------------------------------------
  --  purpose :  Legacy business event raise package for AR Invoice Creation
  -- -----------------------------------------------------------------------
  --  ver  date            name             desc
  --  1.0  02-SEP-2016     TCS         Initial Build
  -- ---------------------------------------------------------------------
  --  name:              trigger_prc
  --  create by:          TCS
  --  Revision:          1.0
  --  creation date:    02-SEP-2016
  --------------------------------------------------------------------

  PROCEDURE trigger_prc(p_customer_trx_id IN NUMBER) AS
    l_list         wf_parameter_list_t;
    l_param        wf_parameter_t;
    l_key          VARCHAR2(240);
    l_exist        VARCHAR2(1);
    l_event_name   VARCHAR2(240) := 'xxar.oracle.apps.ar.transaction.complete';
    l_error_message   VARCHAR2(1000) := NULL;

  BEGIN


    IF fnd_profile.VALUE('HZ_EXECUTE_API_CALLOUTS') = 'Y' THEN


          --Get the item key
      l_key := hz_event_pkg.item_key(l_event_name);


      -- Add Business event parameters
      wf_event.addparametertolist(p_name => 'CUSTOMER_TRX_ID', p_value => p_customer_trx_id, p_parameterlist => l_list);


     IF p_customer_trx_id IS NOT NULL THEN

        -- Raise the business event
        wf_event.RAISE(p_event_name => l_event_name, p_event_key => l_key, p_parameters => l_list);


      END IF;

    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := 'Unexpected error has occured IN XXAR_INV_TRIGGER_PKG package'
                            || SQLERRM;
  END trigger_prc;

END XXAR_INV_TRIGGER_PKG;
/