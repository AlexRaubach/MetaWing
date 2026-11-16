require 'rails_helper'

# Validations and scopes on the card-catalog models (ships, pilots,
# conditions) and on tournaments.
RSpec.describe 'catalog models', type: :model do
  describe Ship do
    it 'requires a unique xws id' do
      create_ship('T-65 X-wing', xws: 't65xwing')

      expect(Ship.new(name: 'Another', xws: 't65xwing')).not_to be_valid
    end

    it 'has a scope for each base size' do
      small  = create_ship('TIE/ln Fighter', size: 'small')
      medium = create_ship('ARC-170', size: 'medium')
      large  = create_ship('YT-1300', size: 'large')
      huge   = create_ship('CR90 Corvette', size: 'huge')

      expect(Ship.small).to eq([small])
      expect(Ship.medium).to eq([medium])
      expect(Ship.large).to eq([large])
      expect(Ship.huge).to eq([huge])
    end

    it 'lists the factions that fly it once per faction' do
      rebels = create_faction('Rebel Alliance')
      scum   = create_faction('Scum and Villainy')
      ywing  = create_ship('BTL-A4 Y-wing')
      create_pilot('Dutch Vander', ship: ywing, faction: rebels)
      create_pilot('Kavil', ship: ywing, faction: scum)

      expect(ywing.factions).to contain_exactly(rebels, scum)
    end
  end

  describe Pilot do
    let(:rebels) { create_faction('Rebel Alliance') }
    let(:scum)   { create_faction('Scum and Villainy') }
    let(:ywing)  { create_ship('BTL-A4 Y-wing') }
    let(:xwing)  { create_ship('T-65 X-wing') }

    before { create_pilot('Gray Squadron Bomber', xws: 'bomber', ship: ywing, faction: rebels) }

    it 'rejects a duplicate xws id on the same ship and faction' do
      expect(Pilot.new(name: 'Dupe', xws: 'bomber', ship: ywing, faction: rebels)).not_to be_valid
    end

    it 'allows the same xws id for another faction or another ship' do
      expect(Pilot.new(name: 'Scum bomber', xws: 'bomber', ship: ywing, faction: scum)).to be_valid
      expect(Pilot.new(name: 'X-wing bomber', xws: 'bomber', ship: xwing, faction: rebels)).to be_valid
    end

    it 'requires a ship and a faction' do
      pilot = Pilot.new(name: 'Nobody', xws: 'nobody')

      expect(pilot).not_to be_valid
      expect(pilot.errors.attribute_names).to include(:ship, :faction)
    end
  end

  describe Condition do
    it 'requires a unique xws id but no pilot or upgrade' do
      Condition.create!(name: 'Hunted', xws: 'hunted')

      expect(Condition.new(name: 'Hunted', xws: 'hunted')).not_to be_valid
      expect(Condition.new(name: 'Listening Device', xws: 'listeningdevice')).to be_valid
    end
  end

  describe Tournament do
    it 'requires a unique List Fortress id' do
      existing = create_tournament

      duplicate = Tournament.new(lists_juggler_id: existing.lists_juggler_id,
                                 tournament_type: existing.tournament_type, format: existing.format)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:lists_juggler_id]).to be_present
    end

    it 'does not require a venue' do
      expect(create_tournament(venue: nil)).to be_persisted
    end
  end
end
