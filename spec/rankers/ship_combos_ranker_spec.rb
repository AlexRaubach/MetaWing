require 'rails_helper'

RSpec.describe Rankers::ShipCombosRanker do
  include_context 'meta scenario'

  # Takes ranking configuration overrides and ranker filters in one go
  def rank(**options)
    configuration, filters = ranker_arguments(options)
    described_class.new(configuration, **filters)
  end

  def ids(ranker)
    ranker.ship_combos.map(&:id)
  end

  it 'ranks ship combos by their average percentile' do
    ranker = rank

    expect(ids(ranker)).to eq([double_xwing_combo.id, single_xwing_combo.id, tie_combo.id])
    expect(ranker.ship_combos.map(&:weight)).to match([be_within(1e-6).of(1.0), be_within(1e-6).of(0.75), be_within(1e-6).of(0.5)])
  end

  it 'describes each combo with its archetype name, faction and usage' do
    expect(rank.ship_combos.first).to include(
      id: double_xwing_combo.id, archetype_name: 'Double X', faction: 'Rebel Alliance', squadrons: 1, tournaments: 1
    )
    expect(rank.ship_combos.second.archetype_name).to be_nil
  end

  it 'lists the ships of each ranked combo, one entry per copy' do
    xwing_entry = { id: xwing.id, name: 'T-65 X-wing', xws: 't65xwing' }

    expect(rank.ships).to eq(
      double_xwing_combo.id => [xwing_entry, xwing_entry],
      single_xwing_combo.id => [xwing_entry],
      tie_combo.id          => [{ id: tie_fighter.id, name: 'TIE/ln Fighter', xws: 'tielnfighter' }]
    )
  end

  it 'reports the totals for the filtered period' do
    ranker = rank

    expect([ranker.number_of_tournaments, ranker.number_of_squadrons]).to eq([2, 3])
  end

  it 'counts squadrons across tournaments in the date range' do
    tie_row = rank(ranking_start: today - 500).ship_combos.detect { |combo| combo.id == tie_combo.id }

    expect(tie_row).to include(squadrons: 2, tournaments: 2)
    expect(tie_row.weight).to be_within(1e-6).of(0.75)
  end

  describe 'filters' do
    it 'by ship' do
      expect(ids(rank(ship_id: xwing.id))).to eq([double_xwing_combo.id, single_xwing_combo.id])
    end

    it 'by pilot' do
      expect(ids(rank(pilot_id: wedge.id))).to eq([double_xwing_combo.id])
    end

    it 'by upgrade' do
      expect(ids(rank(upgrade_id: crack_shot.id))).to eq([single_xwing_combo.id, tie_combo.id])
    end

    it 'by ship combo' do
      expect(ids(rank(ship_combo_id: tie_combo.id))).to eq([tie_combo.id])
    end

    it 'by tournament type and format' do
      expect(ids(rank(tournament_type: casual_type.id))).to eq([single_xwing_combo.id])
      expect(ids(rank(format_id: extended.id))).to eq([double_xwing_combo.id, tie_combo.id])
    end
  end

  it 'limits the result to the top entries, and their ships' do
    ranker = rank(limit: 2)

    expect(ids(ranker)).to eq([double_xwing_combo.id, single_xwing_combo.id])
    expect(ranker.ships.keys).to contain_exactly(double_xwing_combo.id, single_xwing_combo.id)
  end
end
