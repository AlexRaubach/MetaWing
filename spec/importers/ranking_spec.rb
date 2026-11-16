require 'rails_helper'

RSpec.describe Importers::Ranking, :silence_output do
  let(:rebels)  { create_faction('Rebel Alliance') }
  let(:empire)  { create_faction('Galactic Empire') }
  let(:xwing)   { create_ship('T-65 X-wing') }
  let(:ywing)   { create_ship('BTL-A4 Y-wing') }
  let(:tie)     { create_ship('TIE/ln Fighter') }
  let(:luke)    { create_pilot('Luke Skywalker', ship: xwing, faction: rebels) }
  let(:wedge)   { create_pilot('Wedge Antilles', ship: xwing, faction: rebels) }
  let(:dutch)   { create_pilot('Dutch Vander', ship: ywing, faction: rebels) }
  let(:howl)    { create_pilot('Howlrunner', ship: tie, faction: empire) }

  let(:tournament) { create_tournament(num_players: 4) }

  def squadron(pilots, **attributes)
    create_squadron(tournament: tournament, faction: pilots.first.faction, ships: pilots, **attributes)
  end

  def build_ranking_data
    described_class.new.build_ranking_data(tournament.lists_juggler_id)
  end

  describe '#build_ranking_data' do
    describe 'swiss percentiles' do
      it 'spreads the standings evenly, with first place at 1.0' do
        squadrons = (1..4).map { |standing| squadron([luke], swiss_standing: standing) }

        build_ranking_data

        expect(squadrons.map { |s| s.reload.swiss_percentile }).to eq([1.0, 0.75, 0.5, 0.25])
      end

      it 'uses the reported player count when not every list was submitted' do
        tournament.update!(num_players: 10)
        winner = squadron([luke], swiss_standing: 1)
        fifth  = squadron([luke], swiss_standing: 5)

        build_ranking_data

        expect(winner.reload.swiss_percentile).to eq(1.0)
        expect(fifth.reload.swiss_percentile).to eq(0.6)
      end

      it 'uses the number of squadrons when it exceeds the reported player count' do
        tournament.update!(num_players: 2)
        squadrons = (1..4).map { |standing| squadron([luke], swiss_standing: standing) }

        build_ranking_data

        expect(squadrons.last.reload.swiss_percentile).to eq(0.25)
      end

      it 'leaves squadrons without a standing unranked' do
        unranked = squadron([luke], swiss_standing: nil)
        zero     = squadron([luke], swiss_standing: 0)

        build_ranking_data

        expect(unranked.reload.swiss_percentile).to be_nil
        expect(zero.reload.swiss_percentile).to be_nil
      end
    end

    describe 'elimination percentiles' do
      it 'ranks the squadrons that made the cut' do
        first  = squadron([luke], swiss_standing: 2, elimination_standing: 1)
        second = squadron([luke], swiss_standing: 1, elimination_standing: 2)
        missed = squadron([luke], swiss_standing: 3)
        squadron([luke], swiss_standing: 4)

        build_ranking_data

        expect(first.reload.elimination_percentile).to eq(1.0)
        expect(second.reload.elimination_percentile).to eq(0.5)
        expect(missed.reload.elimination_percentile).to be_nil
      end

      it 'rounds the cut size up to the next power of two' do
        tournament.update!(num_players: 8)
        cut = (1..3).map { |standing| squadron([luke], swiss_standing: standing, elimination_standing: standing) }
        squadron([luke], swiss_standing: 4)

        build_ranking_data

        expect(cut.map { |s| s.reload.elimination_percentile }).to eq([1.0, 0.75, 0.5])
      end

      it 'ignores the cut when every squadron has an elimination standing' do
        squadrons = (1..4).map { |standing| squadron([luke], swiss_standing: standing, elimination_standing: standing) }

        build_ranking_data

        expect(squadrons.map { |s| s.reload.elimination_percentile }).to all(be_nil)
      end

      it 'ignores the cut when no squadron has an elimination standing' do
        squadrons = (1..4).map { |standing| squadron([luke], swiss_standing: standing) }

        build_ranking_data

        expect(squadrons.map { |s| s.reload.elimination_percentile }).to all(be_nil)
      end
    end

    describe 'ship combos' do
      it 'assigns squadrons flying the same ships to the same combo' do
        luke_dutch  = squadron([luke, dutch], swiss_standing: 1)
        dutch_wedge = squadron([dutch, wedge], swiss_standing: 2)
        howl_solo   = squadron([howl], swiss_standing: 3)

        expect { build_ranking_data }.to change(ShipCombo, :count).by(2)

        expect(luke_dutch.reload.ship_combo).to eq(dutch_wedge.reload.ship_combo)
        expect(luke_dutch.ship_combo.ships).to contain_exactly(xwing, ywing)
        expect(howl_solo.reload.ship_combo.ships).to eq([tie])
      end

      it 'tells apart combos that differ only in how many of a ship they field' do
        single = squadron([luke], swiss_standing: 1)
        double = squadron([luke, wedge], swiss_standing: 2)

        build_ranking_data

        expect(single.reload.ship_combo).not_to eq(double.reload.ship_combo)
        expect(double.ship_combo.ships).to eq([xwing, xwing])
      end

      it 'reuses a combo that already exists' do
        existing = create_ship_combo(ywing, xwing, archetype_name: 'Rebel Beef')
        list     = squadron([luke, dutch], swiss_standing: 1)

        expect { build_ranking_data }.not_to change(ShipCombo, :count)
        expect(list.reload.ship_combo).to eq(existing)
      end
    end

    describe 'games' do
      let!(:winner) { squadron([luke], swiss_standing: 1, elimination_standing: 1) }
      let!(:loser)  { squadron([howl], swiss_standing: 2, elimination_standing: 2) }
      let!(:bye)    { squadron([dutch], swiss_standing: 3) }

      def game(winning, losing, round_type)
        Game.create!(tournament: tournament, winning_squadron: winning, losing_squadron: losing, round_type: round_type)
      end

      it 'stamps each game with the combos that played it' do
        played = game(winner, loser, 'swiss')

        build_ranking_data

        expect(played.reload.winning_combo.ships).to eq([xwing])
        expect(played.losing_combo.ships).to eq([tie])
      end

      it 'treats unrecognised round types as swiss' do
        played = game(winner, loser, '1')

        build_ranking_data

        expect(played.reload.round_type).to eq('swiss')
      end

      it 'computes win/loss ratios separately for swiss and elimination' do
        game(winner, loser, 'swiss')
        game(winner, loser, 'swiss')
        game(loser, winner, 'swiss')
        game(winner, loser, 'elimination')

        build_ranking_data

        expect(winner.reload).to have_attributes(win_loss_ratio_swiss: be_within(1e-9).of(2.0 / 3), win_loss_ratio_elimination: 1.0)
        expect(loser.reload).to have_attributes(win_loss_ratio_swiss: be_within(1e-9).of(1.0 / 3), win_loss_ratio_elimination: 0.0)
      end

      it 'clears the ratios of squadrons without games' do
        bye.update!(win_loss_ratio_swiss: 0.5, win_loss_ratio_elimination: 0.5)

        build_ranking_data

        expect(bye.reload).to have_attributes(win_loss_ratio_swiss: nil, win_loss_ratio_elimination: nil)
      end
    end

    it 'can be re-run without changing the result' do
      first  = squadron([luke], swiss_standing: 1)
      second = squadron([howl], swiss_standing: 2)
      Game.create!(tournament: tournament, winning_squadron: first, losing_squadron: second, round_type: 'swiss')

      build_ranking_data
      snapshot = Squadron.order(:id).map(&:attributes)

      expect { build_ranking_data }.not_to change(ShipCombo, :count)
      expect(Squadron.order(:id).map { |s| s.attributes.except('updated_at') })
        .to eq(snapshot.map { |attributes| attributes.except('updated_at') })
    end
  end

  describe '#rebuild_all_ranking_data' do
    let!(:old_tournament)     { create_tournament(lists_juggler_id: 10, date: Date.new(2019, 1, 5)) }
    let!(:new_tournament)     { create_tournament(lists_juggler_id: 20, date: Date.new(2019, 6, 5)) }
    let!(:undated_tournament) { create_tournament(lists_juggler_id: 30, date: nil) }

    let(:ranking) { described_class.new }

    def rebuilt_ids(**options)
      ids = []
      allow(ranking).to receive(:build_ranking_data) { |id| ids << id }
      ranking.rebuild_all_ranking_data(**options)
      ids
    end

    it 'rebuilds every tournament by default' do
      expect(rebuilt_ids).to contain_exactly(10, 20, 30)
    end

    it 'skips tournaments below the minimum id' do
      expect(rebuilt_ids(minimum_id: 20)).to contain_exactly(20, 30)
    end

    it 'skips tournaments before the start date but keeps undated ones' do
      expect(rebuilt_ids(start_date: '2019-06-05')).to contain_exactly(20, 30)
    end
  end
end
