require 'rails_helper'

RSpec.describe Rankers::UpgradesRanker do
  include_context 'meta scenario'

  # Takes ranking configuration overrides and ranker filters in one go
  def rank(**options)
    configuration, filters = ranker_arguments(options)
    described_class.new(configuration, **filters)
  end

  def names(ranker)
    ranker.upgrades.map(&:name)
  end

  it 'ranks upgrades by the average percentile of the squadrons carrying them' do
    ranker = rank

    expect(names(ranker)).to eq(['Proton Torpedoes', 'Crack Shot'])
    expect(ranker.upgrades.map(&:weight)).to match([be_within(1e-6).of(1.0), be_within(1e-6).of(0.625)])
  end

  it 'describes each upgrade with its type, image and usage' do
    crack_row = rank.upgrades.last

    expect(crack_row).to include(
      id: crack_shot.id, xws: 'crackshot', name: 'Crack Shot', upgrade_type: 'Talent',
      image: 'https://example.test/crack.png', squadrons: 2, tournaments: 2
    )
    expect(crack_row.average_percentile).to be_within(1e-6).of(0.625)
  end

  it 'reports the totals for the filtered period' do
    ranker = rank

    expect([ranker.number_of_tournaments, ranker.number_of_squadrons]).to eq([2, 3])
  end

  it 'takes type and image from the current side when a legacy ffg side also exists' do
    UpgradeSide.create!(upgrade: crack_shot, title: 'Crack Shot', upgrade_type: 'Elite', ffg: 311, image: 'https://z-dead.test/crack.png')

    crack_rows = rank.upgrades.select { |upgrade| upgrade.id == crack_shot.id }

    expect(crack_rows.size).to eq(1)
    expect(crack_rows.first).to include(upgrade_type: 'Talent', image: 'https://example.test/crack.png', squadrons: 2)
  end

  it 'falls back to the legacy side when it is the only one' do
    UpgradeSide.where(upgrade: crack_shot).update_all(ffg: 311)

    expect(rank.upgrades.last).to include(name: 'Crack Shot', image: 'https://example.test/crack.png')
  end

  it 'does not list upgrades nobody played' do
    create_upgrade('Predator')

    expect(names(rank)).not_to include('Predator')
  end

  describe 'filters' do
    it 'by ship' do
      expect(rank(ship_id: tie_fighter.id).upgrades.map { |u| [u.name, u.squadrons] }).to eq([['Crack Shot', 1]])
    end

    it 'by pilot' do
      expect(names(rank(pilot_id: luke.id))).to eq(['Proton Torpedoes', 'Crack Shot'])
      expect(names(rank(pilot_id: wedge.id))).to eq([])
    end

    it 'by upgrade' do
      expect(names(rank(upgrade_id: proton_torpedoes.id))).to eq(['Proton Torpedoes'])
    end

    it 'by ship combo' do
      expect(names(rank(ship_combo_id: tie_combo.id))).to eq(['Crack Shot'])
    end

    it 'by tournament type and format' do
      expect(names(rank(tournament_type: store_type.id))).to eq(['Proton Torpedoes', 'Crack Shot'])
      expect(names(rank(format_id: hyperspace.id))).to eq(['Crack Shot'])
    end

    it 'by date' do
      expect(names(rank(ranking_start: today - 6))).to eq(['Crack Shot'])
    end
  end

  it 'limits the result to the top entries' do
    expect(names(rank(limit: 1))).to eq(['Proton Torpedoes'])
  end

  it 'applies the multipliers' do
    ranker = rank(widespread_use_multiplier: true)

    expect(names(ranker)).to eq(['Proton Torpedoes', 'Crack Shot'])
    expect(ranker.upgrades.map(&:weight)).to match([
      be_within(1e-6).of(1.0 * Math.log10(2)),
      be_within(1e-6).of(0.625 * Math.log10(3)),
    ])
  end
end
