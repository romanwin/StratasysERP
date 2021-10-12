CREATE OR REPLACE PACKAGE BODY IBY_CC_VALIDATE AS
/* $Header: ibyccvlb.pls 120.5.12010000.6 2009/06/16 09:53:20 lyanamal ship $ */

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0                                 Seeded package body version
  --  1.1   31/08/2016    Sujoy Das       CHG0039336 - Changes in FUNCTION 'CheckCCDigits' for Credit Card Token brand display.
  -----------------------------------------------------------------------

-- *** Declaring global datatypes and variables ***


  FUNCTION CheckCCDigits( p_cc_id  IN VARCHAR2 ) RETURN NUMBER
  AS
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0                                 Seeded FUNCTION version
  --  1.1   31/08/2016    Sujoy Das       CHG0039336 - Changes for Credit Card Token brand display.
  -----------------------------------------------------------------------

	v_DigitSum	INTEGER		:=0;
	v_CCDigit	INTEGER		:=0;
	v_CCLen		INTEGER		:=0;
  BEGIN
	-- START comment out for CHG0039336
  /*v_CCLen:=LENGTH(p_cc_id);

	FOR v_Counter IN 1..v_CCLen LOOP

	  v_CCDigit := TO_NUMBER(SUBSTR(p_cc_id,v_CCLen-v_Counter+1,1));

	  -- every alternate digit beginning with the second one from the
	  -- right must be doubled and the resultant digits added together
	  --
	  IF MOD(v_Counter,2)=0 THEN
		--
		-- according to the algorithm, resulting digits must be
		-- added together; only an issue for #'s >=5
		IF v_CCDigit<5 THEN
		  v_CCDigit := v_CCDigit*2;
		ELSE
		  -- this function just happens to fit the algorithm
		  -- "double x and then add its digits together" for
		  -- all x >=5 and <=9
		  --
		  v_CCDigit := 1+2*(v_CCDigit-5);
		END IF;
	  END IF;
	  --DBMS_OUTPUT.PUT_LINE('digit value is : ' || v_CCDigit);
	  v_DigitSum := v_DigitSum + v_CCDigit;

	END LOOP;

	--DBMS_OUTPUT.PUT_LINE('digit sum is : ' || v_DigitSum);

	RETURN MOD(v_DigitSum,10); */ -- END comment out for CHG0039336
  
    RETURN 0; -- added for CHG0039336

  EXCEPTION
--	WHEN VALUE_ERROR THEN
	WHEN OTHERS THEN
		RETURN NULL;
  END CheckCCDigits;

/*
** This function returns the CC Type in String for the CC Type in
** number passed. It maps the constant defined for CC Type in this
** Package to ones in the LOOKUP Types for the type 'IBY_CARD_TYPES'.
*/

    FUNCTION getLookupCCType( p_cc_type IN NUMBER )
    RETURN VARCHAR2
    AS

    BEGIN

       IF( p_cc_type = 0 ) THEN
          RETURN 'UNKNOWN';
       ELSIF( p_cc_type = 1 ) THEN
          RETURN 'MASTERCARD';
       ELSIF( p_cc_type = 2 ) THEN
          RETURN 'VISA';
       ELSIF( p_cc_type = 3 ) THEN
          RETURN 'AMEX';
       ELSIF( p_cc_type = 4 ) THEN
          RETURN 'DINERS';
       ELSIF( p_cc_type = 5 ) THEN
          RETURN 'DISCOVER';
       ELSIF( p_cc_type = 6 ) THEN
          RETURN 'ENROUTE';
       ELSIF( p_cc_type = 7 ) THEN
          RETURN 'JCB';
       ELSE
          RETURN NULL;
       END IF;

    EXCEPTION
        WHEN OTHERS THEN
                RETURN NULL;
    END getLookupCCType;


    FUNCTION getIssuerCCType( p_cc_issuer IN VARCHAR2 )
    RETURN VARCHAR2
    AS

    BEGIN

       IF( p_cc_issuer = 'UNKNOWN' ) THEN
          RETURN 0;
       ELSIF( p_cc_issuer = 'INVALID' ) THEN
          RETURN c_InvalidCC;
       ELSIF( p_cc_issuer = 'MASTERCARD' ) THEN
          RETURN 1;
       ELSIF( p_cc_issuer = 'VISA' ) THEN
          RETURN 2;
       ELSIF( p_cc_issuer = 'AMEX' ) THEN
          RETURN 3;
       ELSIF( p_cc_issuer = 'DINERS' ) THEN
          RETURN 4;
       ELSIF( p_cc_issuer = 'DISCOVER' ) THEN
          RETURN 5;
       ELSIF( p_cc_issuer = 'ENROUTE' ) THEN
          RETURN 6;
       ELSIF( p_cc_issuer = 'JCB' ) THEN
          RETURN 7;
       ELSE
          RETURN NULL;
       END IF;

    END getIssuerCCType;

  PROCEDURE StripCC (	p_api_version		IN	NUMBER,
			p_init_msg_list		IN	VARCHAR2,
			p_cc_id 		IN 	VARCHAR2,
			p_fill_chars		IN	VARCHAR2,

			x_return_status		OUT NOCOPY VARCHAR2,
			x_msg_count		OUT NOCOPY NUMBER,
			x_msg_data		OUT NOCOPY VARCHAR2,
			x_cc_id 		OUT NOCOPY VARCHAR2
			)	AS

	c_Digits	CONSTANT VARCHAR2(10) 	:='0123456789';
	v_StrippedCC	VARCHAR2(100)		:='';
	v_CCChar	CHAR;
	v_FoundBadChar	BOOLEAN			:=FALSE;
  BEGIN
	FOR v_Counter IN 1..LENGTH(p_cc_id) LOOP
	  --
	  -- tests if a character is a digit
	  --
	  v_CCChar := SUBSTR(p_cc_id,v_Counter,1);

	  IF INSTR(c_Digits,v_CCChar)>0 THEN
		v_StrippedCC := v_StrippedCC || v_CCChar;
	  ELSIF INSTR(p_fill_chars,v_CCChar)>0 THEN
		NULL;
	  ELSE
		-- an illegal character found in the string
		--
		v_FoundBadChar:=TRUE;
		--DBMS_OUTPUT.PUT_LINE('bad char: ' || v_CCChar);
		EXIT;
	  END IF;
	END LOOP;

	IF v_FoundBadChar THEN
	  -- !!
	  -- do something useful here!!
	  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
	  x_cc_id := NULL;
	ELSE
	  x_return_status := FND_API.G_RET_STS_SUCCESS;
	  x_cc_id := v_StrippedCC;
	END IF;

	--DBMS_OUTPUT.PUT_LINE('stripped value is: ' || v_StrippedCC);

  EXCEPTION
	WHEN OTHERS THEN
	  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
	  x_cc_id := NULL;
  END StripCC;

  PROCEDURE StripCC (	p_api_version		IN	NUMBER,
			p_init_msg_list		IN	VARCHAR2,
			p_cc_id 		IN 	VARCHAR2,

			x_return_status		OUT NOCOPY VARCHAR2,
			x_msg_count		OUT NOCOPY NUMBER,
			x_msg_data		OUT NOCOPY VARCHAR2,
			x_cc_id 		OUT NOCOPY VARCHAR2
			)	AS

  BEGIN

	StripCC(p_api_version, p_init_msg_list, p_cc_id,
		c_FillerChars, x_return_status, x_msg_count,
		x_msg_data, x_cc_id );

  END StripCC;

  FUNCTION StripCC ( p_cc_id IN VARCHAR2, p_fill_chars IN VARCHAR2 )
  RETURN VARCHAR2
  IS
    c_Digits        CONSTANT VARCHAR2(10) :='0123456789';
    v_StrippedCC    VARCHAR2(100) := '';
    v_CCChar        CHAR;
    v_FoundBadChar  BOOLEAN :=FALSE;
    l_DBUG_MOD         VARCHAR2(100) :='IBY_CC_VALIDATE.Get_CC_Issuer_Range(6 params)';
  BEGIN

    iby_debug_pub.add('Enter',FND_LOG.LEVEL_STATEMENT,l_DBUG_MOD);

	FOR v_Counter IN 1..LENGTH(p_cc_id) LOOP
	  --
	  -- tests if a character is a digit
	  --
	  v_CCChar := SUBSTR(p_cc_id,v_Counter,1);


	  IF INSTR(c_Digits,v_CCChar)>0 THEN
		v_StrippedCC := v_StrippedCC || v_CCChar;
	  ELSIF INSTR(p_fill_chars,v_CCChar)>0 THEN
		NULL;
	  ELSE
		v_FoundBadChar:=TRUE;
		EXIT;
	  END IF;
	END LOOP;

	IF v_FoundBadChar THEN
         iby_debug_pub.add('Found bad char',FND_LOG.LEVEL_STATEMENT,l_DBUG_MOD);

          RETURN NULL;
	ELSE
	 RETURN v_StrippedCC;
	END IF;
    iby_debug_pub.add('Exit',FND_LOG.LEVEL_STATEMENT,l_DBUG_MOD);


    EXCEPTION
    WHEN OTHERS THEN
      iby_debug_pub.add('In Others Exception',FND_LOG.LEVEL_UNEXPECTED, l_DBUG_MOD);
      iby_debug_pub.add('Exception code='||SQLCODE,FND_LOG.LEVEL_UNEXPECTED,l_DBUG_MOD);
      iby_debug_pub.add('Exception message='||SQLERRM,FND_LOG.LEVEL_UNEXPECTED,l_DBUG_MOD);


  END StripCC;


  PROCEDURE GetCCType (	p_api_version		IN	NUMBER,
			p_init_msg_list		IN	VARCHAR2,
			p_cc_id 		IN 	VARCHAR2,

			x_return_status		OUT NOCOPY VARCHAR2,
			x_msg_count		OUT NOCOPY NUMBER,
			x_msg_data		OUT NOCOPY VARCHAR2,
			x_cc_type 		OUT NOCOPY CCType
			)	AS

	v_Length        INTEGER;
	v_DigitsOk	BOOLEAN;
        lx_card_issuer  iby_creditcard_issuers_b.card_issuer_code%TYPE;
        lx_range_id     iby_cc_issuer_ranges.cc_issuer_range_id%TYPE;
        lx_card_prefix  iby_cc_issuer_ranges.card_number_prefix%TYPE;
        lx_digit_check  iby_creditcard_issuers_b.digit_check_flag%TYPE;

  BEGIN
	x_return_status := FND_API.G_RET_STS_SUCCESS;

	IF (p_cc_id IS NULL) THEN
	  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
	  x_cc_type:=c_InvalidCC;
	  RETURN;
	END IF;

	v_Length:=LENGTH(p_cc_id);

	IF (v_Length <=0) THEN
	  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
	  x_cc_type:=c_InvalidCC;
	  RETURN;
	END IF;

        Get_CC_Issuer_Range
        (p_cc_id,lx_card_issuer,lx_range_id,lx_card_prefix,lx_digit_check);

        IF (lx_digit_check = 'Y') THEN
          v_DigitsOk:= CheckCCDigits(p_cc_id) = 0;
        ELSE
          v_DigitsOk:= TRUE;
        END IF;

	-- this means there were some non-digit characters
	-- in the credit card number
	--
	IF StripCC(p_cc_id,c_FillerChars) IS NULL THEN
	  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
	  x_cc_type:=c_InvalidCC;
	  RETURN;
	END IF;

        IF NOT v_DigitsOk THEN
	  x_cc_type:=c_InvalidCC;
        ELSE
          x_cc_type := getIssuerCCType(NVL(lx_card_issuer,'UNKNOWN'));
	END IF;

  EXCEPTION
	WHEN OTHERS THEN
	  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
	  x_cc_type:=c_InvalidCC;
  END GetCCType;


/*
** This is an overloaded function which returns, a boolean value -
** indicating whether the card is valid or not, AND CC type (in VARCHAR2)
** from the lookup types defined for type 'IBY_CARD_TYPES'
*/

  PROCEDURE ValidateCC (p_api_version		IN	NUMBER,
			p_init_msg_list		IN	VARCHAR2,
			p_cc_id 		IN 	VARCHAR2,
			p_expr_date		IN	DATE,

			x_return_status		OUT NOCOPY VARCHAR2,
			x_msg_count		OUT NOCOPY NUMBER,
			x_msg_data		OUT NOCOPY VARCHAR2,
			x_cc_valid 		OUT NOCOPY BOOLEAN,
			x_cc_type               OUT NOCOPY VARCHAR2
			)	AS

	v_CurrDate	DATE	:= SYSDATE();
	v_CardType	CCType;
	v_spread	REAL;
  BEGIN

	-- expr date is moved to the last day of the month it's on as
	-- most credit cards
	--
	v_spread:=MONTHS_BETWEEN(LAST_DAY(TRUNC(p_expr_date)),
		TRUNC(v_CurrDate));
	x_return_status := FND_API.G_RET_STS_SUCCESS;

	--DBMS_OUTPUT.PUT_LINE('Difference in time: ' || v_spread);
	IF v_spread >= 0 THEN

		GetCCType(p_api_version, p_init_msg_list, p_cc_id,
			x_return_status, x_msg_count, x_msg_data,
			v_CardType );
		--x_cc_valid:=(v_CardType<>c_InvalidCC); -- comment out for CHG0031464
		x_cc_valid := (1 = 1); -- added for CHG0031464
                x_cc_type := getLookupCCType( v_CardType );

		/* set the other out variables here */
	ELSE

		x_cc_valid:=FALSE;

		/* set the other out variables here */
	END IF;

  EXCEPTION
	WHEN OTHERS THEN
	  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
	  x_cc_valid:=FALSE;
  END ValidateCC;


/*
** This is an overloaded function which returns, a boolean value -
** indicating whether the card is valid or not.
*/

  PROCEDURE ValidateCC (p_api_version		IN	NUMBER,
			p_init_msg_list		IN	VARCHAR2,
			p_cc_id 		IN 	VARCHAR2,
			p_expr_date		IN	DATE,

			x_return_status		OUT NOCOPY VARCHAR2,
			x_msg_count		OUT NOCOPY NUMBER,
			x_msg_data		OUT NOCOPY VARCHAR2,
			x_cc_valid 		OUT NOCOPY BOOLEAN
			)	AS

        v_CC_Type       VARCHAR2(80);

  BEGIN

            ValidateCC (p_api_version       =>          p_api_version,
                        p_init_msg_list     =>          p_init_msg_list,
                        p_cc_id             =>          p_cc_id,
                        p_expr_date         =>          p_expr_date,
                        x_return_status     =>          x_return_status,
                        x_msg_count         =>          x_msg_count,
                        x_msg_data          =>          x_msg_data,
                        x_cc_valid          =>          x_cc_valid,
                        x_cc_type           =>          v_CC_Type
                        );

  EXCEPTION
	WHEN OTHERS THEN
	  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
	  x_cc_valid:=FALSE;

  END ValidateCC;

  PROCEDURE Get_CC_Issuer_Range
  (p_card_number     IN     iby_creditcard.ccnumber%TYPE,
   x_card_issuer     OUT NOCOPY iby_creditcard_issuers_b.card_issuer_code%TYPE,
   x_issuer_range    OUT NOCOPY iby_cc_issuer_ranges.cc_issuer_range_id%TYPE,
   x_card_prefix     OUT NOCOPY iby_cc_issuer_ranges.card_number_prefix%TYPE,
   x_digit_check     OUT NOCOPY iby_creditcard_issuers_b.digit_check_flag%TYPE
  )
  IS
    l_cc_number        iby_creditcard.ccnumber%TYPE;
    l_length           NUMBER;
    l_DBUG_MOD         VARCHAR2(100) :='IBY_CC_VALIDATE.Get_CC_Issuer_Range(5 params)';

  BEGIN

    iby_debug_pub.add('Enter',FND_LOG.LEVEL_STATEMENT,l_DBUG_MOD);

    iby_debug_pub.add('Calling  Get_CC_Issuer_Range (6 params)',FND_LOG.LEVEL_STATEMENT,l_DBUG_MOD);

    Get_CC_Issuer_Range(p_card_number,x_card_issuer,x_issuer_range,x_card_prefix,x_digit_check,null);

     iby_debug_pub.add('Exit',FND_LOG.LEVEL_STATEMENT,l_DBUG_MOD);

  END Get_CC_Issuer_Range;
--Bug 8581161: FP:8352320
PROCEDURE Get_CC_Issuer_Range
  (p_card_number     IN     iby_creditcard.ccnumber%TYPE,
   x_card_issuer     OUT NOCOPY iby_creditcard_issuers_b.card_issuer_code%TYPE,
   x_issuer_range    OUT NOCOPY iby_cc_issuer_ranges.cc_issuer_range_id%TYPE,
   x_card_prefix     OUT NOCOPY iby_cc_issuer_ranges.card_number_prefix%TYPE,
   x_digit_check     OUT NOCOPY iby_creditcard_issuers_b.digit_check_flag%TYPE,
   p_card_type       IN iby_creditcard.card_issuer_code%TYPE
  )
  IS
    l_cc_number        iby_creditcard.ccnumber%TYPE;
    l_length           NUMBER;
    l_DBUG_MOD         VARCHAR2(100) :='IBY_CC_VALIDATE.Get_CC_Issuer_Range(6 params)';

    CURSOR c_range
    (ci_card_number IN iby_creditcard.ccnumber%TYPE,
     ci_card_len IN NUMBER,
     ci_card_type IN iby_creditcard.card_issuer_code%TYPE)
    IS
      SELECT cc_issuer_range_id, r.card_issuer_code,
        card_number_prefix, NVL(digit_check_flag,'N')
      FROM iby_cc_issuer_ranges r, iby_creditcard_issuers_b i
      WHERE (card_number_length = ci_card_len)
        AND (INSTR(ci_card_number,card_number_prefix) = 1)
        AND (r.card_issuer_code = i.card_issuer_code)
	AND r.card_issuer_code = NVL(ci_card_type, r.card_issuer_code)
        ORDER BY r.last_updated_by DESC,
	  r.last_update_date DESC;

  BEGIN
      iby_debug_pub.add('Enter',FND_LOG.LEVEL_STATEMENT,l_DBUG_MOD);

    IF (c_range%ISOPEN) THEN CLOSE c_range; END IF;

    l_cc_number :=
      IBY_CC_VALIDATE.StripCC(p_card_number,IBY_CC_VALIDATE.c_FillerChars);

    l_length := LENGTH(l_cc_number);


    IF (l_length > 30) THEN
      x_card_issuer := 'INVALID';
    END IF;

 /*
** Removed all hard coded values.
** We alwasy refer to DB to get the output values.
** Bug# 8581161
*/


    OPEN c_range(l_cc_number,l_length,p_card_type);
    FETCH c_range INTO x_issuer_range, x_card_issuer,
      x_card_prefix, x_digit_check;
    CLOSE c_range;

    IF (x_card_issuer IS NULL) THEN
      x_card_issuer := 'UNKNOWN';
      x_digit_check := 'N';
    END IF;

       iby_debug_pub.add('Exit',FND_LOG.LEVEL_STATEMENT,l_DBUG_MOD);

  EXCEPTION
    WHEN OTHERS THEN
      iby_debug_pub.add('In Others Exception',FND_LOG.LEVEL_UNEXPECTED, l_DBUG_MOD);
      iby_debug_pub.add('Exception code='||SQLCODE,FND_LOG.LEVEL_UNEXPECTED,l_DBUG_MOD);
      iby_debug_pub.add('Exception message='||SQLERRM,FND_LOG.LEVEL_UNEXPECTED,l_DBUG_MOD);



  END Get_CC_Issuer_Range;

  FUNCTION Get_CC_Issuer_Range
  (p_card_number     IN     iby_creditcard.ccnumber%TYPE)
  RETURN NUMBER
  IS
    lx_card_issuer     iby_creditcard_issuers_b.card_issuer_code%TYPE;
    lx_issuer_range    iby_cc_issuer_ranges.cc_issuer_range_id%TYPE;
    lx_card_prefix     iby_cc_issuer_ranges.card_number_prefix%TYPE;
    lx_digit_check     iby_creditcard_issuers_b.digit_check_flag%TYPE;
  BEGIN
    Get_CC_Issuer_Range(p_card_number,lx_card_issuer,lx_issuer_range,
      lx_card_prefix,lx_digit_check);
    RETURN lx_issuer_range;
  END Get_CC_Issuer_Range;

END IBY_CC_VALIDATE;
/
