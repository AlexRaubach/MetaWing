require 'rails_helper'

RSpec.describe 'Ships', type: :request do
  include_context 'meta scenario'

  let(:plain_swiss) { { use_ranking_data: 'swiss', widespread_use_multiplier: 'false', large_tournament_multiplier: 'false' } }

  describe 'GET /ships' do
    it 'renders the ranking table with each ship and its pilots' do
      get ships_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('T-65 X-wing', 'TIE/ln Fighter', 'Luke Skywalker', 'Howlrunner')
    end

    it 'lists the ships per faction as JSON' do
      get ships_path(format: :json), params: plain_swiss

      expect(response.parsed_body.map { |ship| ship.slice('position', 'name', 'faction', 'squadron_count', 'tournaments_count') }).to eq([
        { 'position' => 1, 'name' => 'T-65 X-wing', 'faction' => 'Rebel Alliance', 'squadron_count' => 2, 'tournaments_count' => 2 },
        { 'position' => 2, 'name' => 'TIE/ln Fighter', 'faction' => 'Galactic Empire', 'squadron_count' => 1, 'tournaments_count' => 1 },
      ])
    end

    it 'includes links and pilots in the JSON' do
      get ships_path(format: :json), params: plain_swiss

      xwing_json = response.parsed_body.first
      expect(xwing_json).to include('id' => xwing.id, 'xws' => 't65xwing', 'link' => ship_url(xwing, format: :json), 'average_percentile' => 91.66)
      expect(xwing_json['pilots']).to contain_exactly(
        { 'id' => luke.id, 'name' => 'Luke Skywalker', 'link' => pilot_url(luke, format: :json) },
        { 'id' => wedge.id, 'name' => 'Wedge Antilles', 'link' => pilot_url(wedge, format: :json) }
      )
    end

    it 'exports CSV' do
      get ships_path(format: :csv), params: plain_swiss

      rows = CSV.parse(response.body)
      expect(rows.first.grep(/translation missing/i)).to be_empty
      expect(rows.drop(1).map { |row| [row[0], row[1], row[2], row[4], row[8]] }).to eq([
        ['1', 'T-65 X-wing', ship_url(xwing), '2', 'Rebel Alliance'],
        ['2', 'TIE/ln Fighter', ship_url(tie_fighter), '1', 'Galactic Empire'],
      ])
    end
  end

  describe 'GET /ships/:id' do
    it 'renders the ship page with its pilots, upgrades, archetypes and notable squadrons' do
      get ship_path(xwing)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('T-65 X-wing', 'Wedge Antilles', 'Proton Torpedoes', 'Double X', 'Alice')
      expect(response.body).not_to include('Howlrunner')
    end

    it 'renders for a ship nobody played in the period' do
      get ship_path(create_ship('BTL-A4 Y-wing'))

      expect(response).to have_http_status(:ok)
    end

    it 'returns just that ship as JSON' do
      get ship_path(tie_fighter, format: :json)

      expect(response.parsed_body).to include('id' => tie_fighter.id, 'name' => 'TIE/ln Fighter', 'position' => 1)
    end

    it 'returns just that ship as CSV' do
      get ship_path(tie_fighter, format: :csv)

      expect(CSV.parse(response.body).drop(1).map { |row| row[1] }).to eq(['TIE/ln Fighter'])
    end

    it 'responds 404 for an unknown ship' do
      get ship_path(0)

      expect(response).to have_http_status(:not_found)
    end
  end
end
