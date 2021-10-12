CREATE OR REPLACE PACKAGE ap_web_cus_acctg_pkg AS
/* $Header: apwcaccb.pls 120.3.12010000.2 2008/08/06 07:44:50 rveliche ship $ */

FUNCTION GetIsCustomBuildOnly RETURN NUMBER;


FUNCTION BuildAccount(
        p_report_header_id              IN NUMBER,
        p_report_line_id                IN NUMBER,
        p_employee_id                   IN NUMBER,
        p_cost_center                   IN VARCHAR2,
        p_exp_type_parameter_id         IN NUMBER,
        p_segments                      IN AP_OIE_KFF_SEGMENTS_T,
        p_ccid                          IN NUMBER,
        p_build_mode                    IN VARCHAR2,
        p_new_segments                  OUT NOCOPY AP_OIE_KFF_SEGMENTS_T,
        p_new_ccid                      OUT NOCOPY NUMBER,
        p_return_error_message          OUT NOCOPY VARCHAR2) RETURN BOOLEAN;


FUNCTION BuildDistProjectAccount(
        p_report_header_id              IN              NUMBER,
        p_report_line_id                IN              NUMBER,
        p_report_distribution_id        IN              NUMBER,
        p_exp_type_parameter_id         IN              NUMBER,
        p_new_segments                  OUT NOCOPY AP_OIE_KFF_SEGMENTS_T,
        p_new_ccid                      OUT NOCOPY      NUMBER,
        p_return_error_message          OUT NOCOPY      VARCHAR2,
        p_return_status                 OUT NOCOPY      VARCHAR2) RETURN BOOLEAN;

-- Bug: 7176464
FUNCTION CustomValidateProjectDist(
       p_report_line_id                 IN              NUMBER,
       p_web_parameter_id               IN              NUMBER,
       p_project_id                     IN              NUMBER,
       p_task_id                        IN              NUMBER,
       p_award_id                       IN              NUMBER,
       p_expenditure_org_id             IN              NUMBER,
       p_amount                         IN              NUMBER,
       p_return_error_message           OUT NOCOPY      VARCHAR2) RETURN BOOLEAN;

END AP_WEB_CUS_ACCTG_PKG;

 
/
