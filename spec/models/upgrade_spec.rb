require 'rails_helper'

RSpec.describe Upgrade, type: :model do
  it 'requires a unique xws id' do
    Upgrade.create!(name: 'Crack Shot', xws: 'crackshot')

    duplicate = Upgrade.new(name: 'Crack Shot (again)', xws: 'crackshot')

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:xws]).to be_present
  end

  describe '#upgrade_sides' do
    it 'returns the ffg-less side first so stale FFG images are not shown' do
      upgrade = Upgrade.create!(name: 'Crack Shot', xws: 'crackshot')
      legacy  = UpgradeSide.create!(upgrade: upgrade, title: 'legacy', ffg: 7, image: 'https://dead.test/old.png')
      current = UpgradeSide.create!(upgrade: upgrade, title: 'current', image: 'https://example.test/new.png')

      expect(upgrade.upgrade_sides.to_a).to eq([current, legacy])
      expect(upgrade.upgrade_sides.first.image).to eq('https://example.test/new.png')
    end
  end
end
