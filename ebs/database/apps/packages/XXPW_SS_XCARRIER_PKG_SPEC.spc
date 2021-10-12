CREATE OR REPLACE PACKAGE APPS.xxpw_ss_xcarrier_pkg
AS
/* This custom package is created by ProcessWeaver to communicate with xCarrier Shipping Product.
/*
/* Developer Name   : Venkata Nagarjuna Thota
/*
/* Copyright (C)ProcessWeaver, Inc.
/****************************************************************************
/* FUNCTION NAME: XCARRIER_FNC
/****************************************************************************
/* DESCRIPTION: This Custom Function is developed to return the xCarrier URL when user clicks on Tools > PW xCarrier Shipping menu.
/*              It also returns the oracle application context arguments
/*
/* INPUT PARAMETERS   :p_delivery_id     => Delivery ID
/*                     p_organization_id => Organization ID
/*
/* OUTPUT PARAMETERS : None
/*****************************************************************************/
   FUNCTION xcarrier_fnc (p_delivery_id IN NUMBER, p_organization_id NUMBER)
      RETURN VARCHAR2;

/****************************************************************************
/* FUNCTION NAME: delivery_val_fnc
/****************************************************************************
/* DESCRIPTION: This Custom Function is developed to check the status of delivery lines and to launch xCarrier URL for valid status
/*
/* INPUT PARAMETERS   :p_delivery_id     => Delivery ID
/*
/* OUTPUT PARAMETERS : None
/*****************************************************************************/
   FUNCTION delivery_val_fnc (p_delivery_id IN NUMBER)
      RETURN NUMBER;

/****************************************************************************
/* FUNCTION NAME: VALIDATE_USER_FNC
/****************************************************************************
/* DESCRIPTION: This Custom function is developed to check whether user name exists in Oracle applications or not.
/*
/* INPUT PARAMETERS : p_user_name   => Login user of xCarrier
/*
/* RETURNS : Y or N
/*****************************************************************************/
   FUNCTION validate_user_fnc (p_user_name VARCHAR2)
      RETURN VARCHAR2;

/****************************************************************************
/* PROCEDURE NAME: INITIALIZE_PRC
/****************************************************************************
/* DESCRIPTION: This Custom Procedure is developed to initialize the backend session to get oracle application context and multi org access
/*
/* INPUT PARAMETERS  : p_user            => user name
/*                     p_org_id          => org Id
/*                     p_resp_id         => responsibility id
/*                     p_resp_appl_id    => application id
/* OUTPUT PARAMETERS : x_error           => Displays Success or API Errors
/*****************************************************************************/
   PROCEDURE initialize_prc (
      p_user                 VARCHAR2,
      p_org_id               NUMBER,
      p_resp_id              NUMBER,
      p_resp_appl_id         NUMBER,
      x_error          OUT   VARCHAR2
   );

/****************************************************************************
/* PROCEDURE NAME: DELIVERIES_UPD_PRC
/****************************************************************************
/* DESCRIPTION: This Custom procedure is used to update the Open delivery details when user performs plan shipment in xCarrier.
/*              It will be used only for ECS (xCarrier) Shipments.
/*
/* INPUT PARAMETERS:  p_delivery_id         => Delivery ID
/*                    p_org_id              => orgnaization_id of the organization
/*                    waybill               => Master Tracking Number
/*                    weight                => Gross weight of the delivery
/*                    weight_uom_code       => Weight Uom Code used in xCarrier
/*                    p_expected_del_date   => Expected delivery date
/*                    lines_count           => Lines count of the delivery (Boxes or Pallets)
/*                    cost_center           => Cost Center used in xCArrier used in xCarrier.
/*                    ship_method            => shipmethod selected in carrier
/*                    mot                   => MOT of delivery
/*                    payment type          => payment type in xCarrier
/* OUTPUT PARAMETER:  x_error               => Displays Success or API Errors
/****************************************************************************/
   PROCEDURE deliveries_upd_prc (
      p_delivery_id               NUMBER,
      p_org_id                    NUMBER,
      waybill                     VARCHAR2,
      weight                      NUMBER,
      weight_uom_code             VARCHAR2,
      p_expected_del_date         VARCHAR2,
      lines_count                 VARCHAR2,
      cost_center                 VARCHAR2,
      ship_method                 VARCHAR2,
      mot                         VARCHAR2,
      payment_type                VARCHAR2,
      x_error               OUT   VARCHAR2
   );

/****************************************************************************
/* PROCEDURE NAME: FREIGHT_PRC
/****************************************************************************
/* DESCRIPTION: This Custom procedure is developed to update the freight cost.
/*              It will be used only for ECS(xCarrier) Shipments when Freight terms is "PREPAID/ADD , PREPAID/ADD US"
/*              This will delete the existing freight cost and creates latest freight cost.
/*
/* INPUT PARAMETERS  : p_delivery_id        => Delivery ID
/*                     p_freight_cost       => Total Freight Cost
/* OUTPUT PARAMETERS : x_error              => Displays Success or API Errors
/*****************************************************************************/
   PROCEDURE freight_prc (
      p_delivery_id          NUMBER,
      p_freight_cost         NUMBER,
      p_freight_type         VARCHAR2,
      x_error          OUT   VARCHAR2
   );

/****************************************************************************
/* PROCEDURE NAME: CARRIER_POD_UPD_PRC
/****************************************************************************
/* DESCRIPTION: This Custom procedure is used to update the Carrier Signed By, Carrier date OR POD By and POD date details from xCarrier.
/*
/* INPUT PARAMETERS:  p_delivery_id         => Delivery ID
/*                    p_pod_by              => POD By of table wsh_delivery_legs
/*                    p_pod_date            => POD Date of table wsh_delivery_legs
/*                   p_intransit_status      => Intransist Status of Table wsh_new_delivereis
/* OUTPUT PARAMETERS: x_error               => Displays Success or API Errors
/****************************************************************************/
   PROCEDURE carrier_pod_upd_prc (
      p_delivery_id              NUMBER,
      p_pod_by                   VARCHAR2 DEFAULT NULL,
      p_pod_date                 VARCHAR2 DEFAULT NULL,
      p_intransit_status         VARCHAR2,
      x_error              OUT   VARCHAR2
   );

/****************************************************************************
/* PROCEDURE NAME: EXPORT_NUMBER_PRC
/****************************************************************************
/* DESCRIPTION: This Custom procedure is used to update the EXport Entry number entered in xCarrier.
/*
/*
/* INPUT PARAMETERS:  p_delivery_id         => Delivery ID
/*                    export_number  => export_number in xCarrier
/* OUTPUT PARAMETER:  x_error               => Displays Success or API Errors
/****************************************************************************/
   PROCEDURE export_number_prc (
      p_delivery_id         NUMBER,
      export_number         VARCHAR2,
      x_error         OUT   VARCHAR2
   );
END;
/
