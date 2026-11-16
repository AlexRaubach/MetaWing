require 'rails_helper'

RSpec.describe UpgradeSide, type: :model do
  let(:upgrade) { Upgrade.create!(name: 'Crack Shot', xws: 'crackshot') }

  describe '.preferred_first' do
    it 'puts sides without an ffg id ahead of legacy sides that have one' do
      legacy  = UpgradeSide.create!(upgrade: upgrade, title: 'legacy', ffg: 123)
      current = UpgradeSide.create!(upgrade: upgrade, title: 'current')

      expect(UpgradeSide.preferred_first).to eq([current, legacy])
    end

    it 'keeps creation order among sides of the same kind' do
      front = UpgradeSide.create!(upgrade: upgrade, title: 'front')
      back  = UpgradeSide.create!(upgrade: upgrade, title: 'back')

      expect(UpgradeSide.preferred_first).to eq([front, back])
    end
  end

  it 'requires an upgrade' do
    expect(UpgradeSide.new(title: 'orphan')).not_to be_valid
  end
end
