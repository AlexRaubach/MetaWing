require 'rails_helper'

RSpec.describe Rankers::ShipsRanker do
  include_context 'meta scenario'

  # Takes ranking configuration overrides and ranker filters in one go
  def rank(**options)
    configuration, filters = ranker_arguments(options)
    described_class.new(configuration, **filters)
  end

  it 'ranks ships by the average percentile of every copy fielded' do
    ranker = rank

    # two X-wings in the winning list and one in the 0.75 list
    expect(ranker.ships.map(&:name)).to eq(['T-65 X-wing', 'TIE/ln Fighter'])
    expect(ranker.ships.first.weight).to be_within(1e-6).of((1.0 + 1.0 + 0.75) / 3)
    expect(ranker.ships.last.weight).to be_within(1e-6).of(0.5)
  end

  it 'counts each squadron and tournament once, however many copies it fielded' do
    xwing_row = rank.ships.first

    expect(xwing_row).to include(id: xwing.id, xws: 't65xwing', squadrons: 2, tournaments: 2)
  end

  it 'reports the totals for the filtered period' do
    ranker = rank

    expect([ranker.number_of_tournaments, ranker.number_of_squadrons]).to eq([2, 3])
  end

  describe 'grouping by faction' do
    let!(:scum)       { create_faction('Scum and Villainy') }
    let!(:scum_pilot) { create_pilot('Cartel Marauder', ship: xwing, faction: scum) }
    let!(:scum_list) do
      create_squadron(tournament: casual_night, faction: scum, ships: [scum_pilot], swiss_standing: 4, swiss_percentile: 0.25)
    end

    it 'merges factions flying the same ship by default' do
      xwing_row = rank.ships.detect { |ship| ship.id == xwing.id }

      expect(xwing_row.squadrons).to eq(3)
      expect(xwing_row).not_to have_key(:faction_name)
    end

    it 'splits a ship into one row per faction' do
      rows = rank(group_by_faction: true).ships.select { |ship| ship.id == xwing.id }

      expect(rows.map { |row| [row.faction_name, row.squadrons] })
        .to eq([['Rebel Alliance', 2], ['Scum and Villainy', 1]])
      expect(rows.map(&:faction_id)).to eq([rebels.id, scum.id])
    end

    it 'filters by faction' do
      ranker = rank(group_by_faction: true, faction_id: scum.id)

      expect(ranker.ships.map { |row| [row.name, row.faction_name] }).to eq([['T-65 X-wing', 'Scum and Villainy']])
    end
  end

  describe 'filters' do
    it 'by ship' do
      expect(rank(ship_id: tie_fighter.id).ships.map(&:name)).to eq(['TIE/ln Fighter'])
    end

    it 'by ship combo' do
      expect(rank(ship_combo_id: single_xwing_combo.id).ships.map { |s| [s.name, s.squadrons] }).to eq([['T-65 X-wing', 1]])
    end

    it 'by tournament type and format' do
      expect(rank(tournament_type: casual_type.id).ships.map(&:name)).to eq(['T-65 X-wing'])
      expect(rank(format_id: extended.id).ships.map(&:name)).to eq(['T-65 X-wing', 'TIE/ln Fighter'])
    end

    it 'by date' do
      expect(rank(ranking_start: today - 6).ships.map(&:name)).to eq(['T-65 X-wing'])
    end
  end

  describe '#ship_pilots' do
    it 'lists every pilot of each ship, whether or not it was played' do
      unplayed = create_pilot('Biggs Darklighter', ship: xwing, faction: rebels)

      pilots = rank.ship_pilots

      expect(pilots[xwing.id]).to contain_exactly(luke, wedge, unplayed)
      expect(pilots[tie_fighter.id]).to eq([howlrunner])
    end
  end
end
