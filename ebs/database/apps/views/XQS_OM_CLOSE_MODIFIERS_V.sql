create or replace view xqs_om_close_modifiers_v as
select
--------------------------------------------------------------------
--  customization code: CHG0031775
--  name:               XXOBJT_OA2SF_ASSET_INTERFACE_V
--  create by:          Pinhas Rozner
--  $Revision:          1.0
--  creation date:      2.4.14
--  Description:
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   2.2.14    yuval tal  initial build CHG0031775
--------------------------------------------------------------------
 customer_name              "Customer Name",
       customer_number      "Customer Number",
       modifier_description "Modifier Description",
       operating_unit       "Operating Unit",
       country              "Country",
       start_date           "Start Date",
       end_date             "End Date",
       ou_id                "OU ID"
  from XXOM_MODIFIERS_REPORT_V;
