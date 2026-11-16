require 'rails_helper'

RSpec.describe Importers::SquadronFromXws, :silence_output do
  let!(:rebels) { create_faction('Rebel Alliance', xws: 'rebelalliance') }
  let!(:scum)   { create_faction('Scum and Villainy', xws: 'scumandvillainy') }
  let!(:xwing)  { create_ship('T-65 X-wing', xws: 't65xwing') }
  let!(:ywing)  { create_ship('BTL-A4 Y-wing', xws: 'btla4ywing') }
  let!(:luke)   { create_pilot('Luke Skywalker', xws: 'lukeskywalker', ship: xwing, faction: rebels) }
  let!(:rebel_bomber) { create_pilot('Gray Squadron Bomber', xws: 'bomber', ship: ywing, faction: rebels) }
  let!(:scum_bomber)  { create_pilot('Crymorah Goon', xws: 'bomber', ship: ywing, faction: scum) }

  let!(:crack_shot) { create_upgrade('Crack Shot', type: 'Talent', xws: 'crackshot') }
  let!(:r2d2)       { create_upgrade('R2-D2', type: 'Astromech', xws: 'r2d2') }
  let!(:sense)      { create_upgrade('Sense', type: 'Force Power', xws: 'sense') }

  def xws(pilots, faction: 'rebelalliance', **extra)
    { 'faction' => faction, 'pilots' => pilots }.merge(extra.stringify_keys)
  end

  describe '.build_squadron' do
    it 'builds an unsaved squadron with its faction, name and raw xws' do
      list = xws([{ 'name' => 'lukeskywalker', 'ship' => 't65xwing' }], name: 'Red Five')

      squadron = described_class.build_squadron(list)

      expect(squadron).to be_new_record
      expect(squadron).to have_attributes(faction_id: rebels.id, name: 'Red Five')
      expect(squadron.attributes['xws']).to eq(list)
    end

    it 'accepts the xws as a JSON string' do
      squadron = described_class.build_squadron(xws([{ 'name' => 'lukeskywalker', 'ship' => 't65xwing' }]).to_json)

      expect(squadron.ship_configurations.map(&:pilot)).to eq([luke])
    end

    it 'adds one ship configuration per pilot, saved together with the squadron' do
      squadron = described_class.build_squadron(xws([
        { 'name' => 'lukeskywalker', 'ship' => 't65xwing' },
        { 'name' => 'bomber', 'ship' => 'btla4ywing' },
        { 'name' => 'bomber', 'ship' => 'btla4ywing' },
      ]))

      expect { squadron.save! }.to change(ShipConfiguration, :count).by(3)
      expect(squadron.reload.pilots).to contain_exactly(luke, rebel_bomber, rebel_bomber)
    end

    it 'picks the pilot belonging to the squadron faction when xws ids are shared' do
      rebel_list = described_class.build_squadron(xws([{ 'name' => 'bomber', 'ship' => 'btla4ywing' }]))
      scum_list  = described_class.build_squadron(xws([{ 'name' => 'bomber', 'ship' => 'btla4ywing' }], faction: 'scumandvillainy'))

      expect(rebel_list.ship_configurations.first.pilot).to eq(rebel_bomber)
      expect(scum_list.ship_configurations.first.pilot).to eq(scum_bomber)
    end

    it 'falls back to the pilot "id" key when there is no "name"' do
      squadron = described_class.build_squadron(xws([{ 'id' => 'lukeskywalker', 'ship' => 't65xwing' }]))

      expect(squadron.ship_configurations.first.pilot).to eq(luke)
    end

    it 'attaches upgrades by type and xws id' do
      squadron = described_class.build_squadron(xws([
        { 'name' => 'lukeskywalker', 'ship' => 't65xwing',
          'upgrades' => { 'talent' => ['crackshot'], 'astromech' => ['r2d2'] } },
      ]))
      squadron.save!

      expect(squadron.ship_configurations.first.upgrades).to contain_exactly(crack_shot, r2d2)
    end

    it 'understands legacy and hyphenated upgrade type keys' do
      squadron = described_class.build_squadron(xws([
        { 'name' => 'lukeskywalker', 'ship' => 't65xwing',
          'upgrades' => { 'ept' => ['crackshot'], 'amd' => ['r2d2'], 'force-power' => ['sense'] } },
      ]))

      expect(squadron.ship_configurations.first.upgrades).to contain_exactly(crack_shot, r2d2, sense)
    end

    it 'accepts the List Fortress {name, points} upgrade entries' do
      squadron = described_class.build_squadron(xws([
        { 'name' => 'lukeskywalker', 'ship' => 't65xwing',
          'upgrades' => { 'talent' => [{ 'name' => 'crackshot', 'points' => 1 }] } },
      ]))

      expect(squadron.ship_configurations.first.upgrades).to eq([crack_shot])
    end

    it 'does not match an upgrade filed under a different type' do
      squadron = described_class.build_squadron(xws([
        { 'name' => 'lukeskywalker', 'ship' => 't65xwing', 'upgrades' => { 'astromech' => ['crackshot'] } },
      ]))

      expect(squadron.ship_configurations.first.upgrades).to be_empty
    end

    it 'skips upgrades it does not know' do
      squadron = described_class.build_squadron(xws([
        { 'name' => 'lukeskywalker', 'ship' => 't65xwing', 'upgrades' => { 'talent' => ['crackshot', 'nosuchcard'] } },
      ]))

      expect(squadron.ship_configurations.first.upgrades).to eq([crack_shot])
    end

    it 'builds an empty squadron when the list has no pilots' do
      squadron = described_class.build_squadron('faction' => 'rebelalliance')

      expect(squadron.ship_configurations).to be_empty
    end

    it 'raises for an unknown ship' do
      list = xws([{ 'name' => 'lukeskywalker', 'ship' => 'deathstar' }])

      expect { described_class.build_squadron(list) }.to raise_error(RuntimeError, /Ship not found for deathstar/)
    end

    it 'raises for an unknown pilot' do
      list = xws([{ 'name' => 'jarjar', 'ship' => 't65xwing' }])

      expect { described_class.build_squadron(list) }.to raise_error(RuntimeError, /Pilot not found for jarjar/)
    end
  end

  describe '.find_with_key' do
    it 'finds a record by its xws id' do
      expect(described_class.find_with_key(Ship, 't65xwing')).to eq(xwing)
    end

    it 'retries with the known corrections for misspelled ids' do
      silencer = create_ship('TIE/vn Silencer', xws: 'tievnsilencer')

      expect(described_class.find_with_key(Ship, 'tiesilencer')).to eq(silencer)
    end

    it 'corrects misspelled pilot ids within a ship' do
      deathrain_ship = create_ship('TIE/ca Punisher', xws: 'tiecapunisher')
      deathrain      = create_pilot('Deathrain', xws: 'deathrain', ship: deathrain_ship, faction: scum)

      expect(described_class.find_with_key(deathrain_ship.pilots, 'Deathrain', 'scumandvillainy')).to eq(deathrain)
    end
  end

  describe '.normalize_upgrade_type_key' do
    {
      'force'          => 'Force Power',
      'force-power'    => 'Force Power',
      'forcepower'     => 'Force Power',
      'ept'            => 'Talent',
      'amd'            => 'Astromech',
      'mod'            => 'Modification',
      'tactical-relay' => 'Tactical Relay',
      'tacticalrelay'  => 'Tactical Relay',
    }.each do |key, expected|
      it "maps #{key.inspect} to #{expected.inspect}" do
        expect(described_class.normalize_upgrade_type_key(key)).to eq(expected)
      end
    end

    it 'ignores case' do
      expect(described_class.normalize_upgrade_type_key('EPT')).to eq('Talent')
    end

    it 'returns other keys unchanged' do
      expect(described_class.normalize_upgrade_type_key('torpedo')).to eq('torpedo')
    end
  end
end
