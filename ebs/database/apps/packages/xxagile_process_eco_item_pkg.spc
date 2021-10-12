CREATE OR REPLACE PACKAGE xxagile_process_eco_item_pkg AUTHID CURRENT_USER IS

  ---------------------------------------------------------------------------
  -- $Header: xxagile_process_eco_item_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxagile_process_eco_item_pkg
  -- Created: Vinay Chappidi
  -- Author  : 26-Dec-2007
  --------------------------------------------------------------------------
  -- Perpose: Wrapper package containing all ECO item record creation
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build
  ---------------------------------------------------------------------------

  TYPE lrec_ref_deseg_type IS RECORD(
    p_ref_designator VARCHAR2(15));

  TYPE ltab_ref_deseg_type IS TABLE OF lrec_ref_deseg_type INDEX BY BINARY_INTEGER;

  TYPE lrec_components_type IS RECORD(
    p_component_seq_num NUMBER,
    p_component         VARCHAR2(240),
    p_component_qty     NUMBER,
    p_ref_designator    ltab_ref_deseg_type, -- varchar2(15)
    p_balloon           VARCHAR2(150), -- varchar2(15)
    p_comments          VARCHAR2(240),
    p_acd_flag          NUMBER,
    p_disable_date      DATE);

  TYPE ltab_components_type IS TABLE OF lrec_components_type INDEX BY BINARY_INTEGER;

  TYPE lrec_revised_items_type IS RECORD(
    p_assembly             VARCHAR2(240),
    p_new_assembly_itm_rev VARCHAR2(100),
    p_old_assembly_itm_rev VARCHAR2(100),
    p_effective_date       DATE, -- effective date for the revised item and components
    p_old_effective_date   DATE, -- needed when we are trying to update or delete
    p_components_tbl       ltab_components_type,
    p_owner_organization   VARCHAR2(240));
  TYPE ltab_revised_items_type IS TABLE OF lrec_revised_items_type INDEX BY BINARY_INTEGER;

  /* procedure process_eco_item(p_eco_number           IN varchar2, -- varchar2(10)
  p_change_type_code     IN varchar2, -- varchar2(30)
  p_assembly             IN varchar2, -- varchar2(240)
  p_new_assembly_itm_rev IN varchar2, -- varchar2(3)
  p_old_assembly_itm_rev IN varchar2, -- varchar2(3)
  p_effective_date       date, -- effective date for the revised item and components
  p_old_effective_date   IN date, -- needed when we are trying to update or delete
  p_components_tbl       IN ltab_components_type,
  --                               p_ref_designator IN varchar2, -- varchar2(15)
  --                               p_balloon IN varchar2, -- varchar2(15)
  p_requestor           IN varchar2, -- varchar2(30)
  p_owner_organization  IN varchar2, -- varchar2(240) bill
  p_creation_dt         IN date,
  p_created_by          IN number,
  p_last_updated_dt     IN date,
  p_last_update_by      IN number,
  x_return_status       OUT NOCOPY varchar2,
  x_error_code          OUT NOCOPY number,
  x_msg_count           OUT NOCOPY number,
  x_msg_data            OUT NOCOPY varchar2,
  p_ecn_initiation_date IN date); --eco*/

  PROCEDURE process_eco_item(p_eco_number          IN VARCHAR2, -- varchar2(10)
                             p_change_type_code    IN VARCHAR2, -- varchar2(30)
                             p_ecn_initiation_date IN DATE,
                             p_revised_items       IN xxagile_proc_eco_item_pkg12,
                             p_creation_dt         IN DATE,
                             p_created_by          IN NUMBER,
                             p_last_updated_dt     IN DATE,
                             p_last_update_by      IN NUMBER,
                             x_return_status       OUT NOCOPY VARCHAR2,
                             x_error_code          OUT NOCOPY NUMBER,
                             x_msg_count           OUT NOCOPY NUMBER,
                             x_msg_data            OUT NOCOPY VARCHAR2); --eco

END xxagile_process_eco_item_pkg;
/
