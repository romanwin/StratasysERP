/*
** File Name: xx_okl_acc_gen_wf_pkg.pks
** Created by: Devendra Singh 
** Revision: 1.0
** Creation Date: 13/01/2014
--------------------------------------------------------------------
** Purpose : Package defined to derive the account 
--------------------------------------------------------------------
** Version    Date        Name           Desc
--------------------------------------------------------------------
** 1.0     13/01/2014 Devendra Singh Initial build for CR-1242
*/
CREATE OR REPLACE PACKAGE xx_okl_acc_gen_wf_pkg
AS
   /*
   ** Procedure Name: set_ccid
   ** Created by: Devendra Singh 
   ** Revision: 1.0
   ** Creation Date: 13/01/2014
   -------------------------------------------------------------------------
   ** Purpose : Procedure will be called from the Account Generator API to 
   **           invoke the workflow to generate the ccid
   -------------------------------------------------------------------------
   ** Version    Date        Name           Desc
   -------------------------------------------------------------------------
   ** 1.0     13/01/2014 Devendra Singh Initial build
   */
   PROCEDURE set_ccid (
      itemtype   IN              VARCHAR2,
      itemkey    IN              VARCHAR2,
      actid      IN              NUMBER,
      funcmode   IN              VARCHAR2,
      RESULT     OUT NOCOPY      VARCHAR2
   );
END xx_okl_acc_gen_wf_pkg;
/