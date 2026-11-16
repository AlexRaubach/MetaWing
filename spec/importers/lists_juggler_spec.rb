require 'rails_helper'

# All List Fortress traffic goes through Net::HTTP.get_response, which is
# stubbed here: these specs never touch the network.
RSpec.describe Importers::ListsJuggler, :silence_output do
  subject(:importer) { described_class.new }

  let(:api) { 'https://listfortress.test/api/v1' }

  let!(:rebels) { create_faction('Rebel Alliance', xws: 'rebelalliance') }
  let!(:empire) { create_faction('Galactic Empire', xws: 'galacticempire') }
  let!(:xwing)  { create_ship('T-65 X-wing', xws: 't65xwing') }
  let!(:tie)    { create_ship('TIE/ln Fighter', xws: 'tielnfighter') }
  let!(:luke)   { create_pilot('Luke Skywalker', xws: 'lukeskywalker', ship: xwing, faction: rebels) }
  let!(:howl)   { create_pilot('Howlrunner', xws: 'howlrunner', ship: tie, faction: empire) }

  let(:rebel_list)  { { 'faction' => 'rebelalliance', 'pilots' => [{ 'name' => 'lukeskywalker', 'ship' => 't65xwing' }] }.to_json }
  let(:empire_list) { { 'faction' => 'galacticempire', 'pilots' => [{ 'name' => 'howlrunner', 'ship' => 'tielnfighter' }] }.to_json }

  around do |example|
    original = Rails.configuration.x.listfortress.uri
    Rails.configuration.x.listfortress.uri = api
    example.run
  ensure
    Rails.configuration.x.listfortress.uri = original
  end

  # Serves `responses` (url => body) and records every url requested
  def stub_list_fortress(responses)
    requested = []
    allow(Net::HTTP).to receive(:get_response) do |uri|
      requested << uri.to_s
      body = responses.fetch(uri.to_s) { raise "unexpected request to #{uri}" }
      instance_double(Net::HTTPOK, body: body.is_a?(String) ? body.dup : body.to_json)
    end
    requested
  end

  def participant(id, name, list_json, **attributes)
    { 'id' => id, 'name' => name, 'list_json' => list_json, 'score' => 0, 'mov' => 0,
      'swiss_rank' => nil, 'top_cut_rank' => nil }.merge(attributes.stringify_keys)
  end

  def match(player1_id, player1_points, player2_id, player2_points, result: 'win')
    { 'player1_id' => player1_id, 'player1_points' => player1_points,
      'player2_id' => player2_id, 'player2_points' => player2_points, 'result' => result }
  end

  describe '#sync_tournament' do
    let(:tournament_data) do
      {
        'id' => 42, 'name' => 'Corellia Open', 'location' => 'Coronet', 'country' => 'Corellia',
        'date' => '2019-03-02', 'format_id' => 1, 'tournament_type_id' => 3,
        'participants' => [
          participant(1, 'Alice', rebel_list, score: 20, mov: 800, swiss_rank: 1, top_cut_rank: 1),
          participant(2, 'Bob', empire_list, score: 10, mov: 500, swiss_rank: 2),
          participant(3, 'Carol (no list)', nil, swiss_rank: 3),
        ],
        'rounds' => [
          { 'round_number' => 1, 'roundtype_id' => 'swiss', 'matches' => [match(1, 200, 2, 50)] },
          { 'round_number' => 2, 'roundtype_id' => 'elimination', 'matches' => [match(1, 100, 2, 0)] },
        ],
      }
    end

    before { stub_list_fortress("#{api}/tournaments/42" => tournament_data) }

    # Like sync_tournaments, start from a freshly loaded (or brand new) record
    def sync_tournament_42
      importer.sync_tournament(Tournament.find_by(lists_juggler_id: 42) || Tournament.new(lists_juggler_id: 42))
      Tournament.find_by(lists_juggler_id: 42)
    end

    it 'stores the tournament details' do
      tournament = sync_tournament_42

      expect(tournament).to have_attributes(
        name: 'Corellia Open', date: Date.new(2019, 3, 2), num_players: 3, format_id: 1, tournament_type_id: 3
      )
      expect(tournament.venue).to have_attributes(name: 'Corellia Open', city: 'Coronet', country: 'Corellia')
    end

    it 'imports the squadron of every participant who submitted a list' do
      tournament = sync_tournament_42

      expect(tournament.squadrons.pluck(:player_name)).to contain_exactly('Alice', 'Bob')
      expect(tournament.squadrons.find_by(player_name: 'Alice')).to have_attributes(
        faction_id: rebels.id, points: 20, mov: 800, swiss_standing: 1, elimination_standing: 1, pilots: [luke]
      )
    end

    it 'imports the games with their round details' do
      tournament = sync_tournament_42
      alice      = tournament.squadrons.find_by(player_name: 'Alice')
      bob        = tournament.squadrons.find_by(player_name: 'Bob')

      expect(tournament.games.order(:round_number).map { |g| [g.round_number, g.round_type, g.winning_squadron, g.losing_squadron] })
        .to eq([[1, 'swiss', alice, bob], [2, 'elimination', alice, bob]])
    end

    it 'replaces squadrons and games when a tournament is synced again' do
      sync_tournament_42

      expect { sync_tournament_42 }
        .to not_change(Tournament, :count)
        .and not_change(Squadron, :count)
        .and not_change(Game, :count)
        .and not_change(Venue, :count)
    end

    it 'has no venue when the location is incomplete' do
      stub_list_fortress("#{api}/tournaments/42" => tournament_data.merge('country' => nil))

      expect(sync_tournament_42.venue).to be_nil
    end

    it 'skips a squadron whose list cannot be resolved without losing the rest' do
      broken = { 'faction' => 'rebelalliance', 'pilots' => [{ 'name' => 'nobody', 'ship' => 't65xwing' }] }.to_json
      tournament_data['participants'][1] = participant(2, 'Bob', broken)

      tournament = sync_tournament_42

      expect(tournament.squadrons.pluck(:player_name)).to eq(['Alice'])
      expect(tournament.games).to be_empty
    end

    it 'leaves the tournament unsaved when List Fortress returns nothing for it' do
      stub_list_fortress("#{api}/tournaments/42" => 'null')

      expect(sync_tournament_42).to be_nil
    end
  end

  describe '#sync_games' do
    let(:tournament) { create_tournament }
    let(:alice)      { create_squadron(tournament: tournament, faction: rebels, ships: [luke]) }
    let(:bob)        { create_squadron(tournament: tournament, faction: empire, ships: [howl]) }
    let(:squadrons)  { { 1 => alice, 2 => bob } }

    def sync(*matches)
      importer.sync_games(tournament, [{ 'round_number' => 1, 'roundtype_id' => 'swiss', 'matches' => matches }], squadrons)
    end

    it 'records a win for player 1' do
      sync(match(1, 200, 2, 50))

      expect(Game.all.map { |g| [g.winning_squadron, g.losing_squadron] }).to eq([[alice, bob]])
    end

    it 'records a win for player 2' do
      sync(match(1, 50, 2, 200))

      expect(Game.all.map { |g| [g.winning_squadron, g.losing_squadron] }).to eq([[bob, alice]])
    end

    it 'ignores matches that did not end in a win' do
      sync(match(1, 200, 2, 50, result: 'tie'), match(1, 200, 2, 50, result: 'bye'))

      expect(Game.count).to eq(0)
    end

    it 'ignores matches with equal points' do
      sync(match(1, 100, 2, 100))

      expect(Game.count).to eq(0)
    end

    it 'ignores matches against players whose squadron was not imported' do
      sync(match(1, 200, 99, 50))

      expect(Game.count).to eq(0)
    end
  end

  describe '#sync_squadron' do
    let(:tournament) { create_tournament }

    it 'returns nil for a participant without a list' do
      expect(importer.sync_squadron(tournament, participant(1, 'Alice', nil))).to be_nil
      expect(importer.sync_squadron(tournament, participant(1, 'Alice', ''))).to be_nil
    end

    it 'returns nil instead of raising when the list is invalid' do
      expect(importer.sync_squadron(tournament, participant(1, 'Alice', '{"faction":"nonsense"}'))).to be_nil
      expect(Squadron.count).to eq(0)
    end
  end

  describe '#sync_tournaments' do
    let(:listing) do
      [
        { 'id' => 7, 'updated_at' => '2019-03-05T10:00:00.000Z' },
        { 'id' => 5, 'updated_at' => '2019-03-01T10:00:00.000Z' },
        { 'id' => 9, 'updated_at' => '2019-03-03T10:00:00.000Z' },
      ]
    end
    let(:synced_ids) { [] }

    before do
      allow(importer).to receive(:sync_tournament) { |tournament| synced_ids << tournament.lists_juggler_id }
    end

    it 'syncs every listed tournament in id order' do
      stub_list_fortress("#{api}/tournaments" => listing)

      importer.sync_tournaments

      expect(synced_ids).to eq([5, 7, 9])
    end

    it 'remembers the most recent update it has seen' do
      stub_list_fortress("#{api}/tournaments" => listing)

      importer.sync_tournaments

      expect(Time.iso8601(KeyValueStoreRecord.get('latest_tourney_update'))).to eq(Time.utc(2019, 3, 5, 10))
    end

    it 'skips tournaments below the minimum id' do
      stub_list_fortress("#{api}/tournaments" => listing)

      importer.sync_tournaments(minimum_id: 7)

      expect(synced_ids).to eq([7, 9])
    end

    it 'skips already-imported tournaments from before the start date' do
      stub_list_fortress("#{api}/tournaments" => listing)
      create_tournament(lists_juggler_id: 5, date: Date.new(2018, 12, 1))
      create_tournament(lists_juggler_id: 7, date: Date.new(2019, 3, 1))

      importer.sync_tournaments(start_date: '2019-01-01')

      expect(synced_ids).to eq([7, 9])
    end

    it 'syncs an existing tournament in place rather than creating a new one' do
      existing = create_tournament(lists_juggler_id: 5)
      synced   = []
      allow(importer).to receive(:sync_tournament) { |tournament| synced << tournament }
      stub_list_fortress("#{api}/tournaments" => [listing[1]])

      importer.sync_tournaments

      expect(synced).to eq([existing])
    end

    it 'asks only for tournaments updated since the last sync when told to' do
      KeyValueStoreRecord.set!('latest_tourney_update', '2019-03-04T00:00:00Z')
      requested = stub_list_fortress("#{api}/tournaments?updatedafter=2019-03-04T00:00:00Z" => [listing[0]])

      importer.sync_tournaments(use_updated: true)

      expect(requested).to eq(["#{api}/tournaments?updatedafter=2019-03-04T00:00:00Z"])
      expect(synced_ids).to eq([7])
    end

    it 'asks for the full listing by default even after an earlier sync' do
      KeyValueStoreRecord.set!('latest_tourney_update', '2019-03-04T00:00:00Z')
      requested = stub_list_fortress("#{api}/tournaments" => listing)

      importer.sync_tournaments

      expect(requested).to eq(["#{api}/tournaments"])
    end

    it 'never moves the remembered update time backwards' do
      KeyValueStoreRecord.set!('latest_tourney_update', '2020-01-01T00:00:00Z')
      stub_list_fortress("#{api}/tournaments" => listing)

      importer.sync_tournaments

      expect(Time.iso8601(KeyValueStoreRecord.get('latest_tourney_update'))).to eq(Time.utc(2020, 1, 1))
    end

    it 'does nothing when the listing is empty' do
      stub_list_fortress("#{api}/tournaments" => [])

      importer.sync_tournaments

      expect(synced_ids).to be_empty
      expect(KeyValueStoreRecord.get('latest_tourney_update')).to be_nil
    end
  end

  describe '#clean_tournaments' do
    it 'removes local tournaments that List Fortress no longer lists' do
      kept    = create_tournament(lists_juggler_id: 5)
      deleted = create_tournament(lists_juggler_id: 6)
      create_squadron(tournament: deleted, faction: rebels, ships: [luke])
      stub_list_fortress("#{api}/tournaments" => [{ 'id' => 5 }])

      importer.clean_tournaments

      expect(Tournament.all).to eq([kept])
      expect(Squadron.count).to eq(0)
    end

    it 'removes nothing when the listing comes back empty' do
      create_tournament(lists_juggler_id: 5)
      stub_list_fortress("#{api}/tournaments" => [])

      expect { importer.clean_tournaments }.not_to change(Tournament, :count)
    end
  end

  describe '#remove_tournament' do
    it 'deletes the tournament with its squadrons, ship configurations and games' do
      tournament = create_tournament(lists_juggler_id: 5)
      alice      = create_squadron(tournament: tournament, faction: rebels, ships: [luke])
      bob        = create_squadron(tournament: tournament, faction: empire, ships: [howl])
      create_game(winner: alice, loser: bob)

      importer.remove_tournament(5)

      expect([Tournament.count, Squadron.count, ShipConfiguration.count, Game.count]).to eq([0, 0, 0, 0])
    end

    it 'leaves other tournaments alone' do
      other = create_tournament(lists_juggler_id: 6)
      create_tournament(lists_juggler_id: 5)

      importer.remove_tournament(5)

      expect(Tournament.all).to eq([other])
    end

    it 'does not raise for an unknown tournament' do
      expect { importer.remove_tournament(12345) }.not_to raise_error
    end
  end
end
