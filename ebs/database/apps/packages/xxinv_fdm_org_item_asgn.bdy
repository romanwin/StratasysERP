create or replace 
package body xxinv_fdm_org_item_asgn IS
--
--
  --------------------------------------------------------------------
  --  name:              xxinv_fdm_org_item_asgn
  --  create by:         Sanjai K Misra
  --  Revision:          1.0
  --  creation date:     01-Jul-14
  --------------------------------------------------------------------
  --  purpose :          Copy UME Items to org under SSUS
  --                     Yhis package was created for change request CHG0032038
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0                Sanjai K Misra    Initial Creation
  --  2.0  25-Sep-2014   Sanjai K Misra    Modified cursor c_org of procedure
  --                                       assign item and selected only ENABLED
  --                                       organizations
--
--
procedure write_msg
( p_msg varchar2
) IS
BEGIN
  if fnd_global.conc_request_id > 0
  then 
     fnd_file.put_line( fnd_file.log, p_msg);
  else
     dbms_output.put_line(p_msg);
  end if;
END write_msg;
--
--
PROCEDURE get_item_Details (p_item_rec IN OUT  INV_ITEM_GRP.Item_rec_type) IS
BEGIN
  SELECT PRIMARY_UNIT_OF_MEASURE
    INTO p_item_rec.primary_unit_of_measure
    FROM mtl_system_items_b
   WHERE segment1 = p_item_rec.segment1
     and organization_id = 91
  ;
EXCEPTION
  WHEN OTHERS THEN 
    write_msg('Error in Procedure get_item_Details');
    write_msg('Error Text = ' || sqlerrm);
    write_msg('Segment1 = ' || p_item_rec.segment1);
END;
--
--
FUNCTION does_item_exists 
( p_item_number VARCHAR2
, p_organization_id NUMBER
) RETURN boolean IS
  l_exists VARCHAR2(30);
BEGIN
  SELECT 'Y'
    INTO l_exists
    FROM mtl_system_items_b
   WHERE segment1 = p_item_number
     AND organization_id = p_organization_id;
  RETURN TRUE;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN FALSE;
END does_item_exists;

--
--
PROCEDURE assign_item 
( p_item_number VARCHAR2
) IS
  i number;
  l_err_tbl       INV_ITEM_GRP.Error_tbl_type;
  l_item_rec_in   INV_ITEM_GRP.Item_rec_type;
  l_item_rec_out  INV_ITEM_GRP.Item_rec_type;
  l_template_name VARCHAR2(2000);
  l_return_status VARCHAR2(20);
  l_msg_count     NUMBER;
  x_message_list  error_handler.error_tbl_type;

  l_msg_data varchar2(2000);
  
  CURSOR c_orgs is 
    select par.organization_code, organization_id
      from fnd_lookups lk
         , mtl_parameters par
     where lookup_type = 'XXSSUS_FDM_INV_ORGS'
       and par.organization_code = lk.lookup_code
       and lk.enabled_flag = 'Y'
       and nvl(lk.start_date_active,SYSDATE-1) <= SYSDATE
       and nvl(lk.end_date_active  ,SYSDATE+1) >= SYSDATE
     order by decode(lookup_code, 'USE','1',lookup_code)
    ;

--
--
begin
  
  write_msg('.');

  FOR l_orgs in c_orgs
  LOOP
     l_item_rec_in.organization_id        := l_orgs.organization_id;
     l_item_rec_in.segment1               := p_item_number;

     if  l_item_rec_in.organization_id  = 740
     then
        l_template_name := 'SSUS USE Fin Good';
        l_item_rec_in.planner_code := fnd_api.G_MISS_CHAR;
     else
       l_template_name := 'SSUS Org Fin Good';
       l_item_rec_in.planner_code := 'EP01';
    end if;
 
    IF does_item_exists (l_item_rec_in.segment1 , l_item_rec_in.organization_id) = FALSE
    THEN
       get_item_Details(l_item_rec_in);
       ego_item_pub.Assign_Item_To_Org
       ( p_api_version      => 1.0
       , p_init_msg_list    => fnd_api.g_true
       , p_commit           => fnd_api.g_false
       , p_Item_Number      => l_item_rec_in.segment1 
       , p_Organization_Id  => l_item_rec_in.organization_id
       , x_return_status    => l_return_status
       , x_msg_count        => l_msg_count
       ) ;


       --write_msg('Return Status = ' || l_return_status);
       --write_msg('Message Count = ' || l_msg_count);
       IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
       THEN
          write_msg('Error while assigning item ' || l_item_rec_in.segment1 || 
                    ' To Organization ' || l_orgs.organization_code || '. Error Messages Messages are listed below.');
          Error_Handler.GET_MESSAGE_LIST(x_message_list=>x_message_list);
          FOR j IN 1..x_message_list.COUNT LOOP
             write_msg('.. ' || x_message_list(j).message_text);
          END LOOP;
       ELSE
          --
          -- Item has been assigned to org successfully, so now update item template
          --   
          l_err_tbl.delete;
          inv_item_grp.Update_Item
          ( p_Item_rec       => l_item_rec_in
          , x_Item_rec       => l_item_rec_out 
          , x_return_status  => l_return_status
          , x_Error_tbl      => l_err_tbl
          , p_Template_Name  => l_template_name
          ) ;

          IF l_err_tbl.COUNT > 0
          THEN
             write_msg('.. Error in Updating Template for Item ' || l_item_rec_in.segment1 || 
                       ' Organization = '                        || l_orgs.organization_code     ||
                       ' Error Messages are Listed Below.'
                      );
             FOR i in l_err_tbl.FIRST..l_err_tbl.LAST
             LOOP
                write_msg('.. ' || l_err_tbl(i).message_text);
             END LOOP;
          ELSE
             write_msg('Template ' || l_template_name || ' assigned to Item ' || l_item_rec_in.segment1 || 
                       ', Org ' ||  l_orgs.organization_code || ' Successfully.'
                      );
          END IF; -- check for Error in Template update
       END IF; -- Check for erro in Org Assignment
    ELSE
      write_msg('Item ' || l_item_rec_in.segment1 || 
                ' is Already Assigned to Org ' ||  l_orgs.organization_code
               );
      l_return_status := FND_API.G_RET_STS_SUCCESS;
    END IF;
  END LOOP;
end;
--
--
PROCEDURE process_items
( errbuf      OUT VARCHAR2
, retcode     OUT VARCHAR2 
, p_file_name     VARCHAR2
, p_directory     VARCHAR2
) IS
  l_fh_read      UTL_FILE.file_type;
  l_fname_read   VARCHAR2(80);
  l_buffer       VARCHAR2(32767);

--  p_directory     VARCHAR2(250) := '/UtlFiles/shared/DEV' ; --'XXOBJT_UTLFILES_DIR';
  p_table_name    VARCHAR2(30) := 'XXOBJT_CONV_ITEMS';
  p_template_name VARCHAR2(80) := 'XXSSUS_ORG_ASGN';
  p_expected_num_of_rows NUMBER;
  
  CURSOR c_items is 
    select item_code 
         , rowid
      from xxobjt_conv_items
     where request_id        = fnd_global.conc_request_id
       and trans_to_int_code = 'N'
       and item_code is not null
    ;
BEGIN


/*
  l_fname_read  := p_filename;               -- This file must exist and have read permissions
 
  l_fh_read     := UTL_FILE.fopen('XXOBJT_UTLFILES_DIR', l_fname_read , 'r');
  LOOP
     BEGIN
        UTL_FILE.get_line(l_fh_read,l_buffer);
        write_msg('Processing Item ' || l_buffer);
        assign_item(l_buffer);
     EXCEPTION
       WHEN NO_DATA_FOUND THEN
         l_buffer := NULL;
         EXIT;
     END ;

  END LOOP;
  --
  --
  UTL_FILE.fclose(l_fh_read);
 */
 
    xxobjt_table_loader_util_pkg.load_file
    ( errbuf                 => errbuf
    , retcode                => retcode
    , p_table_name           => p_table_name
    , p_template_name        => p_template_name
    , p_file_name            => p_file_name
    , p_directory            => p_directory
    , p_expected_num_of_rows => p_expected_num_of_rows
    ) ;
    
    IF retcode <> 0
    THEN 
       write_msg('Error return from Loading Conversion Table');
       write_msg('Error Text = ' || errbuf);
       write_msg('Return Code = ' || retcode);
       return;
    END IF;
    
    FOR l_rec in c_items
    LOOP
        write_msg('Processing Item ' || l_rec.item_code);
        assign_item( l_rec.item_code);
        update xxobjt_conv_items
          set trans_to_int_code = 'S'
            , request_id = fnd_global.conc_request_id
         where rowid = l_rec.rowid;
    END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    IF UTL_FILE.is_open(l_fh_read)
    THEN
      UTL_FILE.fclose(l_fh_read);
    END IF;

    DBMS_OUTPUT.put_line('Error Code   :' || sqlcode);
    DBMS_OUTPUT.put_line('Error Message:' || sqlerrm);
END;
--begin
--  i := 1;
--  process_items('items.csv');
--end;
end;
/