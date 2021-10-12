CREATE OR REPLACE PACKAGE BODY xx_bpel_fnd_request_wrapper
--------------------------------------------------------------------
--  name:              XX_BPEL_FND_REQUEST_WRAPPER
--  create by:         YUVAL TAL    
--  Revision:          1.0
--  creation date:     2.11.14
--------------------------------------------------------------------
--  purpose :          CHANGE 0033357  - Create Inbound Journal Interface from Concur
--                     sql generated by bpel for use of soa integration
--                      do not add any extra code !!!!!!!!
--modification history
--------------------------------------------------------------------
--  ver   date               name         desc
--  1.0   2.11.14            yuval tal    CHANGE 0033357  - Create Inbound Journal Interface from Concur

 IS
  PROCEDURE submit_request(request_id     OUT NUMBER,
                           return_code    OUT VARCHAR2,
                           return_message OUT VARCHAR2,
                           application    IN VARCHAR2 DEFAULT NULL,
                           program        IN VARCHAR2 DEFAULT NULL,
                           description    IN VARCHAR2 DEFAULT NULL,
                           start_time     IN VARCHAR2 DEFAULT NULL,
                           sub_request    IN INTEGER,
                           argument1      IN VARCHAR2 DEFAULT chr(0),
                           argument2      IN VARCHAR2 DEFAULT chr(0),
                           argument3      IN VARCHAR2 DEFAULT chr(0),
                           argument4      IN VARCHAR2 DEFAULT chr(0),
                           argument5      IN VARCHAR2 DEFAULT chr(0),
                           argument6      IN VARCHAR2 DEFAULT chr(0),
                           argument7      IN VARCHAR2 DEFAULT chr(0),
                           argument8      IN VARCHAR2 DEFAULT chr(0),
                           argument9      IN VARCHAR2 DEFAULT chr(0),
                           argument10     IN VARCHAR2 DEFAULT chr(0),
                           argument11     IN VARCHAR2 DEFAULT chr(0),
                           argument12     IN VARCHAR2 DEFAULT chr(0),
                           argument13     IN VARCHAR2 DEFAULT chr(0),
                           argument14     IN VARCHAR2 DEFAULT chr(0),
                           argument15     IN VARCHAR2 DEFAULT chr(0),
                           argument16     IN VARCHAR2 DEFAULT chr(0),
                           argument17     IN VARCHAR2 DEFAULT chr(0),
                           argument18     IN VARCHAR2 DEFAULT chr(0),
                           argument19     IN VARCHAR2 DEFAULT chr(0),
                           argument20     IN VARCHAR2 DEFAULT chr(0),
                           argument21     IN VARCHAR2 DEFAULT chr(0),
                           argument22     IN VARCHAR2 DEFAULT chr(0),
                           argument23     IN VARCHAR2 DEFAULT chr(0),
                           argument24     IN VARCHAR2 DEFAULT chr(0),
                           argument25     IN VARCHAR2 DEFAULT chr(0),
                           argument26     IN VARCHAR2 DEFAULT chr(0),
                           argument27     IN VARCHAR2 DEFAULT chr(0),
                           argument28     IN VARCHAR2 DEFAULT chr(0),
                           argument29     IN VARCHAR2 DEFAULT chr(0),
                           argument30     IN VARCHAR2 DEFAULT chr(0),
                           argument31     IN VARCHAR2 DEFAULT chr(0),
                           argument32     IN VARCHAR2 DEFAULT chr(0),
                           argument33     IN VARCHAR2 DEFAULT chr(0),
                           argument34     IN VARCHAR2 DEFAULT chr(0),
                           argument35     IN VARCHAR2 DEFAULT chr(0),
                           argument36     IN VARCHAR2 DEFAULT chr(0),
                           argument37     IN VARCHAR2 DEFAULT chr(0),
                           argument38     IN VARCHAR2 DEFAULT chr(0),
                           argument39     IN VARCHAR2 DEFAULT chr(0),
                           argument40     IN VARCHAR2 DEFAULT chr(0),
                           argument41     IN VARCHAR2 DEFAULT chr(0),
                           argument42     IN VARCHAR2 DEFAULT chr(0),
                           argument43     IN VARCHAR2 DEFAULT chr(0),
                           argument44     IN VARCHAR2 DEFAULT chr(0),
                           argument45     IN VARCHAR2 DEFAULT chr(0),
                           argument46     IN VARCHAR2 DEFAULT chr(0),
                           argument47     IN VARCHAR2 DEFAULT chr(0),
                           argument48     IN VARCHAR2 DEFAULT chr(0),
                           argument49     IN VARCHAR2 DEFAULT chr(0),
                           argument50     IN VARCHAR2 DEFAULT chr(0),
                           argument51     IN VARCHAR2 DEFAULT chr(0),
                           argument52     IN VARCHAR2 DEFAULT chr(0),
                           argument53     IN VARCHAR2 DEFAULT chr(0),
                           argument54     IN VARCHAR2 DEFAULT chr(0),
                           argument55     IN VARCHAR2 DEFAULT chr(0),
                           argument56     IN VARCHAR2 DEFAULT chr(0),
                           argument57     IN VARCHAR2 DEFAULT chr(0),
                           argument58     IN VARCHAR2 DEFAULT chr(0),
                           argument59     IN VARCHAR2 DEFAULT chr(0),
                           argument60     IN VARCHAR2 DEFAULT chr(0),
                           argument61     IN VARCHAR2 DEFAULT chr(0),
                           argument62     IN VARCHAR2 DEFAULT chr(0),
                           argument63     IN VARCHAR2 DEFAULT chr(0),
                           argument64     IN VARCHAR2 DEFAULT chr(0),
                           argument65     IN VARCHAR2 DEFAULT chr(0),
                           argument66     IN VARCHAR2 DEFAULT chr(0),
                           argument67     IN VARCHAR2 DEFAULT chr(0),
                           argument68     IN VARCHAR2 DEFAULT chr(0),
                           argument69     IN VARCHAR2 DEFAULT chr(0),
                           argument70     IN VARCHAR2 DEFAULT chr(0),
                           argument71     IN VARCHAR2 DEFAULT chr(0),
                           argument72     IN VARCHAR2 DEFAULT chr(0),
                           argument73     IN VARCHAR2 DEFAULT chr(0),
                           argument74     IN VARCHAR2 DEFAULT chr(0),
                           argument75     IN VARCHAR2 DEFAULT chr(0),
                           argument76     IN VARCHAR2 DEFAULT chr(0),
                           argument77     IN VARCHAR2 DEFAULT chr(0),
                           argument78     IN VARCHAR2 DEFAULT chr(0),
                           argument79     IN VARCHAR2 DEFAULT chr(0),
                           argument80     IN VARCHAR2 DEFAULT chr(0),
                           argument81     IN VARCHAR2 DEFAULT chr(0),
                           argument82     IN VARCHAR2 DEFAULT chr(0),
                           argument83     IN VARCHAR2 DEFAULT chr(0),
                           argument84     IN VARCHAR2 DEFAULT chr(0),
                           argument85     IN VARCHAR2 DEFAULT chr(0),
                           argument86     IN VARCHAR2 DEFAULT chr(0),
                           argument87     IN VARCHAR2 DEFAULT chr(0),
                           argument88     IN VARCHAR2 DEFAULT chr(0),
                           argument89     IN VARCHAR2 DEFAULT chr(0),
                           argument90     IN VARCHAR2 DEFAULT chr(0),
                           argument91     IN VARCHAR2 DEFAULT chr(0),
                           argument92     IN VARCHAR2 DEFAULT chr(0),
                           argument93     IN VARCHAR2 DEFAULT chr(0),
                           argument94     IN VARCHAR2 DEFAULT chr(0),
                           argument95     IN VARCHAR2 DEFAULT chr(0),
                           argument96     IN VARCHAR2 DEFAULT chr(0),
                           argument97     IN VARCHAR2 DEFAULT chr(0),
                           argument98     IN VARCHAR2 DEFAULT chr(0),
                           argument99     IN VARCHAR2 DEFAULT chr(0),
                           argument100    IN VARCHAR2 DEFAULT chr(0)) IS
    l_sub_request BOOLEAN := FALSE;
  BEGIN
    l_sub_request := sys.sqljutl.int2bool(sub_request);
    request_id    := fnd_request.submit_request(application, program, description, start_time, l_sub_request, argument1, argument2, argument3, argument4, argument5, argument6, argument7, argument8, argument9, argument10, argument11, argument12, argument13, argument14, argument15, argument16, argument17, argument18, argument19, argument20, argument21, argument22, argument23, argument24, argument25, argument26, argument27, argument28, argument29, argument30, argument31, argument32, argument33, argument34, argument35, argument36, argument37, argument38, argument39, argument40, argument41, argument42, argument43, argument44, argument45, argument46, argument47, argument48, argument49, argument50, argument51, argument52, argument53, argument54, argument55, argument56, argument57, argument58, argument59, argument60, argument61, argument62, argument63, argument64, argument65, argument66, argument67, argument68, argument69, argument70, argument71, argument72, argument73, argument74, argument75, argument76, argument77, argument78, argument79, argument80, argument81, argument82, argument83, argument84, argument85, argument86, argument87, argument88, argument89, argument90, argument91, argument92, argument93, argument94, argument95, argument96, argument97, argument98, argument99, argument100);
    IF request_id = 0 THEN
      return_code    := '2';
      return_message := fnd_message.get;
    ELSE
      return_code := '0';
    END IF;
  END submit_request;
END;
/