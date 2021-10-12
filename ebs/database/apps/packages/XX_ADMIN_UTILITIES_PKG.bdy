create or replace
PACKAGE BODY   XX_ADMIN_UTILITIES_PKG 
-- +===================================================================+
-- |                         Stratesys                                 |
-- |                                                                   |
-- +===================================================================+
-- |                                                                   |
-- |Package Name     : XXCSI_ADMIN_UTILITIES_PKG                    |
-- |                                                                   |
-- |Description      : This Package is used for the Adhoc admin Utilities like 
-- |                   reseting Cache and raising custom events
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |1.0   12-08-2016   Vishal Roy(TCS)       Initial code version      |
-- |                                                                   |
-- |                                                                   |
-- +===================================================================+

AS
  --
  --
  PROCEDURE XX_ADMIN_SEQ_PROC ( P_SEQ_NAME IN ALL_SEQUENCES.SEQUENCE_NAME%type,
                                p_cache    IN NUMBER DEFAULT 20,
                                p_manual   IN varchar2 default 'N'
                            ) IS
 -- +===================================================================+
-- |                                                                   |
-- |Procedure Name     : XX_ADMIN_SEQ_PROC                             |
-- |                                                                   |
-- |Description      : This procedure is used to reset the cache to 
-- |                  (input parameter)  of a sequence using the master table
-- |                  xx_admin_seq. If we need to provide Data manually
-- |                  it can be provided by Parameter
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |1.0   12-08-2016   Vishal Roy(TCS)       Initial code version      |
-- |                                                                   |
-- |                                                                   |
-- +===================================================================+
  l_sql VARCHAR2(200);
  --
  --
  BEGIN
    --
    IF p_manual ='Y' THEN
    /* If we are Passing  Sequence Name Manually*/
      l_sql :='ALTER SEQUENCE '||P_SEQ_NAME||' CACHE '||p_cache;
      execute immediate l_sql ;
      commit;
    END IF;--p_manual ='Y' For Mnaual Value
  --
  EXCEPTION WHEN others 
  THEN
    dbms_output.put_line (' Error Found for :'||P_SEQ_NAME||' : With Erro Msg :'|| SQLERRM);
  END XX_ADMIN_SEQ_PROC;
--
--
-- +===================================================================+
-- |                                                                   |
-- |Procedure Name     : XX_CUST_EVENT_RAISE                           |
-- |                                                                   |
-- |Description      : This generic  procedure is used to raise WF for 
-- |  				custom events                                                                 |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |1.0   12-08-2016   Vishal Roy(TCS)       Initial code version      |
-- |                                                                   |
-- |                                                                   |
-- +===================================================================+
PROCEDURE XX_CUST_EVENT_RAISE (
                            P_EVENT_NAME      IN VARCHAR2,
                            P_EVENT_KEY       IN VARCHAR2,
                            P_PARAMETER_1     IN VARCHAR2,
                            P_PARAMETER_1_VAL IN VARCHAR2,
                            P_PARAMETER_2     IN VARCHAR2,
                            P_PARAMETER_2_VAL IN VARCHAR2,
                            P_PARAMETER_3     IN VARCHAR2,
                            P_PARAMETER_3_VAL IN VARCHAR2
)IS
  x_event_parameter_list 		wf_parameter_list_t;
  x_param                   wf_parameter_t;
  x_event_name             	VARCHAR2(300) := P_EVENT_NAME;
  x_event_key              	VARCHAR2(300) := P_EVENT_KEY;
  x_parameter_index       	NUMBER := 0;
BEGIN
  x_event_parameter_list := wf_parameter_list_t();
  --
  --Adding First value to first Event Name
  --
  x_param := wf_parameter_t(NULL,NULL);
  x_event_parameter_list.EXTEND;
  x_param.setname(P_PARAMETER_1);
  x_param.setvalue(P_PARAMETER_1_VAL);
  x_parameter_index := x_parameter_index + 1;
  x_event_parameter_list(x_parameter_index) := x_param;
  --
  --Adding second value to second Event Name
  --
  x_param := wf_parameter_t(NULL,NULL);
  x_event_parameter_list.EXTEND;
  x_param.setname(P_PARAMETER_2);
  x_param.setvalue(P_PARAMETER_2_VAL);
  x_parameter_index := x_parameter_index + 1;
  x_event_parameter_list(x_parameter_index) := x_param;
  --
  --Adding third value to third Event Name
  --
  x_param := wf_parameter_t(NULL,NULL);
  x_event_parameter_list.EXTEND;
  x_param.setname(P_PARAMETER_3);
  x_param.setvalue(P_PARAMETER_3_VAL);
  x_parameter_index := x_parameter_index + 1;
  x_event_parameter_list(x_parameter_index) := x_param;
  --
  -- Raising Standard Workflow Agent 
  --
  wf_event.RAISE(p_event_name => x_event_name
                ,p_event_key  => x_event_key
                ,p_parameters => x_event_parameter_list
             /*,p_event_data   =>  p_data*/
  --
                );
END XX_CUST_EVENT_RAISE;
--
--
END XX_ADMIN_UTILITIES_PKG;
/