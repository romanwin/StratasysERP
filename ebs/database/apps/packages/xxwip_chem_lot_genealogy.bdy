create or replace package body xxwip_chem_lot_genealogy IS
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX.XX.XX    XXXXXX            XXXX
  --  1.1  31.10.2019  Bellona(TCS)      CHG0046734 - Added condition to fetch only active lot numbers
  --------------------------------------------------------------------
   PROCEDURE xxwip_match_lots(errbuf      OUT VARCHAR2,
                              retcode     OUT VARCHAR2,
                              p_job       VARCHAR2,
                              p_child_lot VARCHAR2,
                              p_org_id    NUMBER,
                              p_trx_id    NUMBER) IS

      p_lot_exists       NUMBER;
      l_lot_rec          mtl_lot_numbers%ROWTYPE;
      f_lot_rec          mtl_lot_numbers%ROWTYPE;
      mtl_exp_date       DATE;
      l_return_status    VARCHAR2(4);
      l_msg_count        NUMBER;
      l_msg_data         VARCHAR2(200);
      p_object_id        NUMBER;
      p_parent_object_id NUMBER;
      p_inv_itm_id       NUMBER;
      l_row_id           ROWID;
      assembly_num       VARCHAR2(100);
   BEGIN

      -- get the item of the assembly
      SELECT substr(msib.segment1, instr(msib.segment1, '-') + 1)
        INTO assembly_num
        FROM wip_entities we, mtl_system_items_b msib
       WHERE we.wip_entity_name = p_job AND
             msib.inventory_item_id = we.primary_item_id AND
             msib.organization_id = we.organization_id AND
             msib.organization_id = p_org_id;

      -- check if lot for this bottling job RES and MTL lot exists
      SELECT COUNT(*)
        INTO p_lot_exists
        FROM mtl_lot_numbers mln
       WHERE mln.lot_number =
             substr(p_child_lot, instr(p_child_lot, 'L') + 1) || '-' ||
             assembly_num
         AND mln.organization_id = p_org_id
         AND mln.disable_flag is null    ;          --CHG0046734

      -- if lot  doesn't exist then we create it
      IF p_lot_exists = 0 THEN

         -- create new lot

         -- get the MTL expiration date
         BEGIN
            SELECT to_date('15-' ||
                           to_char(mln.expiration_date, 'MON-YYYY'),
                           'DD-MON-YYYY')
              INTO mtl_exp_date
              FROM mtl_lot_numbers mln
             WHERE mln.lot_number = p_child_lot AND
                   mln.organization_id = p_org_id
               AND mln.disable_flag is null    ;     --CHG0046734
         EXCEPTION
            WHEN OTHERS THEN
               mtl_exp_date := NULL;
         END;

         -- get the item id of the job
         SELECT we.primary_item_id
           INTO p_inv_itm_id
           FROM wip_entities we
          WHERE we.wip_entity_name = p_job AND
                we.organization_id = p_org_id;

         l_lot_rec.inventory_item_id  := p_inv_itm_id;
         l_lot_rec.organization_id    := p_org_id;
         l_lot_rec.lot_number         := substr(p_child_lot,
                                                instr(p_child_lot, 'L') + 1) || '-' ||
                                         assembly_num;
         l_lot_rec.last_update_date   := SYSDATE;
         l_lot_rec.last_updated_by    := fnd_global.user_id;
         l_lot_rec.creation_date      := SYSDATE;
         l_lot_rec.created_by         := fnd_global.user_id;
         l_lot_rec.last_update_login  := 0;
         l_lot_rec.expiration_date    := mtl_exp_date;
         l_lot_rec.status_id          := 1;
         l_lot_rec.origination_type   := 0;
         l_lot_rec.origination_date   := SYSDATE;
         l_lot_rec.availability_type  := 1;
         l_lot_rec.inventory_atp_code := 1;
         l_lot_rec.reservable_type    := 1;

         inv_lot_api_pub.create_inv_lot(x_return_status    => l_return_status,
                                        x_msg_count        => l_msg_count,
                                        x_msg_data         => l_msg_data,
                                        x_row_id           => l_row_id,
                                        x_lot_rec          => f_lot_rec,
                                        p_lot_rec          => l_lot_rec,
                                        p_source           => 3,
                                        p_api_version      => 1.0,
                                        p_init_msg_list    => 'T',
                                        p_commit           => 'F',
                                        p_validation_level => 0,
                                        p_origin_txn_id    => p_trx_id);

      END IF;

      -- get the object id for parent and child
      SELECT mln.gen_object_id
        INTO p_object_id
        FROM mtl_lot_numbers mln
       WHERE mln.lot_number = p_child_lot AND
             mln.organization_id = p_org_id
         AND mln.disable_flag is null   ;                  --CHG0046734

      SELECT mln.gen_object_id
        INTO p_parent_object_id
        FROM mtl_lot_numbers mln
       WHERE mln.lot_number = f_lot_rec.lot_number AND
             mln.organization_id = p_org_id
         AND mln.disable_flag is null   ;                  --CHG0046734

      -- create genealogy between new lot and MTL lot
      inv_genealogy_pub.insert_genealogy(p_api_version        => 1,
                                         p_object_type        => 1,
                                         p_parent_object_type => 1,
                                         p_object_id          => p_object_id,
                                         p_parent_object_id   => p_parent_object_id,
                                         p_origin_txn_id      => p_trx_id,
                                         x_return_status      => l_return_status,
                                         x_msg_count          => l_msg_count,
                                         x_msg_data           => l_msg_data);

   END xxwip_match_lots;

END xxwip_chem_lot_genealogy;
/
