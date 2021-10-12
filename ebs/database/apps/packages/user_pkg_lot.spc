CREATE OR REPLACE PACKAGE user_pkg_lot AUTHID CURRENT_USER AS
  /* $Header: INVUDLGS.pls 120.1.12010000.4 2011/09/19 12:35:10 kbavadek ship $ */
  /*#
  * The user defined lot generation procedures allow a user to create a lot
  * in the system using the lot number generation logic defined by a user (and not by Oracle).
  * @rep:scope public
  * @rep:product INV
  * @rep:lifecycle active
  * @rep:displayname User Defined Lot Generation API
  * @rep:category BUSINESS_ENTITY INV_LOT
  */
  /*#
  * Use this procedure to define the logic to be used by the system
  * when generating the lot numbers. This procedure is invoked by the
  * system while generating a new lot number, if the lot generation
  * level is set as "User Defined" for a particular organization.
  * The user needs to fill in the logic for generating lot number in
  * the stub provided and apply the package to the database.
  * @ param p_org_id Organization Id is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_inventory_item_id Inventory Item Id is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_transaction_date Transaction Date is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_revision Revision of the item is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_subinventory_code Subinventory Code where the lot number will reside is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_locator_id Locator Id is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_transaction_Type_id Transaction Type Id is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_transaction_Action_id Transaction Action Id is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_transaction_source_type_id Transaction Source Type is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_transaction_source_id Transaction Source ID is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_transaction_source_line_id Transaction Source Line ID is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param p_lot_number Lot number to be generated is passed as input in this variable
  * @ paraminfo {@rep:required}
  * @ param x_return_status Return status indicating success or failure.
  * @ paraminfo {@rep:required}
  * @return The new Lot Number generated.
  * @rep:scope public
  * @rep:lifecycle active
  * @rep:displayname Generate User Defined Lot Number
  */
  -- OPM Convergence - added parent_lot_number
  -- Fix for Bug#12925054. Added p_transaction_source_id and p_transaction_source_line_id
  -- so that batch or wip job information can be included

  FUNCTION generate_lot_number(p_org_id                     IN NUMBER,
		       p_inventory_item_id          IN NUMBER,
		       p_transaction_date           IN DATE,
		       p_revision                   IN VARCHAR2,
		       p_subinventory_code          IN VARCHAR2,
		       p_locator_id                 IN NUMBER,
		       p_transaction_type_id        IN NUMBER,
		       p_transaction_action_id      IN NUMBER,
		       p_transaction_source_type_id IN NUMBER,
		       p_transaction_source_id      IN NUMBER,
		       p_transaction_source_line_id IN NUMBER,
		       p_lot_number                 IN VARCHAR2,
		       p_parent_lot_number          IN VARCHAR2,
		       x_return_status              OUT NOCOPY VARCHAR2)
    RETURN VARCHAR2;

  /* Bug6836808
  * Use this Function To Allow or Disallow
  * Creation of New Lots Depending on some user logic,
  * The user can write his own piece of code for the function
  * to return TRUE or FALSE.
  */

  FUNCTION allow_new_lots(p_transaction_type_id IN NUMBER) RETURN BOOLEAN;

  /*
  * Hook for custom logic to allocate expired lots.
  * Customers can then write their own logic to derive use_expired lots.
  * By default, this value is returned as FALSE.
  */

  FUNCTION use_expired_lots(p_organization_id       IN NUMBER,
		    p_inventory_item_id     IN NUMBER,
		    p_demand_source_type_id IN NUMBER,
		    p_demand_source_line_id IN NUMBER) RETURN BOOLEAN;

END user_pkg_lot;
/
