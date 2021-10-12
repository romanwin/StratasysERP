CREATE OR REPLACE PACKAGE xxpo_stratadoc_util_pkg AS
  ----------------------------------------------------------------------------
  --  name:            xxpo_stratadoc_util_pkg
  --  create by:       Dan Melamed
  --  Revision:        1.0
  --  creation date:   20-Mar-2018
  ----------------------------------------------------------------------------
  --  purpose :         New Vendors interface from Oracle to  Stratadoc
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  20-Mar-2018  Dan Melamed                 CHG0042545 - initial build
  ----------------------------------------------------------------------------

  ----------------------------------------------------------------------------
  --  name:            insert_event
  --  create by:       Dan Melamed
  --  Revision:        1.0
  --  creation date:   20-Mar-2018
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write update indications to xxssys_events.
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  --  1.0  20-Mar-2018  Dan Melamed                 CHG0042545 - initial build
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE insert_events(errbuf      OUT NOCOPY VARCHAR2,
                          retcode     OUT NOCOPY NUMBER,
                          p_days_back Number default 0);

end xxpo_stratadoc_util_pkg;
/
