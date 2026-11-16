require 'rails_helper'

RSpec.describe Rankers::CounterComboRanker do
  include_context 'meta scenario'

  def counters(ship_combo, config = {})
    described_class.new(ranking_config(**config), ship_combo.id).counter_combos
  end

  it 'reports the record against each opposing combo' do
    expect(counters(double_xwing_combo)).to match([
      { ship_combo: tie_combo, games_against: 3, wins_against: 2, losses_against: 1, win_loss_ratio: be_within(1e-9).of(2.0 / 3) },
    ])
  end

  it 'reports the mirror image for the opponent' do
    expect(counters(tie_combo)).to match([
      { ship_combo: double_xwing_combo, games_against: 3, wins_against: 1, losses_against: 2, win_loss_ratio: be_within(1e-9).of(1.0 / 3) },
    ])
  end

  it 'accepts the combo id as a string, as the controller passes it' do
    result = described_class.new(ranking_config, tie_combo.id.to_s).counter_combos

    expect(result.map { |counter| counter[:ship_combo] }).to eq([double_xwing_combo])
  end

  context 'with more matchups' do
    let!(:casual_ties) do
      create_squadron(tournament: casual_night, faction: empire, ship_combo: tie_combo, ships: [howlrunner], swiss_standing: 3)
    end

    it 'leaves out matchups with only a single game' do
      create_game(winner: solo_luke, loser: casual_ties)

      expect(counters(tie_combo).map { |counter| counter[:ship_combo] }).to eq([double_xwing_combo])
    end

    it 'puts the worst matchups first' do
      2.times { create_game(winner: casual_ties, loser: solo_luke) }

      expect(counters(tie_combo).map { |counter| [counter[:ship_combo], counter[:wins_against], counter[:losses_against]] })
        .to eq([[double_xwing_combo, 1, 2], [single_xwing_combo, 2, 0]])
    end

    it 'leaves out mirror matches' do
      mirror = create_squadron(tournament: casual_night, faction: empire, ship_combo: tie_combo, ships: [howlrunner], swiss_standing: 4)
      2.times { create_game(winner: casual_ties, loser: mirror) }

      expect(counters(tie_combo).map { |counter| counter[:ship_combo] }).not_to include(tie_combo)
    end

    it 'only counts games from tournaments matching the filter' do
      2.times { create_game(winner: casual_ties, loser: solo_luke) }

      expect(counters(tie_combo, tournament_type: store_type.id).map { |c| c[:ship_combo] }).to eq([double_xwing_combo])
      expect(counters(tie_combo, format_id: hyperspace.id).map { |c| c[:ship_combo] }).to eq([single_xwing_combo])
      expect(counters(tie_combo, ranking_start: today - 6).map { |c| c[:ship_combo] }).to eq([single_xwing_combo])
    end
  end

  it 'is empty for a combo without games' do
    expect(counters(single_xwing_combo)).to eq([])
  end
end
