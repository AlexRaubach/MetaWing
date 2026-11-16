require 'rails_helper'

RSpec.describe Squadron, type: :model do
  describe '#xws' do
    it 'returns standard XWS untouched' do
      xws = { 'faction' => 'rebelalliance', 'pilots' => [{ 'name' => 'lukeskywalker', 'upgrades' => { 'talent' => ['crackshot'] } }] }

      expect(Squadron.new(xws: xws).xws).to eq(xws)
    end

    it 'collapses the proprietary {name, points} upgrade entries back to plain names' do
      squadron = Squadron.new(xws: {
        'pilots' => [{
          'name'     => 'lukeskywalker',
          'upgrades' => {
            'talent'  => [{ 'name' => 'crackshot', 'points' => 1 }],
            'torpedo' => [{ 'name' => 'protontorpedoes', 'points' => 13 }, 'plasmatorpedoes'],
          },
        }],
      })

      expect(squadron.xws['pilots'].first['upgrades']).to eq(
        'talent'  => ['crackshot'],
        'torpedo' => ['protontorpedoes', 'plasmatorpedoes']
      )
    end

    it 'handles negative point values' do
      squadron = Squadron.new(xws: { 'upgrades' => [{ 'name' => 'discount', 'points' => -2 }] })

      expect(squadron.xws).to eq('upgrades' => ['discount'])
    end

    it 'leaves the stored attribute in its raw form' do
      raw      = { 'upgrades' => [{ 'name' => 'crackshot', 'points' => 1 }] }
      squadron = Squadron.new(xws: raw)

      squadron.xws

      expect(squadron.attributes['xws']).to eq(raw)
    end

    it 'is nil when there is no xws' do
      expect(Squadron.new.xws).to be_nil
    end
  end

  it 'destroys its ship configurations along with it' do
    faction  = create_faction
    pilot    = create_pilot('Luke Skywalker', ship: create_ship('T-65 X-wing'), faction: faction)
    squadron = create_squadron(tournament: create_tournament, faction: faction, ships: [pilot])

    expect { squadron.destroy }.to change(ShipConfiguration, :count).by(-1)
  end

  it 'reaches its ships through its pilots' do
    faction  = create_faction
    xwing    = create_ship('T-65 X-wing')
    ywing    = create_ship('BTL-A4 Y-wing')
    squadron = create_squadron(tournament: create_tournament, faction: faction, ships: [
      create_pilot('Luke Skywalker', ship: xwing, faction: faction),
      create_pilot('Dutch Vander', ship: ywing, faction: faction),
    ])

    expect(squadron.ships).to contain_exactly(xwing, ywing)
  end
end
