require 'rails_helper'

RSpec.describe Importers::XwingData2, :silence_output do
  subject(:importer) { described_class.new }

  describe '#sync_factions_json' do
    let(:factions) { [{ 'name' => 'Rebel Alliance', 'xws' => 'rebelalliance', 'ffg' => 1, 'icon' => 'https://example.test/rebel.png' }] }

    it 'creates factions' do
      importer.sync_factions_json(factions)

      expect(Faction.find_by(xws: 'rebelalliance')).to have_attributes(name: 'Rebel Alliance', ffg: 1, icon: 'https://example.test/rebel.png')
    end

    it 'updates an existing faction, matched by xws id, instead of duplicating it' do
      existing = Faction.create!(name: 'Rebels', xws: 'rebelalliance')

      expect { importer.sync_factions_json(factions) }.not_to change(Faction, :count)
      expect(existing.reload.name).to eq('Rebel Alliance')
    end
  end

  describe '#sync_ship_json' do
    let!(:rebels) { create_faction('Rebel Alliance', xws: 'rebelalliance') }
    let(:ship_json) do
      {
        'name' => 'T-65 X-wing', 'xws' => 't65xwing', 'size' => 'Small', 'faction' => 'Rebel Alliance',
        'icon' => 'https://example.test/xwing.png',
        'pilots' => [
          {
            'name' => 'Luke Skywalker', 'xws' => 'lukeskywalker', 'caption' => 'Red Five', 'initiative' => 5,
            'limited' => 1, 'cost' => 62, 'ability' => 'Recover 1 force.', 'hyperspace' => true,
            'image' => 'https://example.test/luke.png', 'artwork' => 'https://example.test/luke-art.png',
            'slots' => ['Force Power', 'Torpedo'],
            'force' => { 'value' => 2, 'recovers' => 1, 'side' => 'light' },
            'charges' => { 'value' => 3, 'recovers' => 0 },
            'alt' => [{ 'image' => 'https://example.test/luke-alt.png', 'source' => 'Worlds 2018' }],
          },
          { 'name' => 'Blue Squadron Escort', 'xws' => 'bluesquadronescort', 'initiative' => 2, 'limited' => 0, 'cost' => 41 },
        ],
      }
    end

    it 'creates the ship' do
      importer.sync_ship_json(ship_json)

      expect(Ship.find_by(xws: 't65xwing')).to have_attributes(name: 'T-65 X-wing', size: 'Small', icon: 'https://example.test/xwing.png')
    end

    it 'creates its pilots in the ship faction' do
      importer.sync_ship_json(ship_json)

      ship = Ship.find_by(xws: 't65xwing')
      expect(ship.pilots.pluck(:xws)).to contain_exactly('lukeskywalker', 'bluesquadronescort')
      expect(ship.pilots.find_by(xws: 'lukeskywalker')).to have_attributes(
        faction: rebels, name: 'Luke Skywalker', caption: 'Red Five', initiative: 5, limited: 1, cost: 62,
        ability: 'Recover 1 force.', hyperspace: true,
        image: 'https://example.test/luke.png', artwork: 'https://example.test/luke-art.png',
        force_value: 2, force_recovers: 1, force_side: 'light', charges_value: 3, charges_recovers: 0
      )
    end

    it 'records pilot slots and alternate art' do
      importer.sync_ship_json(ship_json)

      luke = Pilot.find_by(xws: 'lukeskywalker')
      expect(luke.pilot_slots.pluck(:name)).to contain_exactly('Force Power', 'Torpedo')
      expect(luke.pilot_alts.pluck(:image, :source)).to eq([['https://example.test/luke-alt.png', 'Worlds 2018']])
    end

    it 'finds the faction by xws id as well as by name' do
      importer.sync_ship_json(ship_json.merge('faction' => 'rebelalliance'))

      expect(Pilot.find_by(xws: 'lukeskywalker').faction).to eq(rebels)
    end

    it 'updates in place when synced again' do
      importer.sync_ship_json(ship_json)
      ship_json['pilots'].first['cost'] = 70

      expect { importer.sync_ship_json(ship_json) }
        .to not_change(Ship, :count)
        .and not_change(Pilot, :count)
        .and not_change(PilotSlot, :count)
        .and not_change(PilotAlt, :count)
      expect(Pilot.find_by(xws: 'lukeskywalker').cost).to eq(70)
    end

    it 'keeps pilots with the same xws id in different factions apart' do
      scum = create_faction('Scum and Villainy', xws: 'scumandvillainy')
      importer.sync_ship_json(ship_json)

      importer.sync_ship_json(ship_json.merge('faction' => 'Scum and Villainy'))

      expect(Pilot.where(xws: 'lukeskywalker').map(&:faction)).to contain_exactly(rebels, scum)
      expect(Ship.where(xws: 't65xwing').count).to eq(1)
    end
  end

  describe '#sync_upgrades_json' do
    let(:upgrades) do
      [{
        'name' => 'Proton Torpedoes', 'xws' => 'protontorpedoes', 'limited' => 0, 'hyperspace' => true,
        'cost' => { 'value' => 13 },
        'sides' => [{
          'title' => 'Proton Torpedoes', 'type' => 'Torpedo', 'ability' => 'Attack (lock): Spend 1 charge.',
          'image' => 'https://example.test/proton.png', 'artwork' => 'https://example.test/proton-art.png',
          'charges' => { 'value' => 2, 'recovers' => 0 },
          'attack' => { 'arc' => 'Front Arc', 'value' => 4, 'minrange' => 2, 'maxrange' => 3, 'ordnance' => true },
        }],
      }]
    end

    it 'creates the upgrade' do
      importer.sync_upgrades_json(upgrades)

      expect(Upgrade.find_by(xws: 'protontorpedoes')).to have_attributes(name: 'Proton Torpedoes', limited: 0, cost: 13, hyperspace: true)
    end

    it 'creates the card side with its charges and attack' do
      importer.sync_upgrades_json(upgrades)

      expect(Upgrade.find_by(xws: 'protontorpedoes').upgrade_sides.to_a).to match([
        have_attributes(
          title: 'Proton Torpedoes', upgrade_type: 'Torpedo', ability: 'Attack (lock): Spend 1 charge.',
          image: 'https://example.test/proton.png', artwork: 'https://example.test/proton-art.png',
          charges_value: 2, charges_recovers: 0,
          attack_arc: 'Front Arc', attack_value: 4, attack_minrange: 2, attack_maxrange: 3, attack_ordnance: true
        ),
      ])
    end

    it 'records device and force details' do
      importer.sync_upgrades_json([
        { 'name' => 'Proton Bombs', 'xws' => 'protonbombs', 'sides' => [{
          'title' => 'Proton Bombs', 'type' => 'Device',
          'device' => { 'name' => 'Proton Bomb', 'type' => 'Bomb', 'effect' => 'Each ship at range 0-1 suffers 1 crit.' },
        }] },
        { 'name' => 'Hate', 'xws' => 'hate', 'sides' => [{
          'title' => 'Hate', 'type' => 'Force Power', 'force' => { 'value' => 1, 'recovers' => 0, 'side' => 'dark' },
        }] },
      ])

      expect(Upgrade.find_by(xws: 'protonbombs').upgrade_sides.first)
        .to have_attributes(device_name: 'Proton Bomb', device_type: 'Bomb', device_effect: 'Each ship at range 0-1 suffers 1 crit.')
      expect(Upgrade.find_by(xws: 'hate').upgrade_sides.first)
        .to have_attributes(force_value: 1, force_recovers: 0, force_side: 'dark')
    end

    it 'creates both sides of a dual card in order' do
      importer.sync_upgrades_json([{
        'name' => 'Pivot Wing', 'xws' => 'pivotwing',
        'sides' => [{ 'title' => 'Pivot Wing (Closed)', 'type' => 'Configuration' }, { 'title' => 'Pivot Wing (Open)', 'type' => 'Configuration' }],
      }])

      expect(Upgrade.find_by(xws: 'pivotwing').upgrade_sides.map(&:title)).to eq(['Pivot Wing (Closed)', 'Pivot Wing (Open)'])
    end

    it 'updates the existing sides when synced again' do
      importer.sync_upgrades_json(upgrades)
      upgrades.first['cost'] = { 'value' => 12 }
      upgrades.first['sides'].first['image'] = 'https://example.test/proton-v2.png'

      expect { importer.sync_upgrades_json(upgrades) }
        .to not_change(Upgrade, :count)
        .and not_change(UpgradeSide, :count)

      upgrade = Upgrade.find_by(xws: 'protontorpedoes')
      expect(upgrade.cost).to eq(12)
      expect(upgrade.upgrade_sides.first.image).to eq('https://example.test/proton-v2.png')
    end

    it 'leaves a legacy side with an ffg id untouched and adds a current one beside it' do
      upgrade = Upgrade.create!(name: 'Proton Torpedoes', xws: 'protontorpedoes')
      legacy  = UpgradeSide.create!(upgrade: upgrade, title: 'Proton Torpedoes', ffg: 251, image: 'https://dead.test/proton.png')

      importer.sync_upgrades_json(upgrades)

      expect(legacy.reload.image).to eq('https://dead.test/proton.png')
      expect(upgrade.upgrade_sides.map(&:image)).to eq(['https://example.test/proton.png', 'https://dead.test/proton.png'])
    end

    it 'tolerates upgrades without a cost' do
      importer.sync_upgrades_json([{ 'name' => 'Free', 'xws' => 'free', 'sides' => [] }])

      expect(Upgrade.find_by(xws: 'free').cost).to be_nil
    end
  end

  describe '#sync_conditions_json' do
    let(:conditions) { [{ 'name' => 'Hunted', 'xws' => 'hunted', 'ability' => 'After you are destroyed...', 'image' => 'https://example.test/hunted.png' }] }

    it 'creates conditions' do
      importer.sync_conditions_json(conditions)

      expect(Condition.find_by(xws: 'hunted'))
        .to have_attributes(name: 'Hunted', ability: 'After you are destroyed...', image_path: 'https://example.test/hunted.png')
    end

    it 'updates an existing condition instead of duplicating it' do
      importer.sync_conditions_json(conditions)
      conditions.first['ability'] = 'Errata.'

      expect { importer.sync_conditions_json(conditions) }.not_to change(Condition, :count)
      expect(Condition.find_by(xws: 'hunted').ability).to eq('Errata.')
    end
  end

  describe '#xwing_data2_version' do
    def stub_github(parsed_response)
      allow(HTTParty).to receive(:get).with(described_class::XWD2_URL, timeout: 5)
                                      .and_return(double('response', present?: true, parsed_response: parsed_response))
    end

    it 'reads the version out of the base64 package.json GitHub returns' do
      stub_github('content' => Base64.encode64({ name: 'xwing-data2', version: '2.4.1' }.to_json))

      expect(importer.xwing_data2_version).to eq('2.4.1')
    end

    it 'is nil when GitHub returns no content' do
      stub_github('message' => 'API rate limit exceeded')

      expect(importer.xwing_data2_version).to be_nil
    end

    it 'is nil when package.json has no version' do
      stub_github('content' => Base64.encode64({ name: 'xwing-data2' }.to_json))

      expect(importer.xwing_data2_version).to be_nil
    end
  end

  describe '#sync_all' do
    let(:fixture_repo) { Rails.root.join('spec/fixtures/xwing-data2') }

    before do
      # Stand in for cloning/pulling the xwing-data2 repository
      allow(importer).to receive(:update_submodule) { importer.instance_variable_set(:@dataroot, fixture_repo) }
    end

    it 'does nothing when the stored version is already current' do
      KeyValueStoreRecord.set!('xwing_data2_version', '9.9.9')
      allow(importer).to receive(:xwing_data2_version).and_return('9.9.9')

      expect(importer.sync_all).to be(false)
      expect(importer).not_to have_received(:update_submodule)
      expect(Faction.count).to eq(0)
    end

    context 'when a new version is available' do
      before do
        KeyValueStoreRecord.set!('xwing_data2_version', '9.9.8')
        allow(importer).to receive(:xwing_data2_version).and_return('9.9.9')
      end

      it 'imports everything listed in the manifest' do
        importer.sync_all

        expect(Faction.pluck(:xws)).to contain_exactly('rebelalliance', 'galacticempire')
        expect(Ship.pluck(:xws)).to eq(['t65xwing'])
        expect(Pilot.pluck(:xws)).to contain_exactly('lukeskywalker', 'bluesquadronescort')
        expect(Pilot.find_by(xws: 'lukeskywalker').pilot_slots.pluck(:name)).to contain_exactly('Force Power', 'Torpedo', 'Astromech')
        expect(Upgrade.pluck(:xws)).to eq(['crackshot'])
        expect(UpgradeSide.pluck(:upgrade_type, :charges_value)).to eq([['Talent', 1]])
        expect(Condition.pluck(:xws)).to eq(['hunted'])
      end

      it 'records the version it synced' do
        importer.sync_all

        expect(KeyValueStoreRecord.get('xwing_data2_version')).to eq('9.9.9')
      end

      it 'creates nothing new on a second run' do
        importer.sync_all
        KeyValueStoreRecord.set!('xwing_data2_version', '9.9.8')

        expect { importer.sync_all }.not_to change {
          [Faction, Ship, Pilot, PilotSlot, Upgrade, UpgradeSide, Condition].map(&:count)
        }
      end

      it 'imports lists that the squadron importer can then resolve' do
        importer.sync_all

        squadron = Importers::SquadronFromXws.build_squadron(
          'faction' => 'rebelalliance',
          'pilots'  => [{ 'id' => 'lukeskywalker', 'ship' => 't65xwing', 'upgrades' => { 'talent' => ['crackshot'] } }]
        )

        expect(squadron.ship_configurations.first.pilot.name).to eq('Luke Skywalker')
        expect(squadron.ship_configurations.first.upgrades.map(&:name)).to eq(['Crack Shot'])
      end
    end
  end

  describe '#reset_pilots' do
    it 'clears the pilot slots' do
      pilot = create_pilot('Luke Skywalker', ship: create_ship('T-65 X-wing'), faction: create_faction)
      PilotSlot.create!(pilot: pilot, name: 'Torpedo')

      expect { importer.reset_pilots }.to change(PilotSlot, :count).to(0)
    end
  end
end
