require 'fileutils'
require 'git'
require 'base64'

module Importers
  class XwingData2
    XWD2_URL = 'https://api.github.com/repos/guidokessels/xwing-data2/contents/package.json'.freeze
    XWD2_GIT_URL = 'https://github.com/guidokessels/xwing-data2.git'.freeze

    def parse_json(path)
      js_path = @dataroot + path
      js_string = File.read(js_path)
      ExecJS.eval(js_string)
    end

    def reset_pilots
      PilotSlot.destroy_all
    end

    def xwing_data2_version
      response = HTTParty.get(Importers::XwingData2::XWD2_URL, timeout: 5)

      return nil unless response.present? && response.parsed_response.dig('content').present?

      decoded_content = Base64.decode64(response.parsed_response.dig('content'))

      return nil unless decoded_content.present?

      parsed_content = JSON.parse(decoded_content)
      parsed_content&.dig('version')
    end

    def update_submodule
      @dataroot = Rails.root + 'tmp' + 'xwing-data2'
      abs_path = @dataroot + '.git'
      # puts abs_path
      if !File.exist?(abs_path)
        if Dir.exist?(@dataroot)
          puts 'Deleting xwing-data2'
          FileUtils.remove_dir(@dataroot, force = true)
        end
        puts 'Cloning the repository'
        Git.clone(Importers::XwingData2::XWD2_GIT_URL, @dataroot.to_s)
      elsif !File.directory?(abs_path)
        puts 'Deleting xwing-data2 because it is a submodule'
        FileUtils.remove_dir(@dataroot, force = true)
        puts 'Cloning the repository to replace the submodule'
        Git.clone(Importers::XwingData2::XWD2_GIT_URL, @dataroot.to_s)
      else
        puts 'Updating to the latest from the repository'
        g = Git.open(@dataroot)
        g.pull
      end
    end

    def sync_all
      latest_update = KeyValueStoreRecord.get('xwing_data2_version')
      github_version = xwing_data2_version

      return false if github_version == latest_update

      update_submodule
      @manifest = parse_json('data/' + 'manifest.json')

      sync_factions
      sync_pilots
      sync_conditions
      sync_upgrades

      KeyValueStoreRecord.set!('xwing_data2_version', github_version)
    end

    def sync_factions
      factions_path_array = @manifest['factions']
      factions_path_array.each do |faction_path|
        factions = parse_json(faction_path)
        sync_factions_json(factions)
      end
    end

    def sync_factions_json(factions_hash)
      factions_hash.each do |faction_data|
        faction = Faction.find_or_initialize_by(xws: faction_data['xws'])
        faction.name = faction_data['name']
        faction.ffg = faction_data['ffg']
        faction.icon = faction_data['icon']
        faction.save!
      end
    end

    def sync_pilots
      pilots_array = @manifest['pilots']
      pilots_array.each do |pilot|
        ships_array = pilot['ships']
        ships_array.each do |ship_path|
          ship = parse_json(ship_path)
          sync_ship_json(ship)
        end
      end
    end

    def sync_ship_json(ship_hash)
      ship = Ship.find_or_create_by(xws:ship_hash['xws'])
      ship.name = ship_hash['name']
      ship.ffg = ship_hash['ffg']
      ship.size = ship_hash['size']
      ship.icon = ship_hash['icon']
      #TODO Dial
      #TODO faction
      #TODO stats
      #TODO actions

      pilots = ship_hash['pilots']
      faction_id = (Faction.find_by(xws: ship_hash['faction']) || Faction.find_by(name: ship_hash['faction'])).id

      pilots.each do |pilot_hash|
        sync_pilot(pilot_hash,ship,faction_id)
      end

      ship.save
    end

    def sync_pilot(pilot_hash,ship,faction_id)
      pilot = Pilot.where({ship_id:ship.id,faction_id:faction_id}).find_or_create_by(xws:pilot_hash['xws'])
      pilot.ffg = pilot_hash['ffg']
      pilot.ship_id = ship.id
      pilot.faction_id = faction_id
      pilot.name = pilot_hash['name']
      pilot.caption = pilot_hash['caption'] if pilot_hash['caption'].present?

      pilot.initiative = pilot_hash['initiative']
      pilot.limited = pilot_hash['limited']
      pilot.ability = pilot_hash['ability']
      pilot.image = pilot_hash['image']
      pilot.artwork = pilot_hash['artwork']
      pilot.hyperspace = pilot_hash['hyperspace']
      pilot.cost = pilot_hash['cost']
      pilot_slots = pilot_hash['slots']
      if pilot_slots.present?
        pilot_slots.each do |slot_name|
          slot = PilotSlot.where({name:slot_name}).find_or_create_by(pilot_id:pilot.id)
          slot.name = slot_name
          slot.save
        end
      end

      pilot_alts = pilot_hash['alt']
      if pilot_alts.present?
        pilot_alts.each do |alt_hash|
          alt = PilotAlt.where({image:alt_hash['image'],source:alt_hash['source']}).find_or_create_by(pilot_id:pilot.id)
          alt.image = alt_hash['image']
          alt.source = alt_hash['source']
          alt.save
        end
      end

      if pilot_hash['charges'].present?
        pilot.charges_value = pilot_hash['charges']['value']
        pilot.charges_recovers = pilot_hash['charges']['recovers']
      end

      if pilot_hash['force'].present?
        pilot.force_value = pilot_hash['force']['value']
        pilot.force_recovers = pilot_hash['force']['recovers']
        pilot.force_side = pilot_hash['force']['side']
      end

      if !pilot.save
        puts pilot.name
        puts pilot.errors.full_messages
      end
    end

    def sync_upgrades
      upgrades_array = @manifest['upgrades']
      upgrades_array.each do |upgrade_path|
        upgrades = parse_json(upgrade_path)
        sync_upgrades_json(upgrades)
      end
    end

    def sync_upgrades_json(upgrades_hash)
      upgrades_hash.each do |upgrade_data|
        upgrade              = Upgrade.find_or_create_by(xws: upgrade_data['xws'])
        upgrade.name         = upgrade_data['name']
        upgrade.limited      = upgrade_data['limited']
        upgrade_cost = upgrade_data['cost'] #TODO VARIABLE COST

        upgrade.cost = upgrade_cost['value'] if upgrade_cost.present?
        upgrade.hyperspace = upgrade_data['hyperspace']

        upgrade_sides = upgrade_data['sides']
        upgrade_sides.each do |side|
          sync_upgrade_side_json(upgrade,side)
        end

        # TODO Restrictions
        upgrade.save
      end
    end

    def sync_upgrade_side_json(upgrade,side)
      upgrade_side = UpgradeSide.find_or_create_by(upgrade_id: upgrade.id, ffg: side['ffg'])
      upgrade_side.title = side['title']
      upgrade_side.upgrade_type = side['type']
      upgrade_side.ability = side['ability']
      # upgrade_side_slots = side['slots']
      # upgrade_side_slots.each do |side_slot|
      #   slot = Slot.find_or_create_by(name: side_slot)
      #   upgrade_side_slot = UpgradeSideSlot.find_or_create_by(upgrade_side_id: upgrade_side.id, slot_id: slot.id)
      # end
      upgrade_side.image = side['image']
      upgrade_side.artwork = side['artwork']
      upgrade_side_charges = side['charges']
      if upgrade_side_charges.present?
        upgrade_side.charges_value = upgrade_side_charges['value']
        upgrade_side.charges_recovers = upgrade_side_charges['recovers']
      end
      upgrade_side_attack = side['attack']
      if upgrade_side_attack.present?
        upgrade_side.attack_arc = upgrade_side_attack['arc']
        upgrade_side.attack_value = upgrade_side_attack['value']
        upgrade_side.attack_minrange = upgrade_side_attack['minrange']
        upgrade_side.attack_maxrange = upgrade_side_attack['maxrange']
        upgrade_side.attack_ordnance = upgrade_side_attack['ordnance']
      end

      upgrade_side_device = side['device']
      if upgrade_side_device.present?
        upgrade_side.device_name = upgrade_side_device['name']
        upgrade_side.device_type = upgrade_side_device['type']
        upgrade_side.device_effect = upgrade_side_device['effect']
      end

      upgrade_side_force = side['force']
      if upgrade_side_force.present?
        upgrade_side.force_value = upgrade_side_force['value']
        upgrade_side.force_recovers = upgrade_side_force['recovers']
        upgrade_side.force_side = upgrade_side_force['side']
      end

      # upgrade_side_alts = side['alt']
      # if upgrade_side_alts.present?
      #   upgrade_side_alts.each do |alt_hash|
      #     alt = UpgradeSideAlt.find_or_create_by(upgrade_side_id:upgrade_side.id, image: alt_hash['image'], source: alt_hash['source'])
      #   end
      # end
      # TODO Grants
      # TODO Actions

      upgrade_side.save!
    end

    def sync_conditions
      conditions_path = @manifest['conditions']
      conditions = parse_json(conditions_path)
      sync_conditions_json(conditions)
    end

    def sync_conditions_json(conditions_hash)
      conditions_hash.each do |condition_data|
        condition            = Condition.find_or_initialize_by(xws: condition_data['xws'])
        condition.name       = condition_data['name']
        condition.image_path = condition_data['image']
        condition.ability    = condition_data['ability']
        condition.save!
      end
    end
  end
end
