require 'rails_helper'

RSpec.describe 'Upgrades', type: :request do
  include_context 'meta scenario'

  let(:plain_swiss) { { use_ranking_data: 'swiss', widespread_use_multiplier: 'false', large_tournament_multiplier: 'false' } }

  describe 'GET /upgrades' do
    it 'renders the ranking table' do
      get upgrades_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Proton Torpedoes', 'Crack Shot')
    end

    it 'lists the upgrades as JSON' do
      get upgrades_path(format: :json), params: plain_swiss

      expect(response.parsed_body).to match([
        a_hash_including('position' => 1, 'id' => proton_torpedoes.id, 'xws' => 'protontorpedoes', 'name' => 'Proton Torpedoes',
                         'link' => upgrade_url(proton_torpedoes, format: :json),
                         'squadron_count' => 1, 'tournaments_count' => 1, 'average_percentile' => 100.0),
        a_hash_including('position' => 2, 'name' => 'Crack Shot', 'squadron_count' => 2, 'average_percentile' => 62.5),
      ])
    end

    it 'exports CSV' do
      get upgrades_path(format: :csv), params: plain_swiss

      rows = CSV.parse(response.body)
      expect(rows.first.grep(/translation missing/i)).to be_empty
      expect(rows.drop(1).map { |row| row.first(2) }).to eq([['1', 'Proton Torpedoes'], ['2', 'Crack Shot']])
    end
  end

  describe 'GET /upgrades/:id' do
    it 'renders the upgrade page with the pilots and archetypes that use it' do
      get upgrade_path(crack_shot)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Crack Shot', 'Luke Skywalker', 'Howlrunner', 'Howl Swarm')
      expect(response.body).not_to include('Wedge Antilles')
    end

    it 'shows the current card image rather than a legacy ffg one' do
      UpgradeSide.create!(upgrade: crack_shot, title: 'Crack Shot', upgrade_type: 'Talent', ffg: 311, image: 'https://dead.test/legacy.png')

      get upgrade_path(crack_shot)

      expect(response.body).to include('https://example.test/crack.png')
      expect(response.body).not_to include('https://dead.test/legacy.png')
    end

    it 'renders for an upgrade nobody played in the period' do
      get upgrade_path(create_upgrade('Predator'))

      expect(response).to have_http_status(:ok)
    end

    it 'returns just that upgrade as JSON' do
      get upgrade_path(crack_shot, format: :json)

      expect(response.parsed_body).to include('id' => crack_shot.id, 'name' => 'Crack Shot', 'position' => 1, 'squadron_count' => 2)
    end

    it 'returns just that upgrade as CSV' do
      get upgrade_path(crack_shot, format: :csv)

      expect(CSV.parse(response.body).drop(1).map { |row| row[1] }).to eq(['Crack Shot'])
    end

    it 'responds 404 for an unknown upgrade' do
      get upgrade_path(0)

      expect(response).to have_http_status(:not_found)
    end
  end
end
