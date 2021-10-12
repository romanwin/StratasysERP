CREATE OR REPLACE PACKAGE BODY cs_servicerequest_cuhk  AS
  /* $Header: cscsrb.pls 120.0 2006/02/09 17:06:59 spusegao noship $ */

  /*****************************************************************************************
   This is the Customer User Hook API.
   The Customers can add customization procedures here for Pre and Post Processing.
   ******************************************************************************************/
G_PKG_NAME           CONSTANT VARCHAR2(30) := 'CS_ServiceRequest_CUHK';

   PROCEDURE Create_ServiceRequest_Pre
  ( p_api_version            IN    NUMBER,
    p_init_msg_list          IN    VARCHAR2  ,
    p_commit                 IN    VARCHAR2  ,
    p_validation_level       IN    NUMBER    ,
    x_return_status          OUT   NOCOPY VARCHAR2,
    x_msg_count              OUT   NOCOPY NUMBER,
    x_msg_data               OUT   NOCOPY VARCHAR2,
    p_resp_appl_id           IN    NUMBER    ,
    p_resp_id                IN    NUMBER    ,
    p_user_id                IN    NUMBER,
    p_login_id               IN    NUMBER    ,
    p_org_id                 IN    NUMBER    ,
    p_request_id             IN    NUMBER    ,
    p_request_number         IN    VARCHAR2  ,
    p_invocation_mode        IN    VARCHAR2 := 'NORMAL',
    p_service_request_rec    IN    CS_ServiceRequest_PVT.service_request_rec_type,
    p_notes                  IN    CS_ServiceRequest_PVT.notes_table,
    p_contacts               IN    CS_ServiceRequest_PVT.contacts_table ,
    x_request_id             OUT   NOCOPY NUMBER,
    x_request_number         OUT   NOCOPY VARCHAR2,
    x_interaction_id         OUT   NOCOPY NUMBER,
    x_workflow_process_id    OUT   NOCOPY NUMBER
  ) Is
    l_return_status     VARCHAR2(1)  := null;
    l_api_name          VARCHAR2(30) := 'Create_ServiceRequest_Post';
    l_api_name_full     CONSTANT VARCHAR2(61)  := G_PKG_NAME||'.'||l_api_name;

  Begin

    Savepoint CS_ServiceRequest_CUHK;

    x_return_status := fnd_api.g_ret_sts_success;
/*
   -- Call to ISupport Package

     IBU_SR_CUHK.Create_ServiceRequest_Pre(
                p_api_version            => p_api_version,
                p_init_msg_list          => p_init_msg_list,
                p_commit                 => p_commit,
                p_validation_level       => fnd_api.g_valid_level_full,
                x_return_status          => l_return_status,
                x_msg_count              => x_msg_count,
                x_msg_data               => x_msg_data,
                p_resp_appl_id           => p_resp_appl_id,
                p_resp_id                => p_resp_id,
                p_user_id                => p_user_id,
                p_login_id               => p_login_id,
                p_org_id                 => p_org_id,
                p_request_id             => p_request_id,
                p_request_number         => p_request_number,
                p_invocation_mode        => p_invocation_mode,
                p_service_request_rec    => p_service_request_rec,
                p_notes                  => p_notes,
                p_contacts               => p_contacts,
                x_request_id             => x_request_id,
                x_request_number         => x_request_number,
                x_interaction_id         => x_interaction_id,
                x_workflow_process_id    => x_workflow_process_id
         );
    IF (l_return_status <> fnd_api.g_ret_sts_success) THEN
            RAISE FND_API.G_EXC_ERROR;
    END IF;
--------


   -- Call to GIT Package
    CS_GIT_USERHOOK_PKG.GIT_Create_ServiceRequest_Pre (
                p_api_version     => p_api_version,
                p_init_msg_list   => p_init_msg_list,
                p_commit          => p_commit,
                p_validation_level=> FND_API.G_VALID_LEVEL_FULL,
                x_return_status   => l_return_status,
                x_msg_count       => x_msg_count,
                x_msg_data        => x_msg_data,
                p_sr_rec          => p_service_request_rec,
                p_incident_number => p_request_number,
                p_incident_id     => p_request_id,
                p_invocation_mode => p_invocation_mode
        );

    IF (l_return_status <> fnd_api.g_ret_sts_success) THEN
            RAISE FND_API.G_EXC_ERROR;
    END IF;
*/
    -- Added null b'coz patch# 2192849 giving errors b'coz of this file.
    NULL;
--------------

    /*CS_OSS_USERHOOK_PKG.OSS_Create_ServiceRequest_Pre(
               p_api_version         => p_api_version,
               p_init_msg_list       => p_init_msg_list,
               p_commit              => p_commit,
               p_validation_level    => FND_API.G_VALID_LEVEL_FULL,
               x_return_status       => l_return_status,
               x_msg_count           => x_msg_count,
               x_msg_data            => x_msg_data,
               p_service_request_rec => p_service_request_rec
        );

    IF (l_return_status <> FND_API.G_RET_STS_SUCCESS) THEN
            RAISE FND_API.G_EXC_ERROR;
    END IF;
*/
-- Standard call to get message count and if count is 1, get message info
    FND_MSG_PUB.Count_And_Get(  p_count => x_msg_count,
                                p_data  => x_msg_data );

EXCEPTION
   WHEN FND_API.G_EXC_ERROR THEN
        ROLLBACK TO CS_ServiceRequest_CUHK;
        x_return_status := FND_API.G_RET_STS_ERROR;
        FND_MSG_PUB.Count_And_Get
          ( p_count => x_msg_count,
            p_data  => x_msg_data );
    WHEN OTHERS THEN
        ROLLBACK TO CS_ServiceRequest_CUHK;
        x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
        IF FND_MSG_PUB.Check_Msg_Level(FND_MSG_PUB.G_MSG_LVL_UNEXP_ERROR) THEN
            FND_MSG_PUB.Add_Exc_Msg(G_PKG_NAME, l_api_name);
        END IF;
        FND_MSG_PUB.Count_And_Get
        (    p_count => x_msg_count,
             p_data  => x_msg_data
        );
  END;

  PROCEDURE  Create_ServiceRequest_Post
  ( p_api_version            IN    NUMBER,
    p_init_msg_list          IN    VARCHAR2 ,
    p_commit                 IN    VARCHAR2 ,
    p_validation_level       IN    NUMBER   ,
    x_return_status          OUT   NOCOPY VARCHAR2,
    x_msg_count              OUT   NOCOPY NUMBER,
    x_msg_data               OUT   NOCOPY VARCHAR2,
    p_resp_appl_id           IN    NUMBER    ,
    p_resp_id                IN    NUMBER    ,
    p_user_id                IN    NUMBER,
    p_login_id               IN    NUMBER    ,
    p_org_id                 IN    NUMBER    ,
    p_request_id             IN    NUMBER    ,
    p_request_number         IN    VARCHAR2  ,
    p_invocation_mode        IN    VARCHAR2 := 'NORMAL',
    p_service_request_rec    IN    CS_ServiceRequest_PVT.service_request_rec_type,
    p_notes                  IN    CS_ServiceRequest_PVT.notes_table,
    p_contacts               IN    CS_ServiceRequest_PVT.contacts_table ,
    x_request_id             OUT   NOCOPY NUMBER,
    x_request_number         OUT   NOCOPY VARCHAR2,
    x_interaction_id         OUT   NOCOPY NUMBER,
    x_workflow_process_id    OUT   NOCOPY NUMBER
  ) IS
    l_return_status     VARCHAR2(1)  := null;
    l_api_name          VARCHAR2(30) := 'Create_ServiceRequest_Post';
    l_api_name_full     CONSTANT VARCHAR2(61)  := G_PKG_NAME||'.'||l_api_name;
BEGIN

    Savepoint CS_ServiceRequest_CUHK;

    x_return_status := fnd_api.g_ret_sts_success;
/*
     IBU_SR_CUHK.Create_ServiceRequest_Post(
                p_api_version            => p_api_version,
                p_init_msg_list          => p_init_msg_list,
                p_commit                 => p_commit,
                p_validation_level       => fnd_api.g_valid_level_full,
                x_return_status          => l_return_status,
                x_msg_count              => x_msg_count,
                x_msg_data               => x_msg_data,
                p_resp_appl_id           => p_resp_appl_id,
                p_resp_id                => p_resp_id,
                p_user_id                => p_user_id,
                p_login_id               => p_login_id,
                p_org_id                 => p_org_id,
                p_request_id             => p_request_id,
                p_request_number         => p_request_number,
                p_invocation_mode        => p_invocation_mode,
                p_service_request_rec    => p_service_request_rec,
                p_notes                  => p_notes,
                p_contacts               => p_contacts,
                x_request_id             => x_request_id,
                x_request_number         => x_request_number,
                x_interaction_id         => x_interaction_id,
                x_workflow_process_id    => x_workflow_process_id
         );

    IF (l_return_status <> fnd_api.g_ret_sts_success) THEN
            RAISE FND_API.G_EXC_ERROR;
    END IF;


    CS_GIT_USERHOOK_PKG.GIT_Create_ServiceRequest_Post(
                p_api_version      => p_api_version,
                p_init_msg_list    => p_init_msg_list,
                p_commit           => p_commit,
                p_validation_level => FND_API.G_VALID_LEVEL_FULL,
                x_return_status    => l_return_status,
                x_msg_count        => x_msg_count,
                x_msg_data         => x_msg_data,
                p_sr_rec           => p_service_request_rec,
                p_incident_number  => p_request_number,
                p_incident_id      => p_request_id,
                p_invocation_mode  => p_invocation_mode
        );

    If (l_return_status <> FND_API.G_RET_STS_SUCCESS) THEN
        RAISE FND_API.G_EXC_ERROR;
    END IF;
*/
    NULL;

-- Standard call to get message count and if count is 1, get message info
    FND_MSG_PUB.Count_And_Get(  p_count => x_msg_count,
                                p_data  => x_msg_data );
EXCEPTION
   WHEN FND_API.G_EXC_ERROR THEN
        ROLLBACK TO CS_ServiceRequest_CUHK;
        x_return_status := FND_API.G_RET_STS_ERROR;
        FND_MSG_PUB.Count_And_Get
          ( p_count => x_msg_count,
            p_data  => x_msg_data );
    WHEN OTHERS THEN
        ROLLBACK TO CS_ServiceRequest_CUHK;
        x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
        IF FND_MSG_PUB.Check_Msg_Level(FND_MSG_PUB.G_MSG_LVL_UNEXP_ERROR) THEN
            FND_MSG_PUB.Add_Exc_Msg(G_PKG_NAME, l_api_name);
        END IF;
        FND_MSG_PUB.Count_And_Get
        (    p_count => x_msg_count,
             p_data  => x_msg_data
        );
END;


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
    p_init_msg_list		    IN	VARCHAR2  ,
    p_commit			    IN	VARCHAR2  ,
    p_validation_level	    IN	NUMBER    ,
    x_return_status		    OUT	NOCOPY VARCHAR2,
    x_msg_count		    OUT	NOCOPY NUMBER,
    x_msg_data			    OUT	NOCOPY VARCHAR2,
    p_request_id		    IN	NUMBER,
    p_object_version_number  IN    NUMBER,
    p_resp_appl_id		    IN	NUMBER    ,
    p_resp_id			    IN	NUMBER    ,
    p_last_updated_by	    IN	NUMBER,
    p_last_update_login	    IN	NUMBER    ,
    p_last_update_date	    IN	DATE,
    p_invocation_mode       IN  VARCHAR2 := 'NORMAL',
    p_service_request_rec    IN    CS_ServiceRequest_PVT.service_request_rec_type,
    p_update_desc_flex       IN    VARCHAR2  ,
    p_notes                  IN    CS_ServiceRequest_PVT.notes_table,
    p_contacts               IN    CS_ServiceRequest_PVT.contacts_table,
    p_audit_comments         IN    VARCHAR2  ,
    p_called_by_workflow	    IN 	VARCHAR2  ,
    p_workflow_process_id    IN	NUMBER    ,
    x_workflow_process_id    OUT   NOCOPY NUMBER,
    x_interaction_id	     OUT NOCOPY NUMBER
    ) IS
    l_action_type	    VARCHAR2(15) := 'UPDATE';
    l_source            VARCHAR2(10);
    l_return_status     VARCHAR2(1);
    l_msg_data          VARCHAR2(2000);
    l_msg_count         NUMBER;
    l_api_name          VARCHAR2(30) := 'Update_ServiceRequest_Post';
    l_api_name_full     CONSTANT VARCHAR2(61)  := G_PKG_NAME||'.'||l_api_name;
 Begin

    Savepoint CS_ServiceRequest_CUHK;
    -- Added by Vitaly 15-Mar-2010 --
    -- CUST288 - SR Charge Validation On Closure
    -- x_return_status := fnd_api.g_ret_sts_success;  -- closed by Vitaly 15-Mar-2010
    XXCS_SR_CHARGES_VALIDATION_PKG.check_sr_charges_validation(
                                      p_incident_id       => p_request_id,
                                      p_new_inc_status_id => p_service_request_rec.status_id,
                                      p_out_status        => x_return_status);
    -- end Vitaly 15-Mar-2010
/*
   -- Call to ISupport Package

     IBU_SR_CUHK.Update_ServiceRequest_Pre(
                p_api_version            => p_api_version,
                p_init_msg_list          => p_init_msg_list,
                p_commit                 => p_commit,
                p_validation_level       => fnd_api.g_valid_level_full,
                x_return_status          => l_return_status,
                x_msg_count              => x_msg_count,
                x_msg_data               => x_msg_data,
                p_request_id             => p_request_id,
                p_object_version_number  => p_object_version_number,
                p_resp_appl_id           => p_resp_appl_id,
                p_resp_id                => p_resp_id,
                p_last_updated_by        => p_last_updated_by,
                p_last_update_login      => p_last_update_login,
                p_last_update_date       => p_last_update_date,
                p_invocation_mode        => p_invocation_mode,
                p_service_request_rec    => p_service_request_rec,
                p_update_desc_flex       => p_update_desc_flex,
                p_notes                  => p_notes,
                p_contacts               => p_contacts,
                p_audit_comments         => p_audit_comments,
                p_called_by_workflow     => p_called_by_workflow,
                p_workflow_process_id    => p_workflow_process_id,
                x_workflow_process_id    => x_workflow_process_id,
                x_interaction_id         => x_interaction_id
          );

   IF (l_return_status <> FND_API.G_RET_STS_SUCCESS) THEN
        RAISE FND_API.G_EXC_ERROR;
    END IF;
---------

      CS_GIT_USERHOOK_PKG.GIT_Update_ServiceRequest_Pre(
                p_api_version      => p_api_version,
                p_init_msg_list    => p_init_msg_list,
                p_commit           => p_commit,
                p_validation_level => FND_API.G_VALID_LEVEL_FULL,
                x_return_status    => l_return_status,
                x_msg_count        => x_msg_count,
                x_msg_data         => x_msg_data,
                p_sr_rec           => p_service_request_rec,
                p_incident_id      => p_request_id,
                p_invocation_mode  => p_invocation_mode
          );

    IF (l_return_status <> FND_API.G_RET_STS_SUCCESS) THEN
        RAISE FND_API.G_EXC_ERROR;
    END IF;
*/
    NULL;

     /*CS_OSS_USERHOOK_PKG.OSS_Update_ServiceRequest_Pre(
                p_api_version         => p_api_version,
                p_init_msg_list       => p_init_msg_list,
                p_commit              => p_commit,
                p_validation_level    => FND_API.G_VALID_LEVEL_FULL,
                x_return_status       => l_return_status,
                x_msg_count           => x_msg_count,
                x_msg_data            => x_msg_data,
                p_service_request_rec => p_service_request_rec
        );

    IF (l_return_status <> FND_API.G_RET_STS_SUCCESS) THEN
        RAISE FND_API.G_EXC_ERROR;
    END IF;
*/
-- Standard call to get message count and if count is 1, get message info
    FND_MSG_PUB.Count_And_Get(  p_count => x_msg_count,
                                p_data  => x_msg_data );
EXCEPTION
   WHEN FND_API.G_EXC_ERROR THEN
        ROLLBACK TO CS_ServiceRequest_CUHK;
        x_return_status := FND_API.G_RET_STS_ERROR;
        FND_MSG_PUB.Count_And_Get
          ( p_count => x_msg_count,
            p_data  => x_msg_data );
    WHEN OTHERS THEN
        ROLLBACK TO CS_ServiceRequest_CUHK;
        x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
        IF FND_MSG_PUB.Check_Msg_Level(FND_MSG_PUB.G_MSG_LVL_UNEXP_ERROR) THEN
            FND_MSG_PUB.Add_Exc_Msg(G_PKG_NAME, l_api_name);
        END IF;
        FND_MSG_PUB.Count_And_Get
        (    p_count => x_msg_count,
             p_data  => x_msg_data
        );
 End;

  /* Customer Procedure for post processing in case of
	 update service request */


  /*
  PROCEDURE  Update_ServiceRequest_Post
( p_request_id    IN      NUMBER,
    p_service_request_rec   IN   CS_ServiceRequest_PVT.service_request_rec_type,
	x_return_status        OUT  NOCOPY VARCHAR2);  */



   PROCEDURE  Update_ServiceRequest_Post
   ( p_api_version		    IN	NUMBER,
    p_init_msg_list		    IN	VARCHAR2  ,
    p_commit			    IN	VARCHAR2  ,
    p_validation_level	    IN	NUMBER    ,
    x_return_status		    OUT	NOCOPY VARCHAR2,
    x_msg_count		    OUT	NOCOPY NUMBER,
    x_msg_data			    OUT	NOCOPY VARCHAR2,
    p_request_id		    IN	NUMBER,
    p_object_version_number  IN    NUMBER,
    p_resp_appl_id		    IN	NUMBER    ,
    p_resp_id			    IN	NUMBER    ,
    p_last_updated_by	    IN	NUMBER,
    p_last_update_login	    IN	NUMBER   ,
    p_last_update_date	    IN	DATE,
    p_invocation_mode       IN  VARCHAR2 := 'NORMAL',
    p_service_request_rec    IN    CS_ServiceRequest_PVT.service_request_rec_type,
    p_update_desc_flex       IN    VARCHAR2  ,
    p_notes                  IN    CS_ServiceRequest_PVT.notes_table,
    p_contacts               IN    CS_ServiceRequest_PVT.contacts_table,
    p_audit_comments         IN    VARCHAR2  ,
    p_called_by_workflow	    IN 	VARCHAR2  ,
    p_workflow_process_id    IN	NUMBER    ,
    x_workflow_process_id    OUT   NOCOPY NUMBER,
    x_interaction_id	    OUT	NOCOPY NUMBER
    ) IS
    l_action_type	    VARCHAR2(15) := 'UPDATE';
    l_source            VARCHAR2(10);
    l_return_status     VARCHAR2(1);
    l_api_name          VARCHAR2(30) := 'Update_ServiceRequest_Post';
    l_api_name_full     CONSTANT VARCHAR2(61)  := G_PKG_NAME||'.'||l_api_name;
BEGIN

     Savepoint CS_ServiceRequest_CUHK;

    x_return_status := fnd_api.g_ret_sts_success;
/*
     IBU_SR_CUHK.Update_ServiceRequest_Post(
                p_api_version            => p_api_version,
                p_init_msg_list          => p_init_msg_list,
                p_commit                 => p_commit,
                p_validation_level       => fnd_api.g_valid_level_full,
                x_return_status          => l_return_status,
                x_msg_count              => x_msg_count,
                x_msg_data               => x_msg_data,
                p_request_id             => p_request_id,
                p_object_version_number  => p_object_version_number,
                p_resp_appl_id           => p_resp_appl_id,
                p_resp_id                => p_resp_id,
                p_last_updated_by        => p_last_updated_by,
                p_last_update_login      => p_last_update_login,
                p_last_update_date       => p_last_update_date,
                p_invocation_mode        => p_invocation_mode,
                p_service_request_rec    => p_service_request_rec,
                p_update_desc_flex       => p_update_desc_flex,
                p_notes                  => p_notes,
                p_contacts               => p_contacts,
                p_audit_comments         => p_audit_comments,
                p_called_by_workflow     => p_called_by_workflow,
                p_workflow_process_id    => p_workflow_process_id,
                x_workflow_process_id    => x_workflow_process_id,
                x_interaction_id         => x_interaction_id
          );

   IF (l_return_status <> FND_API.G_RET_STS_SUCCESS) THEN
            RAISE FND_API.G_EXC_ERROR;
    END IF;

      CS_GIT_USERHOOK_PKG.GIT_Update_ServiceRequest_Post(
                p_api_version      => p_api_version,
                p_init_msg_list    => p_init_msg_list,
                p_commit           => p_commit,
                p_validation_level => FND_API.G_VALID_LEVEL_FULL,
                x_return_status    => l_return_status,
                x_msg_count        => x_msg_count,
                x_msg_data         => x_msg_data,
                p_sr_rec           => p_service_request_rec,
                p_incident_id      => p_request_id,
                p_invocation_mode  => p_invocation_mode
          );

   IF (l_return_status <> FND_API.G_RET_STS_SUCCESS) THEN
        RAISE FND_API.G_EXC_ERROR;
   END IF;
*/
   NULL;

-- Standard call to get message count and if count is 1, get message info
    FND_MSG_PUB.Count_And_Get(  p_count => x_msg_count,
                                p_data  => x_msg_data );

EXCEPTION
   WHEN FND_API.G_EXC_ERROR THEN
        ROLLBACK TO CS_ServiceRequest_CUHK;
        x_return_status := FND_API.G_RET_STS_ERROR;
        FND_MSG_PUB.Count_And_Get
          ( p_count => x_msg_count,
            p_data  => x_msg_data );
    WHEN OTHERS THEN
        ROLLBACK TO CS_ServiceRequest_CUHK;
        x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
        IF FND_MSG_PUB.Check_Msg_Level(FND_MSG_PUB.G_MSG_LVL_UNEXP_ERROR) THEN
            FND_MSG_PUB.Add_Exc_Msg(G_PKG_NAME, l_api_name);
        END IF;
        FND_MSG_PUB.Count_And_Get
        (    p_count => x_msg_count,
             p_data  => x_msg_data
        );
END;

  FUNCTION  Ok_To_Generate_Msg
(p_request_id   IN NUMBER,
 p_service_request_rec   IN   CS_ServiceRequest_PVT.service_request_rec_type)
 RETURN BOOLEAN IS
 Begin
    --Return IBU_SR_CUHK.Ok_To_Generate_Msg(p_request_id, p_service_request_rec);
    NULL;
 End;

  FUNCTION Ok_To_Launch_Workflow
    ( p_request_id   IN NUMBER,
      p_service_request_rec     IN   CS_ServiceRequest_PVT.service_request_rec_type)
    RETURN BOOLEAN IS
 Begin
     return false;
 End;


END  cs_servicerequest_cuhk;
/
