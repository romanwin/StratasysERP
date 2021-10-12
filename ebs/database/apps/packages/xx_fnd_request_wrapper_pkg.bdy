CREATE OR REPLACE PACKAGE BODY xx_fnd_request_wrapper_pkg
--------------------------------------------------------------------
--  name:              xx_fnd_request_wrapper_pkg
--  create by:         YUVAL TAL
--  Revision:          1.0
--  creation date:     28.2.18
--------------------------------------------------------------------
--  purpose :          general package for submiting prog from soa
--  modification history
--------------------------------------------------------------------
--  ver   date         name         desc
--    1.0  28.2.18      yuval tal    CHG0042196 - price book generation
--    1.0  6.12.20      yuval tal     CHG0048579 - OIC  intergration - plsql modifications  add case with ~ to be translate to null

 IS
  PROCEDURE submit_request(p_request_id          OUT NUMBER,
		   p_return_code         OUT VARCHAR2,
		   p_return_message      OUT VARCHAR2,
		   p_user_name           IN VARCHAR2,
		   p_responsibility_name IN VARCHAR2,
		   p_application         IN VARCHAR2,
		   p_program             IN VARCHAR2,
		   p_description         IN VARCHAR2 DEFAULT NULL,
		   p_start_time          IN VARCHAR2 DEFAULT NULL,
		   p_sub_request         IN INTEGER,
		   p_argument1           IN VARCHAR2 DEFAULT chr(0),
		   p_argument2           IN VARCHAR2 DEFAULT chr(0),
		   p_argument3           IN VARCHAR2 DEFAULT chr(0),
		   p_argument4           IN VARCHAR2 DEFAULT chr(0),
		   p_argument5           IN VARCHAR2 DEFAULT chr(0),
		   p_argument6           IN VARCHAR2 DEFAULT chr(0),
		   p_argument7           IN VARCHAR2 DEFAULT chr(0),
		   p_argument8           IN VARCHAR2 DEFAULT chr(0),
		   p_argument9           IN VARCHAR2 DEFAULT chr(0),
		   p_argument10          IN VARCHAR2 DEFAULT chr(0),
		   p_argument11          IN VARCHAR2 DEFAULT chr(0),
		   p_argument12          IN VARCHAR2 DEFAULT chr(0),
		   p_argument13          IN VARCHAR2 DEFAULT chr(0),
		   p_argument14          IN VARCHAR2 DEFAULT chr(0),
		   p_argument15          IN VARCHAR2 DEFAULT chr(0),
		   p_argument16          IN VARCHAR2 DEFAULT chr(0),
		   p_argument17          IN VARCHAR2 DEFAULT chr(0),
		   p_argument18          IN VARCHAR2 DEFAULT chr(0),
		   p_argument19          IN VARCHAR2 DEFAULT chr(0),
		   p_argument20          IN VARCHAR2 DEFAULT chr(0),
		   p_argument21          IN VARCHAR2 DEFAULT chr(0),
		   p_argument22          IN VARCHAR2 DEFAULT chr(0),
		   p_argument23          IN VARCHAR2 DEFAULT chr(0),
		   p_argument24          IN VARCHAR2 DEFAULT chr(0),
		   p_argument25          IN VARCHAR2 DEFAULT chr(0),
		   p_argument26          IN VARCHAR2 DEFAULT chr(0),
		   p_argument27          IN VARCHAR2 DEFAULT chr(0),
		   p_argument28          IN VARCHAR2 DEFAULT chr(0),
		   p_argument29          IN VARCHAR2 DEFAULT chr(0),
		   p_argument30          IN VARCHAR2 DEFAULT chr(0),
		   p_argument31          IN VARCHAR2 DEFAULT chr(0),
		   p_argument32          IN VARCHAR2 DEFAULT chr(0),
		   p_argument33          IN VARCHAR2 DEFAULT chr(0),
		   p_argument34          IN VARCHAR2 DEFAULT chr(0),
		   p_argument35          IN VARCHAR2 DEFAULT chr(0),
		   p_argument36          IN VARCHAR2 DEFAULT chr(0),
		   p_argument37          IN VARCHAR2 DEFAULT chr(0),
		   p_argument38          IN VARCHAR2 DEFAULT chr(0),
		   p_argument39          IN VARCHAR2 DEFAULT chr(0),
		   p_argument40          IN VARCHAR2 DEFAULT chr(0),
		   p_argument41          IN VARCHAR2 DEFAULT chr(0),
		   p_argument42          IN VARCHAR2 DEFAULT chr(0),
		   p_argument43          IN VARCHAR2 DEFAULT chr(0),
		   p_argument44          IN VARCHAR2 DEFAULT chr(0),
		   p_argument45          IN VARCHAR2 DEFAULT chr(0),
		   p_argument46          IN VARCHAR2 DEFAULT chr(0),
		   p_argument47          IN VARCHAR2 DEFAULT chr(0),
		   p_argument48          IN VARCHAR2 DEFAULT chr(0),
		   p_argument49          IN VARCHAR2 DEFAULT chr(0),
		   p_argument50          IN VARCHAR2 DEFAULT chr(0),
		   p_argument51          IN VARCHAR2 DEFAULT chr(0),
		   p_argument52          IN VARCHAR2 DEFAULT chr(0),
		   p_argument53          IN VARCHAR2 DEFAULT chr(0),
		   p_argument54          IN VARCHAR2 DEFAULT chr(0),
		   p_argument55          IN VARCHAR2 DEFAULT chr(0),
		   p_argument56          IN VARCHAR2 DEFAULT chr(0),
		   p_argument57          IN VARCHAR2 DEFAULT chr(0),
		   p_argument58          IN VARCHAR2 DEFAULT chr(0),
		   p_argument59          IN VARCHAR2 DEFAULT chr(0),
		   p_argument60          IN VARCHAR2 DEFAULT chr(0),
		   p_argument61          IN VARCHAR2 DEFAULT chr(0),
		   p_argument62          IN VARCHAR2 DEFAULT chr(0),
		   p_argument63          IN VARCHAR2 DEFAULT chr(0),
		   p_argument64          IN VARCHAR2 DEFAULT chr(0),
		   p_argument65          IN VARCHAR2 DEFAULT chr(0),
		   p_argument66          IN VARCHAR2 DEFAULT chr(0),
		   p_argument67          IN VARCHAR2 DEFAULT chr(0),
		   p_argument68          IN VARCHAR2 DEFAULT chr(0),
		   p_argument69          IN VARCHAR2 DEFAULT chr(0),
		   p_argument70          IN VARCHAR2 DEFAULT chr(0),
		   p_argument71          IN VARCHAR2 DEFAULT chr(0),
		   p_argument72          IN VARCHAR2 DEFAULT chr(0),
		   p_argument73          IN VARCHAR2 DEFAULT chr(0),
		   p_argument74          IN VARCHAR2 DEFAULT chr(0),
		   p_argument75          IN VARCHAR2 DEFAULT chr(0),
		   p_argument76          IN VARCHAR2 DEFAULT chr(0),
		   p_argument77          IN VARCHAR2 DEFAULT chr(0),
		   p_argument78          IN VARCHAR2 DEFAULT chr(0),
		   p_argument79          IN VARCHAR2 DEFAULT chr(0),
		   p_argument80          IN VARCHAR2 DEFAULT chr(0),
		   p_argument81          IN VARCHAR2 DEFAULT chr(0),
		   p_argument82          IN VARCHAR2 DEFAULT chr(0),
		   p_argument83          IN VARCHAR2 DEFAULT chr(0),
		   p_argument84          IN VARCHAR2 DEFAULT chr(0),
		   p_argument85          IN VARCHAR2 DEFAULT chr(0),
		   p_argument86          IN VARCHAR2 DEFAULT chr(0),
		   p_argument87          IN VARCHAR2 DEFAULT chr(0),
		   p_argument88          IN VARCHAR2 DEFAULT chr(0),
		   p_argument89          IN VARCHAR2 DEFAULT chr(0),
		   p_argument90          IN VARCHAR2 DEFAULT chr(0),
		   p_argument91          IN VARCHAR2 DEFAULT chr(0),
		   p_argument92          IN VARCHAR2 DEFAULT chr(0),
		   p_argument93          IN VARCHAR2 DEFAULT chr(0),
		   p_argument94          IN VARCHAR2 DEFAULT chr(0),
		   p_argument95          IN VARCHAR2 DEFAULT chr(0),
		   p_argument96          IN VARCHAR2 DEFAULT chr(0),
		   p_argument97          IN VARCHAR2 DEFAULT chr(0),
		   p_argument98          IN VARCHAR2 DEFAULT chr(0),
		   p_argument99          IN VARCHAR2 DEFAULT chr(0),
		   p_argument100         IN VARCHAR2 DEFAULT chr(0)) IS
    l_sub_request       BOOLEAN := FALSE;
    l_user_id           NUMBER;
    l_responsibility_id NUMBER;
    l_application_id    NUMBER;
  BEGIN
    BEGIN
      SELECT user_id
      INTO   l_user_id
      FROM   fnd_user
      WHERE  user_name = p_user_name;
    
    EXCEPTION
      WHEN OTHERS THEN
      
        p_return_code    := '2';
        p_return_message := 'Unable to find User Id from user name :' ||
		    p_user_name || ' ' || SQLERRM;
        RETURN;
    END;
  
    BEGIN
    
      SELECT t.responsibility_id,
	 t.application_id
      INTO   l_responsibility_id,
	 l_application_id
      FROM   fnd_responsibility_vl t
      WHERE  t.responsibility_key = p_responsibility_name;
    
    EXCEPTION
      WHEN OTHERS THEN
      
        p_return_code    := '2';
        p_return_message := 'Unable to find responsibility Id from responsibility name :' ||
		    p_responsibility_name || ' ' || SQLERRM;
        RETURN;
    END;
  
    fnd_global.apps_initialize(l_user_id,
		       l_responsibility_id,
		       l_application_id);
  
    l_sub_request := sys.sqljutl.int2bool(p_sub_request);
    p_request_id  := fnd_request.submit_request(p_application,
				p_program,
				p_description,
				p_start_time,
				l_sub_request,
				CASE p_argument1
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument1, chr(0))
				END,
				-- CHG0048579
				CASE p_argument2
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument2, chr(0))
				END,
				CASE p_argument3
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument3, chr(0))
				END,
				CASE p_argument4
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument4, chr(0))
				END,
				CASE p_argument5
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument5, chr(0))
				END,
				CASE p_argument6
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument6, chr(0))
				END,
				CASE p_argument7
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument7, chr(0))
				END,
				CASE p_argument8
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument8, chr(0))
				END,
				CASE p_argument9
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument9, chr(0))
				END,
				CASE p_argument10
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument10, chr(0))
				END,
				CASE p_argument11
				  WHEN '~' THEN
				   NULL
				  ELSE
				   nvl(p_argument11, chr(0))
				END,
				nvl(p_argument12, chr(0)),
				nvl(p_argument13, chr(0)),
				nvl(p_argument14, chr(0)),
				nvl(p_argument15, chr(0)),
				nvl(p_argument16, chr(0)),
				nvl(p_argument17, chr(0)),
				nvl(p_argument18, chr(0)),
				nvl(p_argument19, chr(0)),
				nvl(p_argument20, chr(0)),
				nvl(p_argument21, chr(0)),
				nvl(p_argument22, chr(0)),
				nvl(p_argument23, chr(0)),
				nvl(p_argument24, chr(0)),
				nvl(p_argument25, chr(0)),
				nvl(p_argument26, chr(0)),
				nvl(p_argument27, chr(0)),
				nvl(p_argument28, chr(0)),
				nvl(p_argument29, chr(0)),
				nvl(p_argument30, chr(0)),
				nvl(p_argument31, chr(0)),
				nvl(p_argument32, chr(0)),
				nvl(p_argument33, chr(0)),
				nvl(p_argument34, chr(0)),
				nvl(p_argument35, chr(0)),
				nvl(p_argument36, chr(0)),
				nvl(p_argument37, chr(0)),
				nvl(p_argument38, chr(0)),
				nvl(p_argument39, chr(0)),
				nvl(p_argument40, chr(0)),
				nvl(p_argument41, chr(0)),
				nvl(p_argument42, chr(0)),
				nvl(p_argument43, chr(0)),
				nvl(p_argument44, chr(0)),
				nvl(p_argument45, chr(0)),
				nvl(p_argument46, chr(0)),
				nvl(p_argument47, chr(0)),
				nvl(p_argument48, chr(0)),
				nvl(p_argument49, chr(0)),
				nvl(p_argument50, chr(0)),
				nvl(p_argument51, chr(0)),
				nvl(p_argument52, chr(0)),
				nvl(p_argument53, chr(0)),
				nvl(p_argument54, chr(0)),
				nvl(p_argument55, chr(0)),
				nvl(p_argument56, chr(0)),
				nvl(p_argument57, chr(0)),
				nvl(p_argument58, chr(0)),
				nvl(p_argument59, chr(0)),
				nvl(p_argument60, chr(0)),
				nvl(p_argument61, chr(0)),
				nvl(p_argument62, chr(0)),
				nvl(p_argument63, chr(0)),
				nvl(p_argument64, chr(0)),
				nvl(p_argument65, chr(0)),
				nvl(p_argument66, chr(0)),
				nvl(p_argument67, chr(0)),
				nvl(p_argument68, chr(0)),
				nvl(p_argument69, chr(0)),
				nvl(p_argument70, chr(0)),
				nvl(p_argument71, chr(0)),
				nvl(p_argument72, chr(0)),
				nvl(p_argument73, chr(0)),
				nvl(p_argument74, chr(0)),
				nvl(p_argument75, chr(0)),
				nvl(p_argument76, chr(0)),
				nvl(p_argument77, chr(0)),
				nvl(p_argument78, chr(0)),
				nvl(p_argument79, chr(0)),
				nvl(p_argument80, chr(0)),
				nvl(p_argument81, chr(0)),
				nvl(p_argument82, chr(0)),
				nvl(p_argument83, chr(0)),
				nvl(p_argument84, chr(0)),
				nvl(p_argument85, chr(0)),
				nvl(p_argument86, chr(0)),
				nvl(p_argument87, chr(0)),
				nvl(p_argument88, chr(0)),
				nvl(p_argument89, chr(0)),
				nvl(p_argument90, chr(0)),
				nvl(p_argument91, chr(0)),
				nvl(p_argument92, chr(0)),
				nvl(p_argument93, chr(0)),
				nvl(p_argument94, chr(0)),
				nvl(p_argument95, chr(0)),
				nvl(p_argument96, chr(0)),
				nvl(p_argument97, chr(0)),
				nvl(p_argument98, chr(0)),
				nvl(p_argument99, chr(0)),
				nvl(p_argument100, chr(0)));
  
    COMMIT;
    IF p_request_id = 0 THEN
      p_return_code    := '2';
      p_return_message := fnd_message.get;
    ELSE
      p_return_code := '0';
    END IF;
  
  END submit_request;
END;
/
