CREATE OR REPLACE PACKAGE "XXAR_RECEIPT_BATCHES_TO_MASAV" is

  -- Author  : ROMAN.WINER
  -- Created : 2021-06-22 3:58:09 PM
  -- Purpose : CHG0032650 - MASAV collection process

  C_DIRECTORY CONSTANT VARCHAR2(120) := 'XXAR_BATCHES_TO_MASAV';
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   22/06/2021  Roman W.      CHG0032650 - MASAV collection process
  --------------------------------------------------------------------------
  procedure message(p_msg in varchar2);

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   22/06/2021  Roman W.      CHG0032650 - MASAV collection process
  --------------------------------------------------------------------------
  procedure main(errbuf      OUT VARCHAR2,
                 retcode     OUT VARCHAR2,
                 p_batch_id  IN VARCHAR2, -- 385388
                 p_file_path IN VARCHAR2,
                 p_file_name IN VARCHAR2);

end XXAR_RECEIPT_BATCHES_TO_MASAV;
/
