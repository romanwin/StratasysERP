CREATE OR REPLACE PACKAGE cs_servicerequest_cuhk AS
/* $Header: cscsrs.pls 120.0 2006/02/09 17:06:02 spusegao noship $ */

  /*****************************************************************************************
   This is the Customer User Hook API.
   The Customers can add customization procedures here for Pre and Post Processing.
   ******************************************************************************************/




  /* Customer Procedure for pre processing in case of
	create service request */

  /*
  PROCEDURE Create_ServiceRequest_Pre
(p_service_request_rec   IN   CS_ServiceRequest_PVT.service_request_rec_type,
   x_return_status        OUT  NOCOPY VARCHAR2
  ); */

   PROCEDURE Create_ServiceRequest_Pre
  ( p_api_version            IN    NUMBER,
    p_init_msg_list          IN    VARCHAR2 DEFAULT fnd_api.g_false,
    p_commit                 IN    VARCHAR2 DEFAULT fnd_api.g_false,
    p_validation_level       IN    NUMBER   DEFAULT fnd_api.g_valid_level_full,
    x_return_status          OUT   NOCOPY VARCHAR2,
    x_msg_count              OUT   NOCOPY NUMBER,
    x_msg_data               OUT   NOCOPY VARCHAR2,
    p_resp_appl_id           IN    NUMBER   DEFAULT NULL,
    p_resp_id                IN    NUMBER   DEFAULT NULL,
    p_user_id                IN    NUMBER,
    p_login_id               IN    NUMBER   DEFAULT NULL,
    p_org_id                 IN    NUMBER   DEFAULT NULL,
    p_request_id             IN    NUMBER   DEFAULT NULL,
    p_request_number         IN    VARCHAR2 DEFAULT NULL,
    p_invocation_mode        IN    VARCHAR2 := 'NORMAL',
    p_service_request_rec    IN    CS_ServiceRequest_PVT.service_request_rec_type,
    p_notes                  IN    CS_ServiceRequest_PVT.notes_table,
    p_contacts               IN    CS_ServiceRequest_PVT.contacts_table ,
    x_request_id             OUT   NOCOPY NUMBER,
    x_request_number         OUT   NOCOPY VARCHAR2,
    x_interaction_id         OUT   NOCOPY NUMBER,
    x_workflow_process_id    OUT   NOCOPY NUMBER
  ) ;


  /* Customer Procedure for post processing in case of
	create service request */

  /*
  PROCEDURE  Create_ServiceRequest_Post
(p_service_request_rec   IN   CS_ServiceRequest_PVT.service_request_rec_type,
   x_return_status        OUT  NOCOPY VARCHAR2
	);  */


  PROCEDURE  Create_ServiceRequest_Post
  ( p_api_version            IN    NUMBER,
    p_init_msg_list          IN    VARCHAR2 DEFAULT fnd_api.g_false,
    p_commit                 IN    VARCHAR2 DEFAULT fnd_api.g_false,
    p_validation_level       IN    NUMBER   DEFAULT fnd_api.g_valid_level_full,
    x_return_status          OUT   NOCOPY VARCHAR2,
    x_msg_count              OUT   NOCOPY NUMBER,
    x_msg_data               OUT   NOCOPY VARCHAR2,
    p_resp_appl_id           IN    NUMBER   DEFAULT NULL,
    p_resp_id                IN    NUMBER   DEFAULT NULL,
    p_user_id                IN    NUMBER,
    p_login_id               IN    NUMBER   DEFAULT NULL,
    p_org_id                 IN    NUMBER   DEFAULT NULL,
    p_request_id             IN    NUMBER   DEFAULT NULL,
    p_request_number         IN    VARCHAR2 DEFAULT NULL,
    p_invocation_mode        IN    VARCHAR2 := 'NORMAL',
    p_service_request_rec    IN    CS_ServiceRequest_PVT.service_request_rec_type,
    p_notes                  IN    CS_ServiceRequest_PVT.notes_table,
    p_contacts               IN    CS_ServiceRequest_PVT.contacts_table ,
    x_request_id             OUT   NOCOPY NUMBER,
    x_request_number         OUT   NOCOPY VARCHAR2,
    x_interaction_id         OUT   NOCOPY NUMBER,
    x_workflow_process_id    OUT   NOCOPY NUMBER
  );




  /* Customer Procedure for pre processing in case of
	update service request */

  /*
  PROCEDURE  Update_ServiceRequest_Pre
  ( p_request_id    IN      NUMBER,
      p_service_request_rec   IN   CS_ServiceRequest_PVT.service_request_rec_type,
	x_return_status        OUT  NOCOPY VARCHAR2
		); */


   PROCEDURE  Update_ServiceRequest_Pre
  ( p_api_version		    IN	NUMBER,
    p_init_msg_list		    IN	VARCHAR2 DEFAULT fnd_api.g_false,
    p_commit			    IN	VARCHAR2 DEFAULT fnd_api.g_false,
    p_validation_level	    IN	NUMBER   DEFAULT fnd_api.g_valid_level_full,
    x_return_status		    OUT	NOCOPY VARCHAR2,
    x_msg_count		    OUT	NOCOPY NUMBER,
    x_msg_data			    OUT	NOCOPY VARCHAR2,
    p_request_id		    IN	NUMBER,
    p_object_version_number  IN    NUMBER,
    p_resp_appl_id		    IN	NUMBER   DEFAULT NULL,
    p_resp_id			    IN	NUMBER   DEFAULT NULL,
    p_last_updated_by	    IN	NUMBER,
    p_last_update_login	    IN	NUMBER   DEFAULT NULL,
    p_last_update_date	    IN	DATE,
    p_invocation_mode        IN    VARCHAR2 := 'NORMAL',
    p_service_request_rec    IN    CS_ServiceRequest_PVT.service_request_rec_type,
    p_update_desc_flex       IN    VARCHAR2 DEFAULT fnd_api.g_false,
    p_notes                  IN    CS_ServiceRequest_PVT.notes_table,
    p_contacts               IN    CS_ServiceRequest_PVT.contacts_table,
    p_audit_comments         IN    VARCHAR2 DEFAULT NULL,
    p_called_by_workflow	    IN 	VARCHAR2 DEFAULT fnd_api.g_false,
    p_workflow_process_id    IN	NUMBER   DEFAULT NULL,
    x_workflow_process_id    OUT   NOCOPY NUMBER,
    x_interaction_id	    OUT	NOCOPY NUMBER
    ) ;


  /* Customer Procedure for post processing in case of
	 update service request */


  /*
  PROCEDURE  Update_ServiceRequest_Post
( p_request_id    IN      NUMBER,
    p_service_request_rec   IN   CS_ServiceRequest_PVT.service_request_rec_type,
	x_return_status        OUT  NOCOPY VARCHAR2);  */



   PROCEDURE  Update_ServiceRequest_Post
   ( p_api_version		    IN	NUMBER,
    p_init_msg_list		    IN	VARCHAR2 DEFAULT fnd_api.g_false,
    p_commit			    IN	VARCHAR2 DEFAULT fnd_api.g_false,
    p_validation_level	    IN	NUMBER   DEFAULT fnd_api.g_valid_level_full,
    x_return_status		    OUT	NOCOPY VARCHAR2,
    x_msg_count		    OUT	NOCOPY NUMBER,
    x_msg_data			    OUT	NOCOPY VARCHAR2,
    p_request_id		    IN	NUMBER,
    p_object_version_number  IN    NUMBER,
    p_resp_appl_id		    IN	NUMBER   DEFAULT NULL,
    p_resp_id			    IN	NUMBER   DEFAULT NULL,
    p_last_updated_by	    IN	NUMBER,
    p_last_update_login	    IN	NUMBER   DEFAULT NULL,
    p_last_update_date	    IN	DATE,
    p_invocation_mode        IN    VARCHAR2 := 'NORMAL',
    p_service_request_rec    IN    CS_ServiceRequest_PVT.service_request_rec_type,
    p_update_desc_flex       IN    VARCHAR2 DEFAULT fnd_api.g_false,
    p_notes                  IN    CS_ServiceRequest_PVT.notes_table,
    p_contacts               IN    CS_ServiceRequest_PVT.contacts_table,
    p_audit_comments         IN    VARCHAR2 DEFAULT NULL,
    p_called_by_workflow	    IN 	VARCHAR2 DEFAULT fnd_api.g_false,
    p_workflow_process_id    IN	NUMBER   DEFAULT NULL,
    x_workflow_process_id    OUT   NOCOPY NUMBER,
    x_interaction_id	    OUT	NOCOPY NUMBER
    ) ;




  FUNCTION  Ok_To_Generate_Msg
(p_request_id   IN NUMBER,
 p_service_request_rec   IN   CS_ServiceRequest_PVT.service_request_rec_type)
 RETURN BOOLEAN ;


  FUNCTION Ok_To_Launch_Workflow
    ( p_request_id   IN NUMBER,
      p_service_request_rec     IN   CS_ServiceRequest_PVT.service_request_rec_type)
    RETURN BOOLEAN ;

END  cs_servicerequest_cuhk;

 
/
