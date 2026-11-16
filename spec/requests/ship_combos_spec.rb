require 'rails_helper'

RSpec.describe 'Ship combos', type: :request do
  include_context 'meta scenario'

  let(:plain_swiss) { { use_ranking_data: 'swiss', widespread_use_multiplier: 'false', large_tournament_multiplier: 'false' } }

  describe 'GET /ship_combos' do
    it 'renders the archetype table, with a placeholder for unnamed archetypes' do
      get ship_combos_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Double X', 'Howl Swarm', '(unnamed)')
    end

    it 'lists the archetypes as JSON' do
      get ship_combos_path(format: :json), params: plain_swiss

      xwing_json = { 'id' => xwing.id, 'name' => 'T-65 X-wing', 'xws' => 't65xwing', 'link' => ship_url(xwing, format: :json) }
      expect(response.parsed_body).to match([
        a_hash_including('position' => 1, 'id' => double_xwing_combo.id, 'name' => 'Double X', 'faction' => 'Rebel Alliance',
                         'link' => ship_combo_url(double_xwing_combo, format: :json), 'ships' => [xwing_json, xwing_json],
                         'squadron_count' => 1, 'tournaments_count' => 1, 'average_percentile' => 100.0),
        a_hash_including('position' => 2, 'id' => single_xwing_combo.id, 'name' => nil, 'ships' => [xwing_json]),
        a_hash_including('position' => 3, 'id' => tie_combo.id, 'name' => 'Howl Swarm', 'faction' => 'Galactic Empire'),
      ])
    end

    it 'exports CSV' do
      get ship_combos_path(format: :csv), params: plain_swiss

      rows = CSV.parse(response.body)
      expect(rows.size).to eq(4)
      expect(rows.first.grep(/translation missing/i)).to be_empty
      expect(rows[1]).to include('Double X')
    end
  end

  describe 'GET /ship_combos/:id' do
    it 'renders the archetype page with its pilots, upgrades and squadrons' do
      get ship_combo_path(double_xwing_combo)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Double X', 'Luke Skywalker', 'Wedge Antilles', 'Proton Torpedoes', 'Alice')
    end

    it 'shows the matchups against other archetypes' do
      get ship_combo_path(double_xwing_combo)

      expect(response.body).to include('Howl Swarm')
    end

    it 'lists alternate names' do
      double_xwing_combo.update!(alternate_names: ['Red Pair'])

      get ship_combo_path(double_xwing_combo)

      expect(response.body).to include('Red Pair')
    end

    it 'renders for an archetype nobody played in the period' do
      get ship_combo_path(create_ship_combo(tie_fighter, tie_fighter))

      expect(response).to have_http_status(:ok)
    end

    it 'returns just that archetype as JSON' do
      get ship_combo_path(tie_combo, format: :json)

      expect(response.parsed_body).to include('id' => tie_combo.id, 'name' => 'Howl Swarm', 'position' => 1)
    end

    it 'returns just that archetype as CSV' do
      get ship_combo_path(tie_combo, format: :csv)

      expect(response).to have_http_status(:ok)
      expect(CSV.parse(response.body).drop(1).map { |row| row[1] }).to eq(['Howl Swarm'])
    end

    it 'responds 404 for an unknown archetype' do
      get ship_combo_path(0)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /ship_combos/:id' do
    it 'queues an archetype name suggestion for moderation' do
      expect {
        patch ship_combo_path(single_xwing_combo), params: { name_suggestion: 'Lone Wolf', comment: 'obviously' }
      }.to change(ArchetypeNameSuggestion.pending, :count).by(1)

      expect(ArchetypeNameSuggestion.last).to have_attributes(
        ship_combo: single_xwing_combo, name_suggestion: 'Lone Wolf', comment: 'obviously', ip_address: '127.0.0.1'
      )
      expect(response).to redirect_to(ship_combo_path(single_xwing_combo))
    end

    it 'does not rename the archetype itself' do
      patch ship_combo_path(double_xwing_combo), params: { name_suggestion: 'Something Else' }

      expect(double_xwing_combo.reload.archetype_name).to eq('Double X')
    end

    it 'thanks the visitor' do
      patch ship_combo_path(single_xwing_combo), params: { name_suggestion: 'Lone Wolf' }
      follow_redirect!

      expect(response.body).to include('Thanks for your suggestion')
    end

    it 'ignores a blank suggestion' do
      expect {
        patch ship_combo_path(single_xwing_combo), params: { name_suggestion: ' ' }
      }.not_to change(ArchetypeNameSuggestion, :count)
    end
  end
end
