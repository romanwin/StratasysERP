create or replace PACKAGE BODY XXINV_LOT_UPDATE_PKG IS
--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXINV_LOT_UPDATE_PKG.bdy
  Author's Name:   Sandeep Akula
  Date Written:    16-SEP-2015
  Purpose:         Update Lot DFF (Country of Origin - Attribute1)
  Program Style:   Stored Package BODY
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-SEP-2015        1.0                  Sandeep Akula    Initial Version (CHG0036196)
  ---------------------------------------------------------------------------------------------------*/

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    update_lot_dff
  Author's Name:   Sandeep Akula
  Date Written:    16-SEP-2015
  Purpose:         This Procedure updates column attribute1 in the lots table
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-SEP-2015        1.0                  Sandeep Akula     Initial Version -- CHG0036196
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE update_lot_dff(errbuf OUT VARCHAR2,
                         retcode OUT NUMBER,
                         p_backward_days IN NUMBER) IS
                         
CURSOR c_lots is
select organization_id, 
       inventory_item_id, 
       lot_number,
       creation_date
from mtl_lot_numbers 
where attribute1 is null
  and creation_date >= (sysdate - p_backward_days);
  
TYPE t_lots_rec IS
TABLE OF c_lots%ROWTYPE
INDEX BY PLS_INTEGER;

l_lots_rec t_lots_rec;
l_country hr_locations_all.country%type;
l_cnt1 NUMBER;
l_cnt2 NUMBER;

l_api_version      NUMBER := 1.0;
l_init_msg_list    VARCHAR2(100) := fnd_api.g_false; 
l_commit           VARCHAR2(100) := fnd_api.g_false;
l_source           NUMBER := 2;
l_return_status    VARCHAR2(1);
l_msg_data         VARCHAR2(32767);
l_msg_count        NUMBER;
x_mtl_lot_numbers_rec  mtl_lot_numbers%ROWTYPE;
l_mtl_lot_numbers_rec  mtl_lot_numbers%ROWTYPE;
                         
BEGIN

FND_FILE.PUT_LINE(FND_FILE.LOG,'Inside Procedure update_lot_dff');
l_cnt1 := 0;
l_cnt2 := 0;
 OPEN c_lots;
 LOOP
 FETCH c_lots
 BULK COLLECT INTO l_lots_rec LIMIT 100;
 
 FND_FILE.PUT_LINE(FND_FILE.LOG,'Total rec count :'||l_lots_rec.COUNT );
 EXIT WHEN l_lots_rec.count = 0;
 
     FOR indx IN 1 .. l_lots_rec.COUNT 
        LOOP
        
          FND_FILE.PUT_LINE(FND_FILE.LOG,'Start of Lot Update, Lot Number:'||l_lots_rec(indx).lot_number||' '||
                                                               'Organization ID :'||l_lots_rec(indx).organization_id||' '||
                                                               'Item ID :'||l_lots_rec(indx).inventory_item_id);
          
           BEGIN
             SELECT country
             INTO l_country
             FROM (
              SELECT mtlt.transaction_id,
                     mln.lot_number,
                     mmt.creation_date,
                     row_number() OVER(ORDER BY mmt.creation_date ASC)   as row_num,
                     mmt.transaction_type_id,
                     hla.country
              FROM mtl_material_transactions mmt,
                   mtl_lot_numbers mln,
                   mtl_transaction_lot_numbers mtlt,  
                   hr_organization_units hou,
                   hr_locations_all hla
              WHERE 1                   = 1
              AND mmt.inventory_item_id = mln.inventory_item_id
              AND mln.lot_number        = mtlt.lot_number
              AND mln.organization_id   = mtlt.organization_id
              AND mtlt.transaction_id   = mmt.transaction_id
              AND mtlt.organization_id  = hou.organization_id
              AND hou.location_id       = hla.location_id
              AND transaction_type_id   = 44 -- WIP Completion 
              AND mln.lot_number        = l_lots_rec(indx).lot_number
              --AND mln.organization_id   = l_lots_rec(indx).organization_id
              AND mln.inventory_item_id = l_lots_rec(indx).inventory_item_id)
              WHERE row_num = 1;
            EXCEPTION
            WHEN OTHERS THEN
             l_country := NULL;
            END;
           
           IF l_country IS NOT NULL THEN
              FND_FILE.PUT_LINE(FND_FILE.LOG,'Country is not NULL');
             /*update mtl_lot_numbers 
             set attribute1= l_country,
                 last_update_date = SYSDATE,
                 last_updated_by = FND_GLOBAL.user_id
             Where organization_id= l_lots_rec(indx).organization_id
             And inventory_item_id= l_lots_rec(indx).inventory_item_id
             And lot_number= l_lots_rec(indx).lot_number;*/
                    
                     l_mtl_lot_numbers_rec.inventory_item_id := l_lots_rec(indx).inventory_item_id;
                     l_mtl_lot_numbers_rec.organization_id :=  l_lots_rec(indx).organization_id;
                     l_mtl_lot_numbers_rec.lot_number := l_lots_rec(indx).lot_number;
                     l_mtl_lot_numbers_rec.attribute1 := l_country;
                     l_mtl_lot_numbers_rec.last_update_date := SYSDATE;
                     l_mtl_lot_numbers_rec.last_updated_by := FND_GLOBAL.user_id;
             
             
                      l_msg_count := '';
                      l_msg_data := '';
                      l_return_status := '';
                      inv_lot_api_pub.update_inv_lot(x_return_status         => l_return_status,
                                                     x_msg_count             => l_msg_count,
                                                     x_msg_data              => l_msg_data,
                                                     x_lot_rec               => x_mtl_lot_numbers_rec,
                                                     p_lot_rec               => l_mtl_lot_numbers_rec,
                                                     p_source                => l_source,
                                                     p_api_version           => l_api_version,
                                                     p_init_msg_list         => l_init_msg_list,
                                                     p_commit                => l_commit);
          
                               IF l_return_status = fnd_api.g_ret_sts_success THEN
                                    COMMIT;
                                    l_cnt1 := l_cnt1 + 1;
                                    FND_FILE.PUT_LINE(FND_FILE.LOG,'Lot Number :'||l_lots_rec(indx).lot_number||' Updated Sucessfully for Item ID :'||l_lots_rec(indx).inventory_item_id||' and Org :'||l_lots_rec(indx).organization_id);
                               ELSE
                                     FND_FILE.PUT_LINE(FND_FILE.LOG,'Could not Update Lot Number :'||l_lots_rec(indx).lot_number||' for Item ID :'||l_lots_rec(indx).inventory_item_id||' and Org :'||l_lots_rec(indx).organization_id);
                                     ROLLBACK;
                                     l_cnt2 := l_cnt2 + 1;
                                       FOR i IN 1 .. l_msg_count LOOP
                                           l_msg_data := fnd_msg_pub.get( p_msg_index => i, p_encoded => 'F');
                                           FND_FILE.PUT_LINE(FND_FILE.LOG,i|| ') '|| l_msg_data);
                                       END LOOP;
                              END IF;                
             
           END IF;
            
            
            FND_FILE.PUT_LINE(FND_FILE.LOG,'End of Lot Update, Lot Number:'||l_lots_rec(indx).lot_number||' '||
                                                               'Organization ID :'||l_lots_rec(indx).organization_id||' '||
                                                               'Item ID :'||l_lots_rec(indx).inventory_item_id);
        
       END LOOP;
 END LOOP;
 CLOSE c_lots;

COMMIT;

IF l_cnt2 > 0 THEN
RETCODE := '1'; -- Warning 
ERRBUF := 'See Log Messages for details';
ELSE
RETCODE := '0'; 
ERRBUF := NULL;
END IF;

FND_FILE.PUT_LINE(FND_FILE.LOG,'Number of Updated Lots:'||l_cnt1);
FND_FILE.PUT_LINE(FND_FILE.LOG,'Number of  Failed Lots:'||l_cnt2);
FND_FILE.PUT_LINE(FND_FILE.LOG,'End of Procedure update_lot_dff');

EXCEPTION
WHEN OTHERS THEN
ROLLBACK;
RETCODE := '2'; -- Error 
ERRBUF := 'SQL Error:'||SQLERRM;
END update_lot_dff;
END XXINV_LOT_UPDATE_PKG;
/
