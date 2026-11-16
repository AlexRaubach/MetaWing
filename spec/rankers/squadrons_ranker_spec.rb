require 'rails_helper'

RSpec.describe Rankers::SquadronsRanker do
  include_context 'meta scenario'

  # Takes ranking configuration overrides and ranker filters in one go
  def rank(**options)
    configuration, filters = ranker_arguments(options)
    described_class.new(configuration, **{ limit: 10 }.merge(filters))
  end

  def squadrons(ranker)
    ranker.squadrons.to_a
  end

  it 'lists cut finishers first, then by swiss standing' do
    expect(squadrons(rank)).to eq([luke_and_wedge, solo_luke, howl_swarm])
  end

  it 'prefers the larger tournament between equal standings' do
    small_winner = create_squadron(tournament: casual_night, faction: empire, ships: [howlrunner],
                                   swiss_standing: 1, elimination_standing: 1)

    expect(squadrons(rank).first(2)).to eq([luke_and_wedge, small_winner])
  end

  it 'treats a missing or zero standing as last' do
    unranked = create_squadron(tournament: store_championship, faction: empire, ships: [howlrunner], swiss_standing: 0)

    expect(squadrons(rank).last).to eq(unranked)
  end

  it 'returns the two most notable squadrons by default' do
    expect(described_class.new(ranking_config).squadrons.to_a).to eq([luke_and_wedge, solo_luke])
  end

  it 'reports the totals for the filtered period, regardless of the limit' do
    ranker = described_class.new(ranking_config, limit: 1)

    expect([ranker.number_of_tournaments, ranker.number_of_squadrons]).to eq([2, 3])
  end

  it 'returns full squadron records, xws included' do
    expect(squadrons(rank).first.xws['name']).to eq('Red Squadron')
  end

  describe 'filters' do
    it 'by date' do
      expect(squadrons(rank(ranking_start: today - 500))).to include(ancient_howl)
      expect(squadrons(rank)).not_to include(ancient_howl)
    end

    it 'by ship, listing a squadron once even if it fields several' do
      expect(squadrons(rank(ship_id: xwing.id))).to eq([luke_and_wedge, solo_luke])
    end

    it 'by pilot' do
      expect(squadrons(rank(pilot_id: howlrunner.id))).to eq([howl_swarm])
    end

    it 'by upgrade' do
      expect(squadrons(rank(upgrade_id: crack_shot.id))).to eq([solo_luke, howl_swarm])
    end

    it 'by ship combo' do
      expect(squadrons(rank(ship_combo_id: tie_combo.id))).to eq([howl_swarm])
    end

    it 'by tournament type and format' do
      expect(squadrons(rank(tournament_type: casual_type.id))).to eq([solo_luke])
      expect(squadrons(rank(format_id: extended.id))).to eq([luke_and_wedge, howl_swarm])
    end
  end
end
