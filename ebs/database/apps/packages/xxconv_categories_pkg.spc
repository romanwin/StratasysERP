CREATE OR REPLACE PACKAGE xxconv_categories_pkg IS

   -- Author  : AVIH
   -- Created : 3/7/2004 12:18:38 PM
   -- Purpose : 
   -- Updated : 25/12/2005
   /*   PROCEDURE read_categ_csv_file(errbuf           OUT VARCHAR2,
   retcode          OUT VARCHAR2,
   p_location       IN VARCHAR2,
   p_filename       IN VARCHAR2,
   p_master_org_id  IN NUMBER,
   p_child_org_id   IN NUMBER,
   p_categ_set_name IN VARCHAR2,
   p_num_of_segment IN VARCHAR2);*/

   /*  PROCEDURE validate_item_categories(errbuf           OUT VARCHAR2,
                                        retcode          OUT VARCHAR2,
                                        p_master_org_id  IN NUMBER,
                                        p_num_of_segment IN VARCHAR2);
   */
   PROCEDURE insert_item_category(errbuf            OUT VARCHAR2,
                                  retcode           OUT VARCHAR2,
                                  p_organization_id IN NUMBER);

   PROCEDURE handle_categories(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

   PROCEDURE delete_category(p_category_set_id NUMBER,
                             p_category_id     NUMBER);
                             
   PROCEDURE handle_ssys_categories(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

END xxconv_categories_pkg;
/
