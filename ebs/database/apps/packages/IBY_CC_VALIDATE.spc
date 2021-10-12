CREATE OR REPLACE PACKAGE IBY_CC_VALIDATE AUTHID CURRENT_USER AS
/* $Header: ibyccvls.pls 120.5.12010000.4 2009/06/16 09:15:44 lyanamal ship $ */

-------------------------------------------------------------------------
	--**Defining all DataStructures required by the APIs**--

-------------------------------------------------------------------------


--OUTPUT DataStructures
--1. Credit Card Type: identifies the type of the credit card number

SUBTYPE CCType IS NUMBER;


--CONSTANTS

--1. Credit Card Type Constants

c_InvalidCC CONSTANT CCType := -1; -- invalid; fits pattern but fails test
c_UnknownCC CONSTANT CCType := 0; -- fits no known pattern
c_McCC CONSTANT CCType := 1; -- Master Card
c_VisaCC CONSTANT CCType := 2; -- Visa
c_AmexCC CONSTANT CCType := 3; -- American Express
c_DClubCC CONSTANT CCType := 4; -- Diner's Club
c_DiscoverCC CONSTANT CCType := 5; -- The Discover Card
c_EnrouteCC CONSTANT CCType := 6; -- Enroute
c_JCBCC CONSTANT CCType := 7; -- JCB

G_CARD_TYPE_UNKNOWN CONSTANT VARCHAR2(30) := 'UNKNOWN';

--2. typical credit card number filler characters; i.e. characters
---- interspersed in the number that are used to seperate number
---- blocks for readability and can safely be ignored; each
---- character in the string represents one acceptable filler character

c_FillerChars CONSTANT VARCHAR2(2) := ' -';

---------------------------------------------------------------
                      -- API Signatures--
---------------------------------------------------------------

--1.	name:		StripCC
----
----	purpose:	strips the CC number of all filler characters
----
----	args:
----	 p_cc_id	the credit card number, with possible filler chars
----	 p_fill_chars 	string where each character specifies a possible
----			filler character; e.g. '* -' would allow hyphens,
----			astericks, and spaces as filler characters
----
----	return:
----	 x_cc_id	the credit card number, stripped of all filler
----			chars so that it contains only digits

  PROCEDURE StripCC (	p_api_version		IN	NUMBER,
			p_init_msg_list		IN	VARCHAR2,
			p_cc_id 		IN 	VARCHAR2,
			p_fill_chars		IN	VARCHAR2,

			x_return_status		OUT NOCOPY VARCHAR2,
			x_msg_count		OUT NOCOPY NUMBER,
			x_msg_data		OUT NOCOPY VARCHAR2,
			x_cc_id 		OUT NOCOPY VARCHAR2
			);


--2.	name:		StripCC
----
----	purpose:	an overloaded version of the above function
----			which uses constant c_FillerChars to specify
----			what filler characters are allowed
----

  PROCEDURE StripCC (	p_api_version		IN	NUMBER,
			p_init_msg_list		IN	VARCHAR2,
			p_cc_id 		IN 	VARCHAR2,

			x_return_status		OUT NOCOPY VARCHAR2,
			x_msg_count		OUT NOCOPY NUMBER,
			x_msg_data		OUT NOCOPY VARCHAR2,
			x_cc_id 		OUT NOCOPY VARCHAR2
			);


--2.1   name:           StripCC
----
----    purpose:        function version of procedure 1
----
  FUNCTION StripCC ( p_cc_id IN VARCHAR2, p_fill_chars IN VARCHAR2 )
  RETURN VARCHAR2;


--3.	name:		GetCCType
----
----	purpose:	returns the type of a credit card number
----
----	args:
----	 p_cc_id	the credit card number, with NO!! filler chars
----
----
----	return:
----	 x_cc_type	the credit card type of the given credit card
----			number; if the credit card type matches no
----			known pattern then c_UnknownCC is returned;
----			if it matches a pattern but fails some test,
----			then c_InvalidCC is returned


  PROCEDURE GetCCType (	p_api_version		IN	NUMBER,
			p_init_msg_list		IN	VARCHAR2,
			p_cc_id 		IN 	VARCHAR2,

			x_return_status		OUT NOCOPY VARCHAR2,
			x_msg_count		OUT NOCOPY NUMBER,
			x_msg_data		OUT NOCOPY VARCHAR2,
			x_cc_type 		OUT NOCOPY CCType
			);

--4.	name:		ValidateCC
----
----	purpose:	indicates if a cc number, expiration date tuple
----			represents a valid, non-expired credit card account
----
----	args:
----	 p_cc_id	the credit card number, with NO!! filler chars
----	 p_expr_date	the expiration date of the credit card; note
----			that this date will be moved to the end of the
----			month it represents for the purposes of
----			determing expiration; i.e. 4/5/2000 -> 4/30/2000
----
----
----	return:
----	 x_cc_valid	true if and only if the credit card number is valid
----			and it has not expired
----


  PROCEDURE ValidateCC (p_api_version		IN	NUMBER,
			p_init_msg_list		IN	VARCHAR2,
			p_cc_id 		IN 	VARCHAR2,
			p_expr_date		IN	DATE,

			x_return_status		OUT NOCOPY VARCHAR2,
			x_msg_count		OUT NOCOPY NUMBER,
			x_msg_data		OUT NOCOPY VARCHAR2,
			x_cc_valid 		OUT NOCOPY BOOLEAN
			);


--5.	name:		ValidateCC
----                    Overloaded form returns a boolean,indicating whether
----                    the card is valid or not AND the credit card type.
----	purpose:	indicates if a cc number, expiration date tuple
----			represents a valid, non-expired credit card account
----
----	args:
----	 p_cc_id	the credit card number, with NO!! filler chars
----	 p_expr_date	the expiration date of the credit card; note
----			that this date will be moved to the end of the
----			month it represents for the purposes of
----			determing expiration; i.e. 4/5/2000 -> 4/30/2000
----
----
----	return:
----	 x_cc_valid	true if and only if the credit card number is valid
----			and it has not expired
----
----	 x_cc_type      The credit card type in String.It is one from lookup types
----                    defined for the type 'IBY_CARD_TYPES'.


  PROCEDURE ValidateCC (p_api_version		IN	NUMBER,
			p_init_msg_list		IN	VARCHAR2,
			p_cc_id 		IN 	VARCHAR2,
			p_expr_date		IN	DATE,

			x_return_status		OUT NOCOPY VARCHAR2,
			x_msg_count		OUT NOCOPY NUMBER,
			x_msg_data		OUT NOCOPY VARCHAR2,
			x_cc_valid 		OUT NOCOPY BOOLEAN,
			x_cc_type 		OUT NOCOPY VARCHAR2
			);



  --
  -- Name: Get_CC_Issuer_Range
  -- Purpose: Finds the card issuer and range for a particular
  --          credit card number
  -- Args:
  --       p_card_number => The credit card number; should already be
  --                        stripped of non-digit characters
  -- Return:
  --       x_card_issuer => The card issuer code; UNKNOWN if not a known
  --                        card number
  --       x_issuer_range => Range of the card number
  --
  PROCEDURE Get_CC_Issuer_Range
  (p_card_number     IN     iby_creditcard.ccnumber%TYPE,
   x_card_issuer     OUT NOCOPY iby_creditcard_issuers_b.card_issuer_code%TYPE,
   x_issuer_range    OUT NOCOPY iby_cc_issuer_ranges.cc_issuer_range_id%TYPE,
   x_card_prefix     OUT NOCOPY iby_cc_issuer_ranges.card_number_prefix%TYPE,
   x_digit_check     OUT NOCOPY iby_creditcard_issuers_b.digit_check_flag%TYPE
  );

  --
  -- Inline wrapper function for the above
  --
  FUNCTION Get_CC_Issuer_Range
  (p_card_number     IN     iby_creditcard.ccnumber%TYPE)
  RETURN NUMBER;

  FUNCTION CheckCCDigits( p_cc_id  IN VARCHAR2 ) RETURN NUMBER;


  -- FP Bug#8581161 FP:8352320
  -- Name: Get_CC_Issuer_Range - Overloading for multiple ranges
  -- Purpose: Finds the card issuer and range for a particular
  --          credit card number
  -- Args:
  --       p_card_number => The credit card number; should already be
  --                        stripped of non-digit characters
  -- Return:
  --       x_card_issuer => The card issuer code; UNKNOWN if not a known
  --                        card number
  --       x_issuer_range => Range of the card number
  --
  PROCEDURE Get_CC_Issuer_Range
  (p_card_number     IN     iby_creditcard.ccnumber%TYPE,
   x_card_issuer     OUT NOCOPY iby_creditcard_issuers_b.card_issuer_code%TYPE,
   x_issuer_range    OUT NOCOPY iby_cc_issuer_ranges.cc_issuer_range_id%TYPE,
   x_card_prefix     OUT NOCOPY iby_cc_issuer_ranges.card_number_prefix%TYPE,
   x_digit_check     OUT NOCOPY iby_creditcard_issuers_b.digit_check_flag%TYPE,
   p_card_type       IN iby_creditcard.card_issuer_code%TYPE
  );



END IBY_CC_VALIDATE;
/
