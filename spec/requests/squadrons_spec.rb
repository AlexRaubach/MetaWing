require 'rails_helper'

RSpec.describe 'Squadrons', type: :request do
  include_context 'meta scenario'

  def squadron_ids(path)
    get path
    response.parsed_body.map { |squadron| squadron['id'] }
  end

  describe 'GET /squadrons/:id' do
    it 'returns the squadron as standard XWS, without the proprietary points entries' do
      get squadron_path(luke_and_wedge)

      expect(response.media_type).to eq('application/json')
      expect(response.parsed_body).to eq(
        'faction' => 'rebelalliance',
        'name'    => 'Red Squadron',
        'pilots'  => [
          { 'name' => 'lukeskywalker', 'ship' => 't65xwing', 'upgrades' => { 'torpedo' => ['protontorpedoes'] } },
          { 'name' => 'wedgeantilles', 'ship' => 't65xwing' },
        ]
      )
    end

    it 'responds 404 for an unknown squadron' do
      get squadron_path(0)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /ships/:ship_id/squadrons' do
    it 'renders the squadrons fielding that ship' do
      get ship_squadrons_path(xwing)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Alice', 'Carol')
      expect(response.body).not_to include('Bob')
    end

    it 'lists them as JSON, best finish first' do
      expect(squadron_ids(ship_squadrons_path(xwing, format: :json))).to eq([luke_and_wedge.id, solo_luke.id])
    end

    it 'includes a link and the xws of each squadron' do
      get ship_squadrons_path(xwing, format: :json)

      expect(response.parsed_body.first).to eq(
        'id'   => luke_and_wedge.id,
        'link' => squadron_url(luke_and_wedge, format: :json),
        'xws'  => luke_and_wedge.xws
      )
    end

    it 'applies the ranking filter' do
      expect(squadron_ids(ship_squadrons_path(xwing, format: :json, tournament_type: casual_type.id))).to eq([solo_luke.id])
    end
  end

  describe 'GET /pilots/:pilot_id/squadrons' do
    it 'lists the squadrons fielding that pilot' do
      expect(squadron_ids(pilot_squadrons_path(howlrunner, format: :json))).to eq([howl_swarm.id])
    end

    it 'renders as HTML' do
      get pilot_squadrons_path(howlrunner)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Bob')
    end
  end

  describe 'GET /upgrades/:upgrade_id/squadrons' do
    it 'lists the squadrons carrying that upgrade' do
      expect(squadron_ids(upgrade_squadrons_path(crack_shot, format: :json))).to eq([solo_luke.id, howl_swarm.id])
    end

    it 'renders as HTML' do
      get upgrade_squadrons_path(crack_shot)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /ship_combos/:ship_combo_id/squadrons' do
    it 'lists the squadrons of that archetype' do
      expect(squadron_ids(ship_combo_squadrons_path(double_xwing_combo, format: :json))).to eq([luke_and_wedge.id])
    end

    it 'renders as HTML' do
      get ship_combo_squadrons_path(double_xwing_combo)

      expect(response).to have_http_status(:ok)
    end
  end

  it 'returns at most 50 squadrons' do
    51.times { |i| create_squadron(tournament: store_championship, faction: empire, ships: [howlrunner], swiss_standing: i + 5) }

    expect(squadron_ids(pilot_squadrons_path(howlrunner, format: :json)).size).to eq(50)
  end
end
