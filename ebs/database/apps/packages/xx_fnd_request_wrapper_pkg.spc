CREATE OR REPLACE PACKAGE xx_fnd_request_wrapper_pkg
--------------------------------------------------------------------
--  name:              XX_BPEL_FND_REQUEST_WRAPPER
--  create by:         YUVAL TAL
--  Revision:          1.0
--  creation date:     28.2.18
--------------------------------------------------------------------
--  purpose :          general package for submiting prog from soa
--modification history
--------------------------------------------------------------------
--  ver   date               name         desc
--    1.0  28.2.18      yuval tal    CHG0042196 - price book generation
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
		   p_argument100         IN VARCHAR2 DEFAULT chr(0));

END;
/