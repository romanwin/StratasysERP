create or replace
PACKAGE  XX_ADMIN_UTILITIES_PKG AS
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
--

-- +===================================================================+
-- |                                                                   |
-- |Procedure Name     : XX_ADMIN_SEQ_PROC                             |
-- |                                                                   |
-- |Description      : This procedure is used to reset the cache to (input parameter)
-- |                    of a sequence 
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
PROCEDURE XX_ADMIN_SEQ_PROC ( P_SEQ_NAME IN ALL_SEQUENCES.SEQUENCE_NAME%type,
                                p_cache    IN NUMBER DEFAULT 20,
                                p_manual   IN varchar2 default 'N'
                            );

-- +===================================================================+
-- |                                                                   |
-- |Procedure Name     : XX_CUST_EVENT_RAISE                           |
-- |                                                                   |
-- |Description      : This generic  procedure is used to raise WF for custom events
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
PROCEDURE XX_CUST_EVENT_RAISE (
                            P_EVENT_NAME      IN VARCHAR2,
                            P_EVENT_KEY       IN VARCHAR2,
                            P_PARAMETER_1     IN VARCHAR2,
                            P_PARAMETER_1_VAL IN VARCHAR2,
                            P_PARAMETER_2     IN VARCHAR2,
                            P_PARAMETER_2_VAL IN VARCHAR2,
                            P_PARAMETER_3    IN VARCHAR2,
                            P_PARAMETER_3_VAL IN VARCHAR2
);
END XX_ADMIN_UTILITIES_PKG;
/