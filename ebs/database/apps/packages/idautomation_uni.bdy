CREATE OR REPLACE PACKAGE BODY idautomation_uni

--===============================================================
--? Copyright, 2007 IDAutomation.com, Inc. All rights reserved.
--Redistribution and use of this code in source and/or binary
--forms, with or without modification, are permitted provided
--that: (1) all copies of the source code retain the above
--unmodified copyright notice and this entire unmodified
--section of text, (2) You or Your organization owns a valid
--Developer License to this product from IDAutomation.com
--and, (3) when any portion of this code is bundled in any
--form with an application, a valid notice must be provided
--within the user documentation, start-up screen or in the
--help-about section of the application that specifies
--IDAutomation.com as the provider of the Software bundled
--with the application.
--===============================================================

--==============================================================
-- Code128
-- Interleaved 2 of 5
-- Code128A
-- Code128B
-- Code128C
-- Code39
-- Codabar
-- POSTNET
-- PLANET

--Updated: 9-2007
--==============================================================

--*********************************************************************
--
--  For a package description see the package specification.
--
--*********************************************************************
 IS

  -----------------------------------------------------------------------
  -- Global type declarations
  -----------------------------------------------------------------------

  TYPE set128_at IS TABLE OF VARCHAR2(3); --INDEX BY BINARY_INTEGER
  TYPE set_itf_at IS TABLE OF VARCHAR2(5); --INDEX BY BINARY_INTEGER
  TYPE set_c39_at IS TABLE OF VARCHAR2(10); --INDEX BY BINARY_INTEGER
  TYPE set_cod_at IS TABLE OF VARCHAR2(8); --INDEX BY BINARY_INTEGER
  TYPE setwrkstr_at IS TABLE OF VARCHAR2(10); --INDEX BY BINARY_INTEGER
  TYPE set_postnet_at IS TABLE OF VARCHAR2(3); --INDEX BY BINARY_INTEGER
  TYPE set_planet_at IS TABLE OF VARCHAR2(3); --INDEX BY BINARY_INTEGER
  TYPE dual IS TABLE OF VARCHAR2(3);
  -----------------------------------------------------------------------
  -- Global variable/constant declarations
  -----------------------------------------------------------------------

  --NVARCHAR2
  v_symbol_string     NVARCHAR2(4000) := '';
  v_yy                NVARCHAR2(4) := unistr('\0020'); --32
  v_yx                NVARCHAR2(4) := unistr('\2590'); --9616
  v_xy                NVARCHAR2(4) := unistr('\258C'); --9612
  v_xx                NVARCHAR2(4) := unistr('\2588'); --9608
  v_lf                NVARCHAR2(4) := chr(10);
  v_cr                NVARCHAR2(4) := chr(13);
  v_printable_string  NVARCHAR2(4000) := '';
  v_printable_stringd NVARCHAR2(4000) := '';
  v_printable_string2 NVARCHAR2(4000) := '';
  v_return            NVARCHAR2(4000);

  --NUMBERS AND PLS_INTEGER
  v_factor          NUMBER := 3;
  v_i               PLS_INTEGER;
  v_j               PLS_INTEGER;
  v_g               PLS_INTEGER;
  v_length          PLS_INTEGER;
  v_next_digit_used PLS_INTEGER;

  --VARCHAR2
  v_current_char_num  VARCHAR2(3);
  v_current_chr_value VARCHAR2(10);

  --BOOLEAN
  boolean_continue BOOLEAN := FALSE;
  v_demo           BOOLEAN := FALSE; -----------------------------------DEMO
  v_random         NUMBER(1) := 0;

  -----------------------------------------------------------------------
  -- LOCAL procedures/functions
  -----------------------------------------------------------------------

  -----------------------------------------------------------------------
  -- PUBLIC procedures/functions
  -----------------------------------------------------------------------

  -----------------------------------------------------------------------
  --                           Codabar Symbology                       --
  -----------------------------------------------------------------------

  FUNCTION codabar(p_string     IN VARCHAR2,
                   codabarstart IN VARCHAR2,
                   codabarstop  IN VARCHAR2,
                   n_dimension  IN NUMBER) RETURN VARCHAR2
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL implementation bases on the
    --      example code Codabar
    --
    --==============================================================
   IS
    --  v_pos      SGUI_RPT_EXCEPTION.POSITION_T;
  
    --NVARCHAR2
    v_printable_string      NVARCHAR2(6000) := '';
    v_printable_string2     NVARCHAR2(6000) := '';
    v_only_correct_data     NVARCHAR2(6000) := ''; --filtered data after removal
    v_full_data_to_encode   NVARCHAR2(6000) := '';
    v_actual_data_to_encode NVARCHAR2(6000) := '';
    v_local_stop_char       NVARCHAR2(4) := '';
    v_local_start_char      NVARCHAR2(4) := '';
  
    --VARCHAR2
    v_current_char_num VARCHAR2(2);
    v_nwpatterncod     VARCHAR2(2000) := '';
    v_current_value    VARCHAR2(2);
    v_return           VARCHAR2(6000) := '';
    v_two_chars        VARCHAR2(2);
  
    --NUMBER AND PLS_INTEGER
    v_i                PLS_INTEGER := 1;
    v_j                PLS_INTEGER := 1;
    v_length           PLS_INTEGER;
    v_weighted_total   NUMBER := 0;
    v_localn_dimension NUMBER := 2;
    v_local_ndimension PLS_INTEGER := 2;
  
    v_set_cod set_cod_at;
  
  BEGIN
  
    v_full_data_to_encode := p_string;
  
    --Numbers 0 - 9 and 10 = "-", 11="$", 12 = ":", 13="/", 14= ".", 15="+", 16="A", 17="C", 18 = "D"
  
    v_set_cod := set_cod_at('nnnnnwwn',
                            'nnnnwwnn',
                            'nnnwnnwn',
                            'wwnnnnnn',
                            'nnwnnwnn',
                            'wnnnnwnn',
                            'nwnnnnwn',
                            'nwnnwnnn',
                            'nwwnnnnn',
                            'wnnwnnnn',
                            'nnnwwnnn',
                            'nnwwnnnn',
                            'wnnnwnwn',
                            'wnwnnnwn',
                            'wnwnwnnn',
                            'nnwnwnwn',
                            'nnwwnwnn',
                            'nwnwnnwn',
                            'nnnwnwwn',
                            'nnnwwwnn');
  
    IF (n_dimension = 3 OR n_dimension = 2) THEN
      v_localn_dimension := n_dimension;
    ELSE
      v_localn_dimension := 2;
    END IF;
  
    ------------------------START----------------
    IF (codabarstart = 'A' OR codabarstart = 'B' OR codabarstart = 'C' OR
       codabarstart = 'D') THEN
      v_local_start_char := codabarstart;
    ELSE
      v_local_start_char := 'A';
    END IF;
    -------------------------STOP----------------
    IF (codabarstop = 'A' OR codabarstop = 'B' OR codabarstop = 'C' OR
       codabarstop = 'D') THEN
      v_local_stop_char := codabarstop;
    ELSE
      v_local_stop_char := 'A';
    END IF;
  
    v_length := length(v_full_data_to_encode);
    v_i      := 0;
  
    v_actual_data_to_encode := v_local_start_char || v_full_data_to_encode ||
                               v_local_stop_char;
    v_length                := length(v_actual_data_to_encode);
    v_weighted_total        := 0;
    v_current_value         := 0;
  
    v_i      := 0;
    v_length := length(v_actual_data_to_encode);
    FOR v_i IN 1 .. v_length LOOP
      v_current_char_num := (ascii(substr(v_actual_data_to_encode, v_i, 1)));
      -- v_current_value := 99;
    
      IF (v_current_char_num < 58 AND v_current_char_num > 47)
      --numbers 0-9
       THEN
        v_current_value := v_current_char_num - 48;
      
      ELSIF (v_current_char_num = 45) THEN
        v_current_value := 10;
      
      ELSIF (v_current_char_num = 36) THEN
        v_current_value := 11;
      
      ELSIF (v_current_char_num = 58) THEN
        v_current_value := 12;
      
      ELSIF (v_current_char_num = 47) THEN
        v_current_value := 13;
      
      ELSIF (v_current_char_num = 46) THEN
        v_current_value := 14;
      
      ELSIF (v_current_char_num = 43) THEN
        v_current_value := 15;
      
      ELSIF (v_current_char_num = 65 OR v_current_char_num = 97) THEN
        v_current_value := 16;
      
      ELSIF (v_current_char_num = 66 OR v_current_char_num = 98) THEN
        v_current_value := 17;
      
      ELSIF (v_current_char_num = 67 OR v_current_char_num = 99) THEN
        v_current_value := 18;
      
      ELSIF (v_current_char_num = 68 OR v_current_char_num = 100) THEN
        v_current_value := 19;
      END IF;
    
      --get the narrow/wide pattern for codabar
      IF (v_current_value != 99) THEN
        v_nwpatterncod := v_set_cod(v_current_value + 1);
      END IF;
    
      IF (v_localn_dimension = 3 AND v_current_value != 99)
      
       THEN
        v_j := 1;
      
        WHILE v_j < 8 LOOP
          v_two_chars := '';
          v_two_chars := (substr(v_nwpatterncod, v_j, 2));
          IF v_two_chars = 'nn' THEN
            v_printable_string := v_printable_string || 'A';
          ELSIF v_two_chars = 'nw' THEN
            v_printable_string := v_printable_string || 'C';
          ELSIF v_two_chars = 'wn' THEN
            v_printable_string := v_printable_string || 'I';
          ELSIF v_two_chars = 'ww' THEN
            v_printable_string := v_printable_string || 'K';
          END IF;
        
          v_j := v_j + 2;
        END LOOP;
      
      ELSIF (v_localn_dimension = 2 AND v_current_value != 99)
      
       THEN
        v_j := 1;
      
        WHILE v_j < 8 LOOP
          v_two_chars := '';
          v_two_chars := (substr(v_nwpatterncod, v_j, 2));
          IF v_two_chars = 'nn' THEN
            v_printable_string := v_printable_string || 'A';
          ELSIF v_two_chars = 'nw' THEN
            v_printable_string := v_printable_string || 'B';
          ELSIF v_two_chars = 'wn' THEN
            v_printable_string := v_printable_string || 'E';
          ELSIF v_two_chars = 'ww' THEN
            v_printable_string := v_printable_string || 'F';
          END IF;
          v_j := v_j + 2;
        END LOOP;
      
      END IF;
    END LOOP;
  
    v_printable_string2 := v_printable_string;
    v_return            := v_printable_string2;
    RETURN(v_return);
  
  END codabar;

  -----------------------------------------------------------------------
  --                  Interleaved 2of5 Symbology                       --
  -----------------------------------------------------------------------
  ---------------------------
  FUNCTION i2of5(p_number            IN VARCHAR2,
                 include_check_digit IN BOOLEAN,
                 n_dimension         IN NUMBER) RETURN VARCHAR2
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL implementation bases on the
    --      example code provided at http://www.azalea.com/code/i2of5.txt
    --
    --==============================================================
   IS
    --  v_pos      SGUI_RPT_EXCEPTION.POSITION_T;
  
    --VARCHAR2
    v_current_char_num   VARCHAR2(2);
    v_current_encoding   VARCHAR2(2);
    v_char1              VARCHAR2(5);
    v_char2              VARCHAR2(5);
    v_v_current_encoding VARCHAR2(5);
    v_correct_data       VARCHAR2(1024) := '';
    v_wrkstr             VARCHAR2(1024);
    v_retval             VARCHAR2(1024) := '';
  
    --NUMBER OR PLS_INTEGER
    v_localn_dimension  NUMBER := 2;
    v_check_digit_value NUMBER(3) := 0;
    v_icd               NUMBER := 0;
    v_factor            NUMBER := 3;
    v_weighted_total    NUMBER := 0;
    v_i                 PLS_INTEGER := 1;
    v_length            PLS_INTEGER;
  
    --BOOLEAN
    v_lcl_use_check_digit BOOLEAN;
  
    v_set_itf_a set_itf_at;
  
  BEGIN
  
    IF (n_dimension = 3 OR n_dimension = 2) THEN
      v_localn_dimension := n_dimension;
    ELSE
      v_localn_dimension := 2;
    END IF;
  
    v_lcl_use_check_digit := include_check_digit;
  
    v_set_itf_a := set_itf_at('nnwwn',
                              'wnnnw',
                              'nwnnw',
                              'wwnnn',
                              'nnwnw',
                              'wnwnn',
                              'nwwnn',
                              'nnnww',
                              'wnnwn',
                              'nwnwn');
  
    -----------------------------------------------------------------
    -- v_pos := 'checking the input string and the data in it an take only
    --correct one';
    -----------------------------------------------------------------
    FOR v_ii IN 1 .. length(p_number) LOOP
      IF is_number(substr(p_number, v_ii, 1)) = 0 THEN
        v_correct_data := v_correct_data || substr(p_number, v_ii, 1);
      
      END IF;
    END LOOP;
  
    ------------------------------------------------------------
    -- adds odd numbers and multiplies by 3, adds even numbers
  
    -------------------------------------------------------------
    FOR v_ii IN 1 .. length(v_correct_data) LOOP
      v_current_char_num := to_number(substr(v_correct_data, v_ii, 1));
      v_weighted_total   := v_weighted_total +
                            (v_current_char_num * v_factor);
      v_factor           := 4 - v_factor;
    END LOOP;
  
    ----------------------------------------------------------------
    -- v_pos := 'find the check digit by finding the smallest number that = a
    --multiple of 10
  
    ------------------------------------------------------------------
    --BRJ 8/8/2007
    v_icd := MOD(v_weighted_total, 10);
    IF (v_icd != 0) THEN
      v_check_digit_value := 10 - v_icd;
    ELSE
      v_check_digit_value := 0;
    END IF;
  
    -- Add check digit to Only correct data, if the user wants the check digit
    IF (v_lcl_use_check_digit) THEN
      v_correct_data := v_correct_data || v_check_digit_value;
    END IF;
  
    v_wrkstr := v_correct_data;
  
    -----------------------------------------------------------------
    -- v_pos := 'checking if barcode have even number of digits';
    -----------------------------------------------------------------
    IF MOD(length(v_wrkstr), 2) = 1 THEN
      v_wrkstr := '0' || v_wrkstr;
    END IF;
  
    -----------------------------------------------------------------
    --  v_pos := 'converting each digit pair to the corresponding value';
    -----------------------------------------------------------------
    v_length := length(v_wrkstr);
    WHILE v_i <= v_length LOOP
      v_char1            := v_set_itf_a(ascii(substr(v_wrkstr, v_i, 1)) - 47);
      v_char2            := v_set_itf_a(ascii(substr(v_wrkstr, v_i + 1, 1)) - 47);
      v_current_encoding := '';
    
      IF (v_localn_dimension = 2) THEN
      
        FOR v_iii IN 1 .. 5 LOOP
          v_current_encoding := substr(v_char1, v_iii, 1) ||
                                substr(v_char2, v_iii, 1);
          IF v_current_encoding = 'nn' THEN
            v_retval := v_retval || 'A';
          ELSIF v_current_encoding = 'nw' THEN
            v_retval := v_retval || 'B';
          ELSIF v_current_encoding = 'wn' THEN
            v_retval := v_retval || 'E';
          ELSIF v_current_encoding = 'ww' THEN
            v_retval := v_retval || 'F';
          END IF;
        END LOOP;
        v_i := v_i + 2;
      
      ELSIF (v_localn_dimension = 3) THEN
      
        FOR v_iii IN 1 .. 5 LOOP
          v_current_encoding := substr(v_char1, v_iii, 1) ||
                                substr(v_char2, v_iii, 1);
          IF v_current_encoding = 'nn' THEN
            v_retval := v_retval || 'A';
          ELSIF v_current_encoding = 'nw' THEN
            v_retval := v_retval || 'C';
          ELSIF v_current_encoding = 'wn' THEN
            v_retval := v_retval || 'I';
          ELSIF v_current_encoding = 'ww' THEN
            v_retval := v_retval || 'K';
          END IF;
        END LOOP;
        v_i := v_i + 2;
      
      END IF;
    END LOOP;
  
    IF (v_localn_dimension = 3) THEN
      v_printable_string2 := ('AA' || v_retval || 'EA');
    ELSIF (v_localn_dimension = 2) THEN
      v_printable_string2 := ('AA' || v_retval || 'IA');
    END IF;
  
    v_return := v_printable_string2;
  
    ---------------------------------------------------------------------
    --  v_pos := 'add start and stop character';
    ---------------------------------------------------------------------
  
    RETURN(v_return);
  
  END i2of5;

  ------------------------------------------------------------------------
  --                     POSTNET                                        --
  ------------------------------------------------------------------------
  FUNCTION postnet(p_string IN VARCHAR2, include_check_digit IN BOOLEAN)
    RETURN VARCHAR2
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL implementation bases on the
    --      example code Postnet
    --
    --==============================================================
   IS
    --  v_pos      SGUI_RPT_EXCEPTION.POSITION_T;
  
    v_wrkstr VARCHAR2(6000);
    --p_string VARCHAR2 (1024);
    v_return           VARCHAR2(6000) := '';
    v_set_postnet      set_postnet_at;
    v_weighted_total   NUMBER := 0;
    v_current_char_num VARCHAR2(2);
    v_i                PLS_INTEGER := 1;
    v_g                PLS_INTEGER := 1;
  
    v_length              PLS_INTEGER;
    v_factor              NUMBER := 3;
    v_lcl_use_check_digit BOOLEAN;
    v_ip_use_cd           BOOLEAN; --(1) :='';
    v_printable_string    NVARCHAR2(32000) := '';
    v_only_correct_data   NVARCHAR2(32000) := ''; --filtered data after removal
  
    v_full_data_to_encode NVARCHAR2(32000) := '';
    v_nwpatternpn         VARCHAR2(2000) := '';
    v_current_value       VARCHAR2(2);
    v_check_digit         NUMBER(3) := 0;
    v_cd                  NUMBER(3) := 0;
  
  BEGIN
  
    v_ip_use_cd := include_check_digit;
  
    IF (p_string = NULL) THEN
      v_return := '';
    END IF;
  
    v_length := length(p_string);
  
    IF (v_length = 0) THEN
      v_return := '';
    END IF;
  
    v_length := 0;
  
    IF (v_ip_use_cd = TRUE) -- AND v_ip_use_cd ^= NULL) --False = 0, True = non zero or -1
     THEN
      v_lcl_use_check_digit := TRUE;
    ELSIF (v_ip_use_cd = FALSE OR v_ip_use_cd = NULL) THEN
      v_lcl_use_check_digit := FALSE;
    END IF;
  
    v_set_postnet := set_postnet_at('mjo',
                                    'jkn',
                                    'jln',
                                    'jmo',
                                    'kjn',
                                    'kko',
                                    'klo',
                                    'ljn',
                                    'lko',
                                    'llo');
  
    v_full_data_to_encode := p_string;
    v_i                   := 1;
    v_length              := 0;
    v_length              := length(v_full_data_to_encode);
    v_only_correct_data   := '';
    --check to make sure data is numberic or other valid characters
  
    FOR v_i IN 1 .. v_length LOOP
      IF (is_number(substr(v_full_data_to_encode, v_i, 1)) = 0) THEN
        v_only_correct_data := v_only_correct_data ||
                               substr(v_full_data_to_encode, v_i, 1);
      END IF;
    END LOOP;
  
    v_length := 0;
    v_length := length(v_only_correct_data);
  
    --add start character
    v_printable_string := v_printable_string || 'n';
  
    --loop through the characters add get the proper encoding.
    FOR v_i IN 1 .. v_length LOOP
      v_current_char_num := 0;
      v_current_char_num := substr(v_only_correct_data, v_i, 1);
      v_printable_string := v_printable_string ||
                            v_set_postnet(v_current_char_num + 1);
      v_weighted_total   := v_weighted_total + v_current_char_num;
    END LOOP;
  
    v_cd := MOD(v_weighted_total, 10);
  
    IF (v_lcl_use_check_digit = TRUE) THEN
      v_check_digit := 10 - v_cd;
    ELSE
      v_check_digit := 0;
    END IF;
  
    IF (v_lcl_use_check_digit = TRUE) THEN
    
      v_printable_string := v_printable_string ||
                            v_set_postnet(v_check_digit + 1);
    END IF;
  
    v_printable_string := v_printable_string || 'n';
  
    v_printable_string2 := v_printable_string;
  
    v_return := v_printable_string2;
  
    RETURN(v_return);
  
  END postnet;
  --  =========================END POSTNET  =======================================

  ------------------------------------------------------------------------
  --                     PLANET                                       --
  ------------------------------------------------------------------------
  FUNCTION planet(p_string IN VARCHAR2, include_check_digit IN BOOLEAN)
    RETURN VARCHAR2
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL implementation bases on the
    --      example code Planet
    --
    --==============================================================
   IS
    --  v_pos      SGUI_RPT_EXCEPTION.POSITION_T;
  
    v_wrkstr VARCHAR2(6000);
    --p_string VARCHAR2 (1024);
    v_return           VARCHAR2(6000) := '';
    v_set_planet       set_planet_at;
    v_weighted_total   NUMBER := 0;
    v_current_char_num VARCHAR2(2);
    v_i                PLS_INTEGER := 1;
    v_g                PLS_INTEGER := 1;
  
    v_length              PLS_INTEGER;
    v_factor              NUMBER := 3;
    v_lcl_use_check_digit BOOLEAN;
    v_ip_use_cd           BOOLEAN; --(1) :='';
    v_printable_string    NVARCHAR2(32000) := '';
    v_only_correct_data   NVARCHAR2(32000) := ''; --filtered data after removal
  
    v_full_data_to_encode NVARCHAR2(32000) := '';
    v_nwpatternpn         VARCHAR2(2000) := '';
    v_current_value       VARCHAR2(2);
    v_check_digit         NUMBER(3) := 0;
    v_cd                  NUMBER(3) := 0;
  
  BEGIN
  
    v_ip_use_cd := include_check_digit;
  
    IF (p_string = NULL) THEN
      v_return := '';
    END IF;
  
    v_length := length(p_string);
  
    IF (v_length = 0) THEN
      v_return := '';
    END IF;
  
    v_length := 0;
  
    IF (v_ip_use_cd = TRUE) -- AND v_ip_use_cd ^= NULL) --False = 0, True = non zero or -1
     THEN
      v_lcl_use_check_digit := TRUE;
    ELSIF (v_ip_use_cd = FALSE OR v_ip_use_cd = NULL) THEN
      v_lcl_use_check_digit := FALSE;
    END IF;
  
    v_set_planet := set_planet_at('jmn',
                                  'mlo',
                                  'mko',
                                  'mjn',
                                  'lmo',
                                  'lln',
                                  'lkn',
                                  'kmo',
                                  'kln',
                                  'kkn');
  
    v_full_data_to_encode := p_string;
    v_i                   := 1;
    v_length              := 0;
    v_length              := length(v_full_data_to_encode);
    v_only_correct_data   := '';
    --check to make sure data is numberic or other valid characters
  
    FOR v_i IN 1 .. v_length LOOP
      IF (is_number(substr(v_full_data_to_encode, v_i, 1)) = 0) THEN
        v_only_correct_data := v_only_correct_data ||
                               substr(v_full_data_to_encode, v_i, 1);
      END IF;
    END LOOP;
  
    v_length := 0;
    v_length := length(v_only_correct_data);
  
    --add start character
    v_printable_string := v_printable_string || 'n';
  
    --loop through the characters add get the proper encoding.
    FOR v_i IN 1 .. v_length LOOP
      v_current_char_num := 0;
      v_current_char_num := substr(v_only_correct_data, v_i, 1);
      v_printable_string := v_printable_string ||
                            v_set_planet(v_current_char_num + 1);
      v_weighted_total   := v_weighted_total + v_current_char_num;
    END LOOP;
  
    v_cd := MOD(v_weighted_total, 10);
  
    IF (v_lcl_use_check_digit = TRUE) THEN
      v_check_digit := 10 - v_cd;
    ELSE
      v_check_digit := 0;
    END IF;
  
    IF (v_lcl_use_check_digit = TRUE) THEN
    
      v_printable_string := v_printable_string ||
                            v_set_planet(v_check_digit + 1);
    END IF;
  
    v_printable_string := v_printable_string || 'n';
  
    v_printable_string2 := v_printable_string;
  
    v_return := v_printable_string2;
    RETURN(v_return);
  
  END planet;
  --  =========================END PLANET  =======================================

  -----------------------------------------------------------------------
  --                           Code 39 Symbology                       --
  -----------------------------------------------------------------------
  FUNCTION code39(p_string            IN VARCHAR2,
                  include_check_digit IN BOOLEAN,
                  n_dimension         IN NUMBER) RETURN VARCHAR2
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL implementation bases on the
    --      example code Code39.txt
    --
    --==============================================================
   IS
    --  v_pos      SGUI_RPT_EXCEPTION.POSITION_T;
  
    --NVARCHAR2
    v_printable_string  NVARCHAR2(32000) := '';
    v_only_correct_data NVARCHAR2(32000) := ''; --filtered data after removal
    --of invalid code 39 characters
    v_full_data_to_encode NVARCHAR2(32000) := '';
  
    --VARCHAR2
    v_two_chars        VARCHAR2(2);
    v_char1            VARCHAR2(2);
    v_char2            VARCHAR2(2);
    v_wrkstr           VARCHAR2(6000);
    v_return           VARCHAR2(6000) := '';
    v_current_char_num VARCHAR2(2);
    v_nwpattern39      VARCHAR2(2000) := '';
    v_current_value    VARCHAR2(2);
  
    --NUMBER AND PLS_INTEGER
    v_weighted_total    NUMBER := 0;
    v_i                 PLS_INTEGER := 1;
    v_g                 PLS_INTEGER := 1;
    v_length            PLS_INTEGER;
    v_factor            NUMBER := 3;
    v_localn_dimension  NUMBER := 2;
    v_check_digit_value NUMBER(3) := 0;
  
    --BOOLEAN
    v_lcl_use_check_digit BOOLEAN;
    v_ip_use_cd           BOOLEAN;
  
    v_set_c39 set_c39_at;
  
  BEGIN
  
    v_ip_use_cd := include_check_digit;
  
    IF (p_string = NULL) THEN
      v_return := '';
    END IF;
  
    v_length := length(p_string);
  
    IF (v_length = 0) THEN
      v_return := '';
    END IF;
  
    v_length := 0;
  
    IF (v_ip_use_cd = TRUE) -- AND v_ip_use_cd ^= NULL) --False = 0, True = non zero or -1
     THEN
      v_lcl_use_check_digit := TRUE;
    ELSIF (v_ip_use_cd = FALSE OR v_ip_use_cd = NULL) THEN
      v_lcl_use_check_digit := FALSE;
    END IF;
  
    v_set_c39 := set_c39_at('nnnwwnwnnn',
                            'wnnwnnnnwn',
                            'nnwwnnnnwn',
                            'wnwwnnnnnn',
                            'nnnwwnnnwn',
                            'wnnwwnnnnn',
                            'nnwwwnnnnn',
                            'nnnwnnwnwn',
                            'wnnwnnwnnn',
                            'nnwwnnwnnn',
                            'wnnnnwnnwn',
                            'nnwnnwnnwn',
                            'wnwnnwnnnn',
                            'nnnnwwnnwn',
                            'wnnnwwnnnn',
                            'nnwnwwnnnn',
                            'nnnnnwwnwn',
                            'wnnnnwwnnn',
                            'nnwnnwwnnn',
                            'nnnnwwwnnn',
                            'wnnnnnnwwn',
                            'nnwnnnnwwn',
                            'wnwnnnnwnn',
                            'nnnnwnnwwn',
                            'wnnnwnnwnn',
                            'nnwnwnnwnn',
                            'nnnnnnwwwn',
                            'wnnnnnwwnn',
                            'nnwnnnwwnn',
                            'nnnnwnwwnn',
                            'wwnnnnnnwn',
                            'nwwnnnnnwn',
                            'wwwnnnnnnn',
                            'nwnnwnnnwn',
                            'wwnnwnnnnn',
                            'nwwnwnnnnn',
                            'nwnnnnwnwn',
                            'wwnnnnwnnn',
                            'nwwnnnwnnn',
                            'nwnwnwnnnn',
                            'nwnwnnnwnn',
                            'nwnnnwnwnn',
                            'nnnwnwnwnn',
                            'nwnnwnwnnn');
  
    IF (n_dimension = 3 OR n_dimension = 2) THEN
      v_localn_dimension := n_dimension;
    ELSE
      v_localn_dimension := 2;
    END IF;
  
    v_full_data_to_encode := p_string;
    v_i                   := 1;
    v_length              := 0;
    v_length              := length(v_full_data_to_encode);
    v_only_correct_data   := '';
    --check to make sure data is numberic or other valid characters
  
    FOR v_i IN 1 .. v_length LOOP
      --**add all number to onlycorrectdata string**--
      IF (ascii(substr(v_full_data_to_encode, v_i, 1))) >= 48 AND
         (ascii(substr(v_full_data_to_encode, v_i, 1))) <= 57 THEN
        v_only_correct_data := v_only_correct_data ||
                               (substr(v_full_data_to_encode, v_i, 1));
      
      ELSIF ((substr(v_full_data_to_encode, v_i, 1)) = '-') OR
            ((substr(v_full_data_to_encode, v_i, 1)) = '$') OR
            ((substr(v_full_data_to_encode, v_i, 1)) = '%') OR
            ((substr(v_full_data_to_encode, v_i, 1)) = '/') OR
            ((substr(v_full_data_to_encode, v_i, 1)) = '.') OR
            ((substr(v_full_data_to_encode, v_i, 1)) = '+') OR
            ((substr(v_full_data_to_encode, v_i, 1)) = ' ') THEN
        v_only_correct_data := v_only_correct_data ||
                               (substr(v_full_data_to_encode, v_i, 1));
      
      ELSIF ((ascii(substr(v_full_data_to_encode, v_i, 1))) >= 65) AND
            (ascii((substr(v_full_data_to_encode, v_i, 1))) <= 90) --uppercase letters
       THEN
        v_only_correct_data := v_only_correct_data ||
                               (substr(v_full_data_to_encode, v_i, 1));
      
      ELSIF ((ascii(substr(v_full_data_to_encode, v_i, 1))) >= 97 AND
            (ascii(substr(v_full_data_to_encode, v_i, 1))) <= 122) --convert to upper
       THEN
        v_only_correct_data := v_only_correct_data ||
                               (upper(substr(v_full_data_to_encode, v_i, 1)));
      END IF;
    END LOOP;
  
    v_length := 0; --reset back to zero
    v_length := length(v_only_correct_data);
  
    v_weighted_total := 0;
  
    --add start character
    v_printable_string := 'CAIIA';
  
    IF (v_localn_dimension = 3) THEN
      v_printable_string := 'CAIIA';
    ELSIF (v_localn_dimension = 2) THEN
      v_printable_string := 'BAEEA';
    END IF;
  
    v_i := 0;
  
    FOR v_i IN 1 .. v_length LOOP
      v_current_char_num := (ascii(substr(v_only_correct_data, v_i, 1)));
      v_current_value    := 0;
    
      IF (v_current_char_num < 58 AND v_current_char_num > 47)
      --numbers 0-9
       THEN
        v_current_value := v_current_char_num - 48;
      ELSIF (v_current_char_num >= 65 AND v_current_char_num <= 90) --uppercase letters
       THEN
        v_current_value := v_current_char_num - 55;
      
      ELSIF (v_current_char_num = 32) --space
       THEN
        v_current_value := 38;
      
      ELSIF (v_current_char_num = 45) --dash
       THEN
        v_current_value := 36;
      
      ELSIF (v_current_char_num = 46) --period
       THEN
        v_current_value := 37;
      
      ELSIF (v_current_char_num = 36) --dollar sign
       THEN
        v_current_value := 39;
      
      ELSIF (v_current_char_num = 47) --forward slash
       THEN
        v_current_value := 40;
      
      ELSIF (v_current_char_num = 43) --plus sign
       THEN
        v_current_value := 41;
      
      ELSIF (v_current_char_num = 37) --percent sign
       THEN
        v_current_value := 42;
      END IF;
    
      IF (include_check_digit = TRUE) THEN
        v_weighted_total := v_weighted_total + v_current_value;
      END IF;
    
      --get the narrow/wide pattern for codabar
      v_nwpattern39 := v_set_c39(v_current_value + 1);
    
      IF (v_localn_dimension = 3)
      
       THEN
        v_j := 1;
      
        WHILE v_j < 11 LOOP
          v_two_chars := '';
          v_two_chars := (substr(v_nwpattern39, v_j, 2));
          IF v_two_chars = 'nn' THEN
            v_printable_string := v_printable_string || 'A';
          ELSIF v_two_chars = 'nw' THEN
            v_printable_string := v_printable_string || 'C';
          ELSIF v_two_chars = 'wn' THEN
            v_printable_string := v_printable_string || 'I';
          ELSIF v_two_chars = 'ww' THEN
            v_printable_string := v_printable_string || 'K';
          END IF;
          v_j := v_j + 2;
        END LOOP;
      
      ELSIF (v_localn_dimension = 2)
      
       THEN
        v_j := 1;
      
        WHILE v_j < 11 LOOP
          v_two_chars := '';
          v_two_chars := (substr(v_nwpattern39, v_j, 2));
          IF v_two_chars = 'nn' THEN
            v_printable_string := v_printable_string || 'A';
          ELSIF v_two_chars = 'nw' THEN
            v_printable_string := v_printable_string || 'B';
          ELSIF v_two_chars = 'wn' THEN
            v_printable_string := v_printable_string || 'E';
          ELSIF v_two_chars = 'ww' THEN
            v_printable_string := v_printable_string || 'F';
          END IF;
          v_j := v_j + 2;
        END LOOP;
      
      END IF;
    END LOOP;
  
    IF (v_lcl_use_check_digit = TRUE) THEN
      v_check_digit_value := MOD(v_weighted_total, 43);
    
      --get the narrow/wide pattern for Codabar
      v_nwpattern39 := v_set_c39(v_check_digit_value + 1);
    
      IF (v_localn_dimension = 3) THEN
        v_j := 1;
      
        WHILE v_j < 11 LOOP
          v_two_chars := '';
          v_two_chars := (substr(v_nwpattern39, v_j, 2));
          IF v_two_chars = 'nn' THEN
            v_printable_string := v_printable_string || 'A';
          ELSIF v_two_chars = 'nw' THEN
            v_printable_string := v_printable_string || 'C';
          ELSIF v_two_chars = 'wn' THEN
            v_printable_string := v_printable_string || 'I';
          ELSIF v_two_chars = 'ww' THEN
            v_printable_string := v_printable_string || 'K';
          END IF;
          v_j := v_j + 2;
        END LOOP;
      
      ELSIF (v_localn_dimension = 2) THEN
        v_j := 1;
      
        WHILE v_j < 11 LOOP
          v_two_chars := '';
          v_two_chars := (substr(v_nwpattern39, v_j, 2));
          IF v_two_chars = 'nn' THEN
            v_printable_string := v_printable_string || 'A';
          ELSIF v_two_chars = 'nw' THEN
            v_printable_string := v_printable_string || 'B';
          ELSIF v_two_chars = 'wn' THEN
            v_printable_string := v_printable_string || 'E';
          ELSIF v_two_chars = 'ww' THEN
            v_printable_string := v_printable_string || 'F';
          END IF;
          v_j := v_j + 2;
        END LOOP;
      
      END IF;
    END IF;
  
    IF (v_localn_dimension = 3) THEN
      v_printable_string := v_printable_string || 'CAIIA';
    
    ELSIF (v_localn_dimension = 2) THEN
      v_printable_string := v_printable_string || 'BAEEA';
    END IF;
  
    v_printable_string2 := v_printable_string;
  
    v_return := v_printable_string2;
  
    RETURN(v_return);
  
  END code39;
  --  =========================END OF CODE 39 FUNCTION  =======================================

  ------------------------------------------------------------------------------
  ---------------------------
  -------------------------            CODE128 AUTO
  ------------------------------------

  ------------------------------------------------------------------------------
  ---------------------------

  FUNCTION code128(p_string IN VARCHAR2, apply_tilde IN BOOLEAN)
    RETURN VARCHAR2
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL implementation bases on the
    --  Visual Basic & VBA Functions for IDAutomation Universal Barcode Fonts
    --      Version 5.05
    --      These functions are only compatible with the
    --  IDAutomation Universal Barcode Font Advantage (TM)
    --   http://www.idautomation.com/fonts/universal/
    --
    --==============================================================
   IS
    -- v_pos            SGUI_RPT_EXCEPTION.POSITION_T;
  
    v_set_128_a   set128_at;
    v_setwrkstr_a setwrkstr_at := setwrkstr_at();
    v_wrkstr      NVARCHAR2(6000) := '';
    v_asc_value   PLS_INTEGER;
    --v_asc_value NVARCHAR2 (6000) :='';
    v_length            PLS_INTEGER;
    v_128_start         VARCHAR2(3);
    v_chr_value         VARCHAR2(1);
    v_return            VARCHAR2(6000); --ben change from 255 to 512
    v_current_chr_value VARCHAR2(10);
    v_current_asc_value PLS_INTEGER;
    v_weighted_total    NUMBER;
    v_printable_string  VARCHAR2(6000) := ''; --ben change from 255 to 512
    v_check_digit       PLS_INTEGER;
    v_i                 PLS_INTEGER;
    v_next_digit_used   PLS_INTEGER;
    v_j                 PLS_INTEGER;
    v_p_string          VARCHAR2(6000) := '';
    v_p_string2         NVARCHAR2(6000) := '';
    v_dummy             NVARCHAR2(6000) := '';
    v_encoded           VARCHAR2(6000);
    v_factor            NUMBER := 3;
  
    v_k                     PLS_INTEGER;
    v_lcl_applytilde        BOOLEAN := FALSE;
    v_weight_value          NUMBER := 0;
    v_num_chars_taken       NUMBER := 0;
    v_tilde_string_to_check NVARCHAR2(6000) := '';
    v_hex1                  NUMBER;
    v_break                 NUMBER(4) := 0;
    v_g                     PLS_INTEGER := 0;
    v_correct_tilde_string  NVARCHAR2(6000) := '';
  
    v_check_digit_value VARCHAR2(512);
    v_outstring         VARCHAR2(6000);
  
  BEGIN
  
    ------------------------------------------------------------------------------
    -----------------------------------------------------
    v_lcl_applytilde := apply_tilde;
    --begin H
    IF (v_lcl_applytilde = TRUE) THEN
      v_wrkstr := '';
      v_i      := 1;
      v_length := 0;
      v_length := length(p_string);
    
      WHILE v_i <= v_length LOOP
      
        --begin G
        IF (v_i < v_length - 2 AND (substr(p_string, v_i, 1)) = '~' AND
           substr(p_string, v_i + 1, 1) = 'm') THEN
        
          --begin F
        
          IF ((ascii(substr(p_string, v_i + 2, 1))) >= 48 AND
             (ascii(substr(p_string, v_i + 2, 1))) <= 57 AND
             (ascii(substr(p_string, v_i + 3, 1))) >= 48 AND
             (ascii(substr(p_string, v_i + 3, 1))) <= 57) THEN
          
            --weight value
            --begin if E
            IF ((substr(p_string, v_i + 2, 1)) = '0') THEN
              v_weight_value := ((substr(p_string, v_i + 3, 1)));
            ELSE
              v_weight_value := ((substr(p_string, v_i + 2, 2)));
            END IF;
            --end if E
            --begin if D
            IF (v_i - v_weight_value < 1) THEN
              v_weight_value := v_i;
              --end if D
            END IF;
          
            v_k := v_i - 1;
            WHILE v_k >= 0 --begin tilde loop
            
             LOOP
              --begin if C
            
              IF (ascii(substr(p_string, v_k, 1)) >= 48 AND
                 ascii(substr(p_string, v_k, 1)) <= 57) THEN
              
                --begin if B
                IF ((v_k >= 3) AND substr(p_string, v_k - 3, 1) = '~') THEN
                  v_k := v_k - 3;
                
                ELSE
                  v_tilde_string_to_check := v_tilde_string_to_check ||
                                             (substr(p_string, v_k, 1));
                  v_num_chars_taken       := v_num_chars_taken + 1;
                
                  --begin if A
                  IF (v_num_chars_taken = v_weight_value) THEN
                    v_break := 15;
                    EXIT WHEN v_break > 1;
                  END IF;
                  --end if A
                END IF;
                --end if B
              
                --end if C
              END IF;
            
              v_k := v_k - 1;
            END LOOP; --end tilde loop
          
            --begin if i
            IF (v_num_chars_taken > 0) THEN
            
              --Return v_tilde_string_to_check into correct order Reverse method
              v_g := length(v_tilde_string_to_check);
              WHILE v_g > 0 --begin reverse loop
               LOOP
                v_correct_tilde_string := v_correct_tilde_string ||
                                          (substr(v_tilde_string_to_check,
                                                  v_g,
                                                  1));
                v_g                    := v_g - 1;
              
              END LOOP; --end reverse loop
            
              v_wrkstr := v_wrkstr ||
                          find_mod10_digit(v_correct_tilde_string);
              v_i      := v_i + 3;
            ELSE
              v_wrkstr := v_wrkstr || (substr(p_string, v_i, 1));
            END IF;
            --end if i
          
          ELSE
            v_wrkstr := v_wrkstr || (substr(p_string, v_i, 1));
          END IF;
          --end if f
        
        ELSIF (v_i < v_length - 2 AND (substr(p_string, v_i, 1)) = '~') THEN
          -- v_weight_value := (SUBSTR(p_string,v_i +2, 2));
          v_weight_value := (substr(p_string, v_i + 1, 3));
        
          v_wrkstr := v_wrkstr || chr(v_weight_value);
        
          v_i := v_i + 3;
          --  v_hex1:= 0; --reset hexvalue
        
        ELSIF (ascii(substr(p_string, v_i, 1)) >= 0 AND
              (ascii(substr(p_string, v_i, 1))) <= 126 OR
              (ascii(substr(p_string, v_i, 1)) = 202)) THEN
          v_wrkstr := v_wrkstr || (substr(p_string, v_i, 1));
        END IF;
        --end if g
      
        -------------- v_wrkstr := v_wrkstr || (SUBSTR(p_string, v_i, 1));
        v_i := v_i + 1;
      END LOOP;
    
    ELSIF (v_lcl_applytilde = FALSE) THEN
    
      v_wrkstr := p_string;
    END IF;
    --end if h
  
    -- END IF;
  
    ------------------------------------------------------------------------------
    --------------------------------------------------------
    v_set_128_a := set128_at('EFF',
                             'FEF',
                             'FFE',
                             'BBG',
                             'BCF',
                             'CBF',
                             'BFC',
                             'BGB',
                             'CFB',
                             'FBC',
                             'FCB',
                             'GBB',
                             'AFJ',
                             'BEJ',
                             'BFI',
                             'AJF',
                             'BIF',
                             'BJE',
                             'FJA',
                             'FAJ',
                             'FBI',
                             'EJB',
                             'FIB',
                             'IEI',
                             'IBF',
                             'JAF',
                             'JBE',
                             'IFB',
                             'JEB',
                             'JFA',
                             'EEG',
                             'EGE',
                             'GEE',
                             'ACG',
                             'CAG',
                             'CCE',
                             'AGC',
                             'CEC',
                             'CGA',
                             'ECC',
                             'GAC',
                             'GCA',
                             'AEK',
                             'AGI',
                             'CEI',
                             'AIG',
                             'AKE',
                             'CIE',
                             'IIE',
                             'ECI',
                             'GAI',
                             'EIC',
                             'EKA',
                             'EII',
                             'IAG',
                             'ICE',
                             'KAE',
                             'IEC',
                             'IGA',
                             'KEA',
                             'IMA',
                             'FDA',
                             'OAA',
                             'ABH',
                             'ADF',
                             'BAH',
                             'BDE',
                             'DAF',
                             'DBE',
                             'AFD',
                             'AHB',
                             'BED',
                             'BHA',
                             'DEB',
                             'DFA',
                             'HBA',
                             'FAD',
                             'MIA',
                             'HAB',
                             'CMA',
                             'ABN',
                             'BAN',
                             'BBM',
                             'ANB',
                             'BMB',
                             'BNA',
                             'MBB',
                             'NAB',
                             'NBA',
                             'EEM',
                             'EME',
                             'MEE',
                             'AAO',
                             'ACM',
                             'CAM',
                             'AMC',
                             'AOA',
                             'MAC',
                             'MCA',
                             'AIM',
                             'AMI',
                             'IAM',
                             'MAI',
                             'EDB',
                             'EBD',
                             'EBJ');
  
    -----------------------------------------------------------------------
    --  v_pos := 'here we select the character set A, B, or C for the start char';
    -----------------------------------------------------------------------
    -- Here we select the character set A, B, or C for the start character
    -- start A = EDB
    -- start B = EBD
    -- start C = EBJ
    v_chr_value := 'B';
    v_length    := 0;
    v_length    := length(v_wrkstr);
    v_asc_value := ascii(substr(v_wrkstr, 1, 1));
    v_encoded   := '';
    v_i         := 1;
    --set A
    IF v_asc_value < 32 THEN
      v_128_start := 'EDB';
    END IF;
    -------------------------------------------
    --set B
    IF v_asc_value BETWEEN 31 AND 127 OR v_asc_value = 197 THEN
      v_128_start := 'EBD';
    
    END IF;
  
    -------------------------------------------
  
    --set C
    IF v_length > 3 AND is_number(substr(v_wrkstr, 1, 4)) = 0 THEN
      v_128_start := 'EBJ';
    END IF;
  
    ----------------------------------
    --202 & 212-215 is for the FNC1, with this Start C is mandatory
    IF v_asc_value = 202 THEN
      v_128_start := 'EBJ';
    END IF;
    IF v_asc_value > 211 THEN
      v_128_start := 'EBJ';
    END IF;
  
    IF v_128_start = 'EDB' THEN
      v_chr_value := 'A';
    ELSIF v_128_start = 'EBD' THEN
      v_chr_value := 'B';
    ELSIF v_128_start = 'EBJ' THEN
      v_chr_value := 'C';
    END IF;
  
    -----------------------------------------------------------------------
    -- v_pos := 'map the input string into the Code 128 character set';
    -----------------------------------------------------------------------
  
    -- map the input string into the Code 128 character set
    v_i      := 1;
    v_length := 0;
    v_length := length(v_wrkstr);
  
    WHILE v_i <= v_length LOOP
    
      v_asc_value := ascii(substr(v_wrkstr, v_i, 1));
    
      ---------------------------------------------------------------
      --check for FNC2 which is ASCII 197 in any set other than C
      IF v_asc_value = 197 THEN
        -- switch to B
        IF v_chr_value = 'C' THEN
        
          v_setwrkstr_a.extend;
          v_setwrkstr_a(v_setwrkstr_a.count) := 200;
        
          v_chr_value := 'B';
        END IF;
      
        v_setwrkstr_a.extend;
        v_setwrkstr_a(v_setwrkstr_a.count) := 197;
      
      END IF;
      --check for FNC1 in any set which is ASCII 202 and ASCII 212-215
      IF (v_asc_value = 202 OR (v_asc_value <= 217 AND v_asc_value >= 212))
      --BRJ 8/2/07
      -- v_asc_value > 212
       THEN
      
        v_setwrkstr_a.extend;
        v_setwrkstr_a(v_setwrkstr_a.count) := 202;
      
        --  v_length := LENGTH (p_string);
      
      ELSIF
      
       (((v_i < (v_length)) AND
       
       (ascii(substr(v_wrkstr, v_i, 1))) >= 48 AND
       (ascii(substr(p_string, v_i, 1))) <= 57 AND
       (ascii(substr(v_wrkstr, v_i + 1, 1))) >= 48 AND
       (ascii(substr(p_string, v_i + 1, 1))) <= 57 AND
       (ascii(substr(v_wrkstr, v_i + 2, 1))) >= 48 AND
       (ascii(substr(p_string, v_i + 2, 1))) <= 57 AND
       (ascii(substr(v_wrkstr, v_i + 3, 1))) >= 48 AND
       (ascii(substr(p_string, v_i + 3, 1))) <= 57)
       
       OR
       
       (ascii(substr(v_wrkstr, v_i, 1))) >= 48 AND
       (ascii(substr(p_string, v_i, 1))) <= 57 AND
       (ascii(substr(v_wrkstr, v_i + 1, 1))) >= 48 AND
       (ascii(substr(p_string, v_i + 1, 1))) <= 57 AND
       
       v_chr_value = 'C')
      
       THEN
      
        --v_encoded := ''; test
        /* BRJ 8-1-2007
                   Check to see if we have an odd number of number to encode.
                   If so, then stay in current set for 1 number and then switch to
        save space */
      
        -------------------------------------------------------------------------------
        IF (v_chr_value <> 'C') THEN
          v_j      := v_i;
          v_factor := 3;
        
          WHILE (v_j <= v_length AND
                (ascii(substr(v_wrkstr, v_j, 1))) >= 48) AND
                (ascii(substr(v_wrkstr, v_j, 1))) <= 57 LOOP
            v_factor := (4 - v_factor);
            v_j      := v_j + 1;
          
          END LOOP;
        
          IF (v_factor = 1) THEN
          
            v_setwrkstr_a.extend;
            v_setwrkstr_a(v_setwrkstr_a.count) := v_asc_value;
            -- v_wrkstr := v_wrkstr || (SUBSTR(p_string, v_i,1));
          
            v_i := v_i + 1;
          END IF;
        
          v_factor := 0;
        END IF;
      
        ------------------------------------------------------------------------------
      
        --switch to set C if not already in it
        IF v_chr_value <> 'C' THEN
        
          v_setwrkstr_a.extend;
          v_setwrkstr_a(v_setwrkstr_a.count) := 199;
          v_chr_value := 'C';
        
        END IF;
        v_current_chr_value := substr(v_wrkstr, v_i, 2);
        v_current_asc_value := vb_val(v_current_chr_value);
      
        --------------------------
        --set the CurrentValue to the number of String CurrentChar
      
        v_setwrkstr_a.extend;
        v_setwrkstr_a(v_setwrkstr_a.count) := (v_current_asc_value + 32);
      
        v_i := v_i + 1;
        --check for switching to character set A
      ELSIF v_i <= v_length AND
            (v_asc_value < 31 OR --31
            (v_chr_value = 'A' AND v_asc_value BETWEEN 32 AND 96)) THEN
        --switch to set A if not already in it
        IF v_chr_value <> 'A' THEN
          v_setwrkstr_a.extend;
          v_setwrkstr_a(v_setwrkstr_a.count) := 201;
          v_chr_value := 'A';
        END IF;
        IF v_asc_value < 32 THEN
        
          v_setwrkstr_a.extend;
          v_setwrkstr_a(v_setwrkstr_a.count) := (v_asc_value + 96);
        
          -- ELSIF v_asc_value > 32  ---31
          --THEN
          --    v_setwrkstr_a.extend;
          --  v_setwrkstr_a(v_setwrkstr_a.count):= v_asc_value;
        END IF;
        --check for switching to character set B
      ELSIF v_i <= v_length AND v_asc_value BETWEEN 31 AND 127 THEN
        --switch to set B if not already in it
        IF v_chr_value <> 'B' THEN
          v_setwrkstr_a.extend;
          v_setwrkstr_a(v_setwrkstr_a.count) := 200;
        
          v_chr_value := 'B';
        END IF;
      
        v_setwrkstr_a.extend;
        v_setwrkstr_a(v_setwrkstr_a.count) := v_asc_value;
      END IF;
      v_i := v_i + 1;
    END LOOP;
  
    -----------------------------------------------------------------------
    -- v_pos := 'calculating check digit';
    -----------------------------------------------------------------------
    IF v_128_start = 'EDB' THEN
      --v_chr_value was A;
      v_weighted_total := 103;
    ELSIF v_128_start = 'EBD' THEN
      --v_chr_value was B;
      v_weighted_total := 104;
    ELSIF v_128_start = 'EBJ' THEN
      --v_chr_value was C;
      v_weighted_total := 105;
    END IF;
  
    ------------------------------------------------------------------------------
    -------------
  
    v_length := (v_setwrkstr_a.count);
  
    FOR v_ii IN 1 .. v_length LOOP
      v_asc_value := (v_setwrkstr_a(v_ii));
    
      IF v_asc_value < 135 THEN
        v_current_asc_value := v_asc_value - 31;
      END IF;
      IF v_asc_value > 134 THEN
        v_current_asc_value := v_asc_value - 99;
      END IF;
      IF v_asc_value = 194 THEN
        v_current_asc_value := 1;
      END IF;
      v_printable_string  := v_printable_string ||
                             v_set_128_a(v_current_asc_value);
      v_current_asc_value := (v_current_asc_value - 1) * v_ii;
      v_weighted_total    := v_weighted_total + v_current_asc_value;
    END LOOP;
  
    ------------------------------------------------------------------------------
    --------------
    -----------------------------------------------------------------------
    --  v_pos := 'adding start-, printable string-, check-digit value- and stop characters';
    -----------------------------------------------------------------------
  
    v_check_digit := (MOD(v_weighted_total, 103) + 1);
    --GIAH produces the stop character
  
    v_printable_string2 := (v_128_start || v_printable_string ||
                           v_set_128_a(v_check_digit) || 'GIAH');
  
    v_return := v_printable_string2;
  
    --END If;
    RETURN(v_return);
  
  END code128;

  -------------------------CODE128A------------------------------------
  -----------------------------------------------------------------------
  FUNCTION code128a(p_string IN VARCHAR2) RETURN VARCHAR2
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL implementation bases on the
    --  Visual Basic & VBA Functions for IDAutomation Universal Barcode Fonts
    --      Version 5.05
    --      These functions are only compatible with the
    --  IDAutomation Universal Barcode Font Advantage (TM)
    --   http://www.idautomation.com/fonts/universal/
    --
    --==============================================================
   IS
    -- v_pos            SGUI_RPT_EXCEPTION.POSITION_T;
  
    v_set_128_a           set128_at;
    v_full_data_to_encode NVARCHAR2(6000) := '';
    v_printable_string    VARCHAR2(6000) := '';
    v_weighted_total      NUMBER;
    v_length              PLS_INTEGER;
    v_current_value       VARCHAR2(10);
    v_current_char_num    VARCHAR2(30);
    v_check_digit_value   VARCHAR2(512);
    v_return              NVARCHAR2(6000);
  
  BEGIN
  
    v_full_data_to_encode := p_string;
  
    v_set_128_a := set128_at('EFF',
                             'FEF',
                             'FFE',
                             'BBG',
                             'BCF',
                             'CBF',
                             'BFC',
                             'BGB',
                             'CFB',
                             'FBC',
                             'FCB',
                             'GBB',
                             'AFJ',
                             'BEJ',
                             'BFI',
                             'AJF',
                             'BIF',
                             'BJE',
                             'FJA',
                             'FAJ',
                             'FBI',
                             'EJB',
                             'FIB',
                             'IEI',
                             'IBF',
                             'JAF',
                             'JBE',
                             'IFB',
                             'JEB',
                             'JFA',
                             'EEG',
                             'EGE',
                             'GEE',
                             'ACG',
                             'CAG',
                             'CCE',
                             'AGC',
                             'CEC',
                             'CGA',
                             'ECC',
                             'GAC',
                             'GCA',
                             'AEK',
                             'AGI',
                             'CEI',
                             'AIG',
                             'AKE',
                             'CIE',
                             'IIE',
                             'ECI',
                             'GAI',
                             'EIC',
                             'EKA',
                             'EII',
                             'IAG',
                             'ICE',
                             'KAE',
                             'IEC',
                             'IGA',
                             'KEA',
                             'IMA',
                             'FDA',
                             'OAA',
                             'ABH',
                             'ADF',
                             'BAH',
                             'BDE',
                             'DAF',
                             'DBE',
                             'AFD',
                             'AHB',
                             'BED',
                             'BHA',
                             'DEB',
                             'DFA',
                             'HBA',
                             'FAD',
                             'MIA',
                             'HAB',
                             'CMA',
                             'ABN',
                             'BAN',
                             'BBM',
                             'ANB',
                             'BMB',
                             'BNA',
                             'MBB',
                             'NAB',
                             'NBA',
                             'EEM',
                             'EME',
                             'MEE',
                             'AAO',
                             'ACM',
                             'CAM',
                             'AMC',
                             'AOA',
                             'MAC',
                             'MCA',
                             'AIM',
                             'AMI',
                             'IAM',
                             'MAI',
                             'EDB',
                             'EBD',
                             'EBJ');
  
    v_weighted_total := 103; --Weighted total for check digit calculation. initialize with set A start character
  
    v_length := 0;
    v_i      := 1;
  
    v_length := length(v_full_data_to_encode);
  
    --add the character string matching the array to the printable string and calculate the check digit.
    FOR v_i IN 1 .. v_length LOOP
      v_current_char_num := ascii(substr(v_full_data_to_encode, v_i, 1)) - 32;
      v_current_value    := v_current_char_num * v_i;
    
      --if it won't be in the table, don't add it
      IF (v_current_char_num <= 106 AND v_current_char_num >= 0) THEN
        v_weighted_total   := v_weighted_total + v_current_value;
        v_printable_string := v_printable_string ||
                              v_set_128_a(v_current_char_num + 1);
      END IF;
    END LOOP;
  
    -- v_check_digit_value := (v_weighted_total % 103);
    v_check_digit_value := (MOD(v_weighted_total, 103));
    v_printable_string  := v_printable_string ||
                           v_set_128_a(v_check_digit_value + 1);
  
    --GIAH produces the stop character. Add that as well
    --  v_printable_string := v_printable_string || "GIAH");
  
    --Allow the string to return to the proper size.
    v_printable_string2 := ('EDB' || v_printable_string || 'GIAH');
  
    v_return := v_printable_string2;
  
    RETURN(v_return);
  END code128a;

  ---------------------------------------------------------------------------------
  --                            CODE128B
  ---------------------------------------------------------------------------------

  FUNCTION code128b(p_string IN VARCHAR2) RETURN VARCHAR2
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL implementation bases on the
    --  Visual Basic & VBA Functions for IDAutomation Universal Barcode Fonts
    --      Version 5.05
    --      These functions are only compatible with the
    --  IDAutomation Universal Barcode Font Advantage (TM)
    --   http://www.idautomation.com/fonts/universal/
    --
    --==============================================================
   IS
    -- v_pos            SGUI_RPT_EXCEPTION.POSITION_T;
  
    v_set_128_a           set128_at;
    v_full_data_to_encode NVARCHAR2(6000) := '';
    v_printable_string    VARCHAR2(6000) := '';
    v_weighted_total      NUMBER;
    v_length              PLS_INTEGER;
    v_current_value       VARCHAR2(10);
    v_current_char_num    VARCHAR2(30);
    v_check_digit_value   VARCHAR2(512);
    v_return              NVARCHAR2(6000);
  
  BEGIN
  
    v_full_data_to_encode := p_string;
  
    v_set_128_a := set128_at('EFF',
                             'FEF',
                             'FFE',
                             'BBG',
                             'BCF',
                             'CBF',
                             'BFC',
                             'BGB',
                             'CFB',
                             'FBC',
                             'FCB',
                             'GBB',
                             'AFJ',
                             'BEJ',
                             'BFI',
                             'AJF',
                             'BIF',
                             'BJE',
                             'FJA',
                             'FAJ',
                             'FBI',
                             'EJB',
                             'FIB',
                             'IEI',
                             'IBF',
                             'JAF',
                             'JBE',
                             'IFB',
                             'JEB',
                             'JFA',
                             'EEG',
                             'EGE',
                             'GEE',
                             'ACG',
                             'CAG',
                             'CCE',
                             'AGC',
                             'CEC',
                             'CGA',
                             'ECC',
                             'GAC',
                             'GCA',
                             'AEK',
                             'AGI',
                             'CEI',
                             'AIG',
                             'AKE',
                             'CIE',
                             'IIE',
                             'ECI',
                             'GAI',
                             'EIC',
                             'EKA',
                             'EII',
                             'IAG',
                             'ICE',
                             'KAE',
                             'IEC',
                             'IGA',
                             'KEA',
                             'IMA',
                             'FDA',
                             'OAA',
                             'ABH',
                             'ADF',
                             'BAH',
                             'BDE',
                             'DAF',
                             'DBE',
                             'AFD',
                             'AHB',
                             'BED',
                             'BHA',
                             'DEB',
                             'DFA',
                             'HBA',
                             'FAD',
                             'MIA',
                             'HAB',
                             'CMA',
                             'ABN',
                             'BAN',
                             'BBM',
                             'ANB',
                             'BMB',
                             'BNA',
                             'MBB',
                             'NAB',
                             'NBA',
                             'EEM',
                             'EME',
                             'MEE',
                             'AAO',
                             'ACM',
                             'CAM',
                             'AMC',
                             'AOA',
                             'MAC',
                             'MCA',
                             'AIM',
                             'AMI',
                             'IAM',
                             'MAI',
                             'EDB',
                             'EBD',
                             'EBJ');
  
    v_weighted_total := 104; --Weighted total for check digit calculation. initialize with set A start character
  
    v_length := 0;
    v_i      := 1;
  
    v_length := length(v_full_data_to_encode);
  
    --add the character string matching the array to the printable string and calculate the check digit.
    FOR v_i IN 1 .. v_length LOOP
      v_current_char_num := ascii(substr(v_full_data_to_encode, v_i, 1)) - 32;
      v_current_value    := v_current_char_num * v_i;
    
      --if it won't be in the table, don't add it
      IF (v_current_char_num <= 106 AND v_current_char_num >= 0) THEN
        v_weighted_total   := v_weighted_total + v_current_value;
        v_printable_string := v_printable_string ||
                              v_set_128_a(v_current_char_num + 1);
      END IF;
    END LOOP;
  
    -- v_check_digit_value := (v_weighted_total % 103);
    v_check_digit_value := (MOD(v_weighted_total, 103));
    v_printable_string  := v_printable_string ||
                           v_set_128_a(v_check_digit_value + 1);
  
    --GIAH produces the stop character. Add that as well
    --  v_printable_string := v_printable_string || "GIAH");
  
    --Allow the string to return to the proper size.
    v_printable_string2 := ('EBD' || v_printable_string || 'GIAH');
  
    v_return := v_printable_string2;
  
    RETURN(v_return);
  END code128b;

  ----------------------------------------------------------------------------
  --           CODE128C

  ------------------------------------------------------------------------------
  ---------------------------
  FUNCTION code128c(p_string IN VARCHAR2) RETURN VARCHAR2
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL implementation bases on the
    --  Visual Basic & VBA Functions for IDAutomation Universal Barcode Fonts
    --      Version 5.05
    --      These functions are only compatible with the
    --  IDAutomation Universal Barcode Font Advantage (TM)
    --   http://www.idautomation.com/fonts/universal/
    --
    --==============================================================
   IS
    -- v_pos            SGUI_RPT_EXCEPTION.POSITION_T;
  
    v_set_128_a           set128_at;
    v_full_data_to_encode NVARCHAR2(6000) := '';
    v_printable_string    VARCHAR2(6000) := '';
    v_weighted_total      NUMBER;
    v_length              PLS_INTEGER;
    v_current_value       VARCHAR2(10);
    v_current_char_num    VARCHAR2(30);
    v_check_digit_value   VARCHAR2(512);
    v_return              NVARCHAR2(6000);
    v_temp                NUMBER(10) := 0; --in case we need to add a zero
    v_only_correct_data   NVARCHAR2(6000) := '';
    v_weight_value        NUMBER;
    v_correct_data        NVARCHAR2(6000) := '';
  BEGIN
  
    v_full_data_to_encode := p_string;
  
    v_set_128_a := set128_at('EFF',
                             'FEF',
                             'FFE',
                             'BBG',
                             'BCF',
                             'CBF',
                             'BFC',
                             'BGB',
                             'CFB',
                             'FBC',
                             'FCB',
                             'GBB',
                             'AFJ',
                             'BEJ',
                             'BFI',
                             'AJF',
                             'BIF',
                             'BJE',
                             'FJA',
                             'FAJ',
                             'FBI',
                             'EJB',
                             'FIB',
                             'IEI',
                             'IBF',
                             'JAF',
                             'JBE',
                             'IFB',
                             'JEB',
                             'JFA',
                             'EEG',
                             'EGE',
                             'GEE',
                             'ACG',
                             'CAG',
                             'CCE',
                             'AGC',
                             'CEC',
                             'CGA',
                             'ECC',
                             'GAC',
                             'GCA',
                             'AEK',
                             'AGI',
                             'CEI',
                             'AIG',
                             'AKE',
                             'CIE',
                             'IIE',
                             'ECI',
                             'GAI',
                             'EIC',
                             'EKA',
                             'EII',
                             'IAG',
                             'ICE',
                             'KAE',
                             'IEC',
                             'IGA',
                             'KEA',
                             'IMA',
                             'FDA',
                             'OAA',
                             'ABH',
                             'ADF',
                             'BAH',
                             'BDE',
                             'DAF',
                             'DBE',
                             'AFD',
                             'AHB',
                             'BED',
                             'BHA',
                             'DEB',
                             'DFA',
                             'HBA',
                             'FAD',
                             'MIA',
                             'HAB',
                             'CMA',
                             'ABN',
                             'BAN',
                             'BBM',
                             'ANB',
                             'BMB',
                             'BNA',
                             'MBB',
                             'NAB',
                             'NBA',
                             'EEM',
                             'EME',
                             'MEE',
                             'AAO',
                             'ACM',
                             'CAM',
                             'AMC',
                             'AOA',
                             'MAC',
                             'MCA',
                             'AIM',
                             'AMI',
                             'IAM',
                             'MAI',
                             'EDB',
                             'EBD',
                             'EBJ');
  
    v_weighted_total := 105; --Weighted total for check digit calculation. initialize with set C start character
    v_weight_value   := 1;
    v_length         := 0;
    v_i              := 1;
  
    v_length := length(v_full_data_to_encode);
  
    --Check to make sure data is numeric and remove dashes, etc.
    FOR v_i IN 1 .. v_length LOOP
    
      /* Add all numbers to OnlyCorrectData string */
      IF (ascii(substr(v_full_data_to_encode, v_i, 1)) >= 48) AND
         (ascii(substr(v_full_data_to_encode, v_i, 1)) <= 57) THEN
      
        v_correct_data := v_correct_data ||
                          (substr(v_full_data_to_encode, v_i, 1));
      END IF;
    END LOOP;
    v_length := 0;
    v_length := length(v_correct_data);
  
    IF (MOD(v_length, 2) != 0) THEN
      v_correct_data := v_temp || v_correct_data;
    
    END IF;
  
    v_length := length(v_correct_data);
    WHILE v_i < v_length LOOP
      v_current_value := to_number(substr(v_correct_data, v_i, 2));
    
      v_printable_string := v_printable_string ||
                            v_set_128_a(v_current_value + 1);
      v_weighted_total   := v_weighted_total +
                            ((v_current_value) * v_weight_value);
      v_weight_value     := v_weight_value + 1;
      v_i                := v_i + 2;
    END LOOP;
  
    v_check_digit_value := (MOD(v_weighted_total, 103));
    v_printable_string  := v_printable_string ||
                           v_set_128_a(v_check_digit_value + 1);
  
    --Allow the string to return to the proper size.
    v_printable_string2 := ('EBJ' || v_printable_string || 'GIAH');
  
    v_return := v_printable_string2;
  
    RETURN(v_return);
  END code128c;

  FUNCTION is_number(p_string IN VARCHAR2) RETURN PLS_INTEGER
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL function to check if the input string is a number
    --
    --==============================================================
  
   IS
  
    v_check_num NUMBER;
  
  BEGIN
    v_check_num := to_number(p_string);
    RETURN(0);
  EXCEPTION
    WHEN value_error THEN
      RETURN(1);
  END is_number;

  FUNCTION vb_val(p_string IN VARCHAR2) RETURN NUMBER
  --==============================================================
    --
    --  INTERNALS:
    --
    --      PL/SQL function implement Val function from VB
    --
    --==============================================================
   IS
  
    v_num_left VARCHAR2(2000) := '';
    v_wrkstr   VARCHAR2(2000);
    v_return   NUMBER;
  
  BEGIN
    v_wrkstr := ltrim(p_string);
    FOR v_ii IN 1 .. length(v_wrkstr) LOOP
      IF is_number(substr(v_wrkstr, v_ii, 1)) = 0 THEN
        v_num_left := v_num_left || substr(v_wrkstr, v_ii, 1);
      ELSE
        v_return := to_number(v_num_left);
        RETURN(v_return);
      END IF;
    END LOOP;
    v_return := to_number(v_num_left);
    RETURN(v_return);
  
  END vb_val;
  ---------------------------------------------------------------
  FUNCTION find_mod10_digit(v_correct_tilde_string IN VARCHAR2) RETURN NUMBER
  
   IS
    v_remainder          PLS_INTEGER := 0;
    v_m10_factor         NUMBER := 3;
    v_m10_weighted_total NUMBER := 0;
    v_m10i               NUMBER := 0;
    v_hex2               NUMBER;
    v_i                  PLS_INTEGER := 0;
  BEGIN
  
    v_length := length(v_correct_tilde_string);
  
    v_m10i := v_length;
    WHILE v_m10i > 0
    -- FOR v_i in 1..v_m10i
     LOOP
    
      v_m10_weighted_total := v_m10_weighted_total +
                              (substr(v_correct_tilde_string, v_m10i, 1) *
                              v_m10_factor);
      v_m10_factor         := 4 - v_m10_factor;
      v_m10i               := v_m10i - 1;
    
    END LOOP;
  
    v_remainder := MOD(v_m10_weighted_total, 10);
  
    IF (v_remainder = 0) THEN
    
      v_return := chr(48);
      RETURN(v_return);
    ELSE
      v_return := chr((10 - v_remainder) + 48);
      RETURN(v_return);
    END IF;
  END find_mod10_digit;

END idautomation_uni;
/
