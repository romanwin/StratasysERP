CREATE OR REPLACE PACKAGE XXCONV_URL_ATTACHMENTS_PKG IS
  PROCEDURE UPLOAD_URL_ATTACHMENT_FOR_ITEM(ERRBUF                      OUT VARCHAR2,
                                           ERRCODE                     OUT VARCHAR2,
                                           P_LOCATION                  IN VARCHAR2,
                                           P_FILENAME                  IN VARCHAR2,
                                           P_IGNORE_FIRST_HEADERS_LINE IN VARCHAR2 DEFAULT 'Y',
                                           P_VALIDATE_ONLY_FLAG        IN VARCHAR2 DEFAULT 'Y',
                                           P_ORGANIZATION_ID           IN NUMBER,
                                           P_INVENTORY_ITEM_ID         IN NUMBER,
                                           P_DATATYPE_ID               IN NUMBER,
                                           P_CATEGORY_ID               IN NUMBER);
  FUNCTION GET_FIELD_FROM_UTL_FILE_LINE(P_LINE_STR     IN VARCHAR2,
                                        P_FIELD_NUMBER IN NUMBER)
    RETURN VARCHAR2;
  FUNCTION CREATE_URL_ATTACHMENT_FOR_ITEM(P_CATEGORY_ID          IN NUMBER,
                                          P_SEGMENT1             IN VARCHAR2,
                                          P_DATATYPE_ID          IN NUMBER,
                                          P_URL                  IN VARCHAR2,
                                          P_FUNCTION_NAME        IN VARCHAR2,
                                          P_ENTITY_NAME          IN VARCHAR2,
                                          P_PK1_VALUE            IN VARCHAR2, --Organization_id  
                                          P_PK2_VALUE            IN VARCHAR2, --Inventory_item_Id
                                          P_PK3_VALUE            IN VARCHAR2,
                                          P_PK4_VALUE            IN VARCHAR2,
                                          P_PK5_VALUE            IN VARCHAR2,
                                          P_USER_ID              IN NUMBER,
                                          P_USAGE_TYPE           IN VARCHAR2,
                                          P_DOCUMENT_DESCRIPTION IN VARCHAR2,
                                          P_TITLE                IN VARCHAR2)
    RETURN VARCHAR2;

END XXCONV_URL_ATTACHMENTS_PKG;
/

