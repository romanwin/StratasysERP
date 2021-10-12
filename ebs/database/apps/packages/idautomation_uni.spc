CREATE OR REPLACE PACKAGE idautomation_uni

--===============================================================
--? Copyright, 2008 IDAutomation.com, Inc. All rights reserved.
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
 IS

  -----------------------------------------------------------------------
  -- Public type declarations
  -----------------------------------------------------------------------

  -----------------------------------------------------------------------
  -- Public variable/constant declarations
  -----------------------------------------------------------------------

  -----------------------------------------------------------------------
  -- Public procedure/function declarations
  -----------------------------------------------------------------------

  FUNCTION i2of5(p_number            IN VARCHAR2,
                 include_check_digit IN BOOLEAN,
                 n_dimension         IN NUMBER) RETURN VARCHAR2;
  --==============================================================
  --
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function encodes a number into the 2of5 barcode format
  --      and returns the digits to display the barcode.
  --
  --  FORMAL PARAMETERS:
  --
  --      p_string : number you like to display
  --      include_check_digit: T or F to display check character
  --      n_dimension:  changes thickness of bars
  --      bar_height :  changes the height of the barcode
  --
  --  EXCEPTIONS:
  --

  FUNCTION code39(p_string            IN VARCHAR2,
                  include_check_digit IN BOOLEAN,
                  n_dimension         IN NUMBER) RETURN VARCHAR2;
  --==============================================================
  --
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function encodes a number into the Code39 barcode format
  --      and returns the digits to display the barcode.
  --
  --  FORMAL PARAMETERS:
  --
  --      p_string : number you like to display
  --      include_check_digit: T or F to display check character
  --      n_dimension:  changes thickness of bars
  --      bar_height :  changes the height of the barcode
  --
  --  EXCEPTIONS:
  --

  --

  FUNCTION code128a(p_string IN VARCHAR2) RETURN VARCHAR2;
  --==============================================================
  --
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function encodes a string into the 128A barcode format
  --      and returns the digits to display the barcode.
  --
  --  FORMAL PARAMETERS:
  --
  --      p_string : string you like to display
  --      bar_height :  changes the height of the barcode
  --  EXCEPTIONS:
  --
  --

  FUNCTION code128b(p_string IN VARCHAR2) RETURN VARCHAR2;
  --==============================================================
  --
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function encodes a string into the 128B barcode format
  --      and returns the digits to display the barcode.
  --
  --  FORMAL PARAMETERS:
  --
  --      p_string : string you like to display
  --      bar_height :  changes the height of the barcode
  --  EXCEPTIONS:
  --

  FUNCTION code128c(p_string IN VARCHAR2) RETURN VARCHAR2;
  --================================================================
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function encodes a string into the 128C barcode format
  --      and returns the digits to display the barcode.
  --
  --  FORMAL PARAMETERS:
  --
  --      p_string : string you like to display
  --      bar_height :  changes the height of the barcode
  --  EXCEPTIONS:
  --

  FUNCTION code128(p_string IN VARCHAR2, apply_tilde IN BOOLEAN)
    RETURN VARCHAR2;
  --============================================================================
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function encodes a string into the 128A barcode format
  --      and returns the digits to display the barcode.
  --
  --  FORMAL PARAMETERS:
  --
  --      p_string : number you like to display
  --      apply_tilde:  apply tilde parameter
  --      bar_height :  changes the height of the barcode
  --  EXCEPTIONS:
  --

  FUNCTION is_number(p_string IN VARCHAR2) RETURN PLS_INTEGER;
  --==============================================================
  --
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function check if input string is number
  --      if true give back 0
  --      if false give back 1
  --
  --  FORMAL PARAMETERS:
  --
  --      p_string : string you like to check
  --
  --  EXCEPTIONS:
  --

  FUNCTION vb_val(p_string IN VARCHAR2) RETURN NUMBER;
  --==============================================================
  --
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function implements Val VB function
  --      the leading blanks are removed from the input string
  --      gives back the number value from the string
  --
  --  FORMAL PARAMETERS:
  --
  --      p_string : string from which you like to take a number value
  --
  --  EXCEPTIONS:
  --

  FUNCTION find_mod10_digit(v_correct_tilde_string IN VARCHAR2) RETURN NUMBER;

  --==============================================================
  --
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function implements Mode10 Check Digit
  --
  --
  --
  --  FORMAL PARAMETERS:
  --
  --      v_correct_tilde_string : string from which you will calculate check digit
  --
  --  EXCEPTIONS:
  --

  FUNCTION codabar(p_string     IN VARCHAR2,
                   codabarstart IN VARCHAR2,
                   codabarstop  IN VARCHAR2,
                   n_dimension  IN NUMBER) RETURN VARCHAR2;
  --==============================================================
  --
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function encodes a number into the CODABAR barcode format
  --      and returns the digits to display the barcode.
  --
  --  FORMAL PARAMETERS:
  --
  --      p_string : number you like to display
  --      codabarstart: is start character
  --      codabarstop:  is stop  character
  --      n_dimension:  changes thickness of bars
  --      bar_height :  changes the height of the barcode
  --
  --  EXCEPTIONS:
  --

  FUNCTION postnet(p_string IN VARCHAR2, include_check_digit IN BOOLEAN)
    RETURN VARCHAR2;
  --==============================================================
  --
  --  FUNCTIONAL DESCRIPTION:
  --
  --      This function encodes a 5 digit, 9 digit or 11 digit number
  --      and returns the digits to display the barcode.
  --
  --  FORMAL PARAMETERS:
  --
  --      p_string : number you like to display
  --      include_check_digit: T or F to display check character
  --  EXCEPTIONS:
  --

  FUNCTION planet(p_string IN VARCHAR2, include_check_digit IN BOOLEAN)
    RETURN VARCHAR2;
  --==============================================================
--
--  FUNCTIONAL DESCRIPTION:
--
--      This function encodes a 5 digit, 9 digit or 11 digit number
--      and returns the digits to display the barcode.
--
--  FORMAL PARAMETERS:
--
--      p_string : number you like to display
--      include_check_digit: T or F to display check character
--  EXCEPTIONS:
--

END;
/
