require 'rails_helper'

RSpec.describe Rankers::PilotsRanker do
  include_context 'meta scenario'

  # Takes ranking configuration overrides and ranker filters in one go
  def rank(**options)
    configuration, filters = ranker_arguments(options)
    described_class.new(configuration, **filters)
  end

  def names(ranker)
    ranker.pilots.map(&:name)
  end

  it 'ranks pilots by their average swiss percentile' do
    ranker = rank

    expect(names(ranker)).to eq(['Wedge Antilles', 'Luke Skywalker', 'Howlrunner'])
    expect(ranker.pilots.map(&:weight)).to match([be_within(1e-6).of(1.0), be_within(1e-6).of(0.875), be_within(1e-6).of(0.5)])
  end

  it 'describes each pilot with its ship, faction and usage' do
    luke_row = rank.pilots.detect { |pilot| pilot.id == luke.id }

    expect(luke_row).to include(
      xws: 'lukeskywalker', name: 'Luke Skywalker', faction: 'Rebel Alliance',
      ship_id: xwing.id, ship_name: 'T-65 X-wing', ship_xws: 't65xwing',
      squadrons: 2, tournaments: 2
    )
    expect(luke_row.average_percentile).to be_within(1e-6).of(0.875)
    expect(luke_row.average_wlr).to be_within(1e-6).of(0.75)
  end

  it 'reports the totals for the filtered period' do
    ranker = rank

    expect(ranker.number_of_tournaments).to eq(2)
    expect(ranker.number_of_squadrons).to eq(3)
  end

  it 'leaves out tournaments outside the date range' do
    expect(rank(ranking_start: today - 6).pilots.map { |p| [p.name, p.squadrons] }).to eq([['Luke Skywalker', 1]])
  end

  it 'reaches back as far as the date range says' do
    howl_row = rank(ranking_start: today - 500).pilots.detect { |pilot| pilot.id == howlrunner.id }

    expect(howl_row.squadrons).to eq(2)
    expect(howl_row.weight).to be_within(1e-6).of(0.75)
  end

  describe 'ranking data' do
    it 'uses only the cut for "elimination", counting squadrons that missed it as 0' do
      ranker = rank(use_ranking_data: 'elimination')

      expect(ranker.pilots.map { |p| [p.name, p.weight] })
        .to eq([['Wedge Antilles', 1.0], ['Luke Skywalker', 0.5], ['Howlrunner', 0.0]])
    end

    it 'adds swiss and cut together for "all" and reports their mean as the percentile' do
      wedge_row = rank(use_ranking_data: 'all').pilots.first

      expect(wedge_row.name).to eq('Wedge Antilles')
      expect(wedge_row.weight).to be_within(1e-6).of(2.0)
      expect(wedge_row.average_percentile).to be_within(1e-6).of(1.0)
    end
  end

  describe 'multipliers' do
    it 'rewards widely used pilots' do
      ranker = rank(widespread_use_multiplier: true)

      expect(names(ranker)).to eq(['Luke Skywalker', 'Wedge Antilles', 'Howlrunner'])
      expect(ranker.pilots.first.weight).to be_within(1e-6).of(0.875 * Math.log10(3))
    end

    it 'rewards results from larger tournaments' do
      ranker = rank(large_tournament_multiplier: true)

      expect(names(ranker)).to eq(['Wedge Antilles', 'Luke Skywalker', 'Howlrunner'])
      expect(ranker.pilots.map(&:weight)).to match([
        be_within(1e-6).of(Math.log10(8)),
        be_within(1e-6).of((Math.log10(8) + 0.75 * Math.log10(4)) / 2),
        be_within(1e-6).of(0.5 * Math.log10(8)),
      ])
    end

    it 'does not change the reported average percentile' do
      ranker = rank(widespread_use_multiplier: true, large_tournament_multiplier: true)

      expect(ranker.pilots.detect { |p| p.id == luke.id }.average_percentile).to be_within(1e-6).of(0.875)
    end
  end

  describe 'filters' do
    it 'by tournament type' do
      ranker = rank(tournament_type: casual_type.id)

      expect(names(ranker)).to eq(['Luke Skywalker'])
      expect(ranker.number_of_tournaments).to eq(1)
    end

    it 'by format' do
      expect(names(rank(format_id: extended.id))).to contain_exactly('Wedge Antilles', 'Luke Skywalker', 'Howlrunner')
      expect(names(rank(format_id: hyperspace.id))).to eq(['Luke Skywalker'])
    end

    it 'by ship' do
      expect(names(rank(ship_id: tie_fighter.id))).to eq(['Howlrunner'])
    end

    it 'by pilot' do
      expect(names(rank(pilot_id: wedge.id))).to eq(['Wedge Antilles'])
    end

    it 'by upgrade, counting only the squadrons where that pilot carried it' do
      ranker = rank(upgrade_id: crack_shot.id)

      expect(ranker.pilots.map { |p| [p.name, p.squadrons] }).to eq([['Luke Skywalker', 1], ['Howlrunner', 1]])
      expect(ranker.pilots.first.weight).to be_within(1e-6).of(0.75)
    end

    it 'by ship combo' do
      expect(names(rank(ship_combo_id: double_xwing_combo.id))).to contain_exactly('Luke Skywalker', 'Wedge Antilles')
    end
  end

  it 'is empty when nothing matches' do
    ranker = rank(ranking_start: today + 1, ranking_end: today + 2)

    expect(ranker.pilots).to eq([])
    expect(ranker.number_of_squadrons).to eq(0)
  end
end
