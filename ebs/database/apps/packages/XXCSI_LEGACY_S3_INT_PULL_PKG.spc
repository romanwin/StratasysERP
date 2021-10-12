create or replace
PACKAGE xxcsi_LEGACY_S3_int_pull_pkg 
-- +===================================================================+
-- |                         Stratesys                                 |
-- |                                                                   |
-- +===================================================================+
-- |                                                                   |
-- |Package Name     : XXCSI_LEGACY_S3_INT_PULL_PKG                    |
-- |                                                                   |
-- |Description      : This Package is used to create instance and     |
-- |                    relationship rlating to  the same to master instance              |
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |Draft1A   12-08-2016   Vishal Roy       Initial code version       |
-- |         |
-- |                                                                   |
-- +===================================================================+
IS
-- +===================================================================+
-- |                                                                   |
-- |Procedure Name     : pull_INSTANCE                         	       |
-- |                                                                   |
-- |Description      : This procedure is used to create instance  
-- |                   by pulling records from view created in S3      |
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |Draft1A   12-08-2016   Vishal Roy       Initial code version       |
-- |         														   |	
-- |                                                                   |
-- +===================================================================+
  PROCEDURE pull_INSTANCE(p_errbuf     	 OUT VARCHAR2,
							p_retcode    OUT NUMBER,
							p_batch_size IN NUMBER,
							p_debug in VARCHAR2);
  --
  --
-- +===================================================================+
-- |                                                                   |
-- |Procedure Name     : PULL_RELATIONSHIP                         	   |
-- |                                                                   |
-- |Description      : This procedure is used to create any missed out  
-- |                   relationship by pulling data from S3 and xref
-- |			       table										   |
-- |                                                                   |
-- |                                                                   |
-- |Change Record:                                                     |
-- |===============                                                    |
-- |Version   Date         Author           Remarks                    |
-- |=======   ==========  =============    ============================|
-- |Draft1A   12-08-2016   Vishal Roy       Initial code version       |
-- |         														   |	
-- |                                                                   |
-- +===================================================================+
  PROCEDURE PULL_RELATIONSHIP(P_ERRBUF      OUT VARCHAR2,
                               P_RETCODE    OUT NUMBER,
                               P_BATCH_SIZE IN NUMBER,
                               p_debug in VARCHAR2
                               );
END xxcsi_LEGACY_S3_int_pull_pkg;
/