CREATE OR REPLACE PACKAGE xxoks_ocint_pub AS
/* $Header: OKSPOCIS.pls 120.1 2006/02/16 10:57:07 vjramali noship $ */

--------------------------------------------------------------------
--  name:            XXOKS_OCINT_PUB
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   22/04/2012
--------------------------------------------------------------------
--                   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--  purpose :        COPY OF ORACLE PACKAGE OKS_OCINT_PUB !!!!
--                   EACH UPGRADE NEED TO COMPARE WITH ORIGINAL ORACLE PACKAGE.
--                   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--                   CUST475 - Reprocess Contracts
--                   we developed Program that manage OKS Reprocessing process,
--                   the Program that update SO Line for service item with start and End date 
--                   according to IB installed date.
--                   oracle program that we run create the printer and its assosiate items.
--                   this is not good for us. the solution is to copy oracle package
--                   and add spme modifications:
--                   in order to creaet contracts only for printers and water jets, 
--                   and not for the other assosiate items to the printer.
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  22/04/2012  Dalit A. Raviv    initial build
--------------------------------------------------------------------   

   ---------------------------------------------------------------------------
-- GLOBAL EXCEPTIONS
---------------------------------------------------------------------------
   g_exception_halt_validation   EXCEPTION;
---------------------------------------------------------------------------
-- GLOBAL VARIABLES
---------------------------------------------------------------------------
   g_pkg_name           CONSTANT VARCHAR2 (200) := 'XXOKS_OCINT_PVT';
   g_app_name           CONSTANT VARCHAR2 (3)   := okc_api.g_app_name;

---------------------------------------------------------------------------
-- Procedures and Functions
---------------------------------------------------------------------------
   PROCEDURE oc_interface (
      errbuf    OUT NOCOPY   VARCHAR2,
      retcode   OUT NOCOPY   NUMBER
   );

   PROCEDURE handle_order_error (
      x_return_status   OUT NOCOPY      VARCHAR2,
      p_upd_rec         IN              oks_rep_pvt.repv_rec_type
   );

   PROCEDURE order_reprocess (
      errbuf     OUT NOCOPY      VARCHAR2,
      retcode    OUT NOCOPY      NUMBER,
      p_option   IN              VARCHAR2,
      p_source   IN              VARCHAR2
   );

   PROCEDURE oks_order_purge (
      errbuf    OUT NOCOPY   VARCHAR2,
      retcode   OUT NOCOPY   NUMBER
   );

   PROCEDURE migrate_aso_queue (
      errbuf    OUT NOCOPY   VARCHAR2,
      retcode   OUT NOCOPY   NUMBER
   );
END xxoks_ocint_pub;
/
