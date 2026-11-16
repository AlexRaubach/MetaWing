require 'rails_helper'

RSpec.describe 'Pilots', type: :request do
  include_context 'meta scenario'

  describe 'GET /pilots' do
    it 'renders the ranking table' do
      get pilots_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Wedge Antilles', 'Luke Skywalker', 'Howlrunner')
    end

    it 'renders when there is no data in the period' do
      get pilots_path, params: { ranking_start: (today + 1).to_s, ranking_end: (today + 2).to_s }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Luke Skywalker')
    end

    describe 'as JSON' do
      # The default filter uses all ranking data with both multipliers on
      it 'lists the pilots in ranking order' do
        get pilots_path(format: :json)

        expect(response.media_type).to eq('application/json')
        expect(response.parsed_body.map { |pilot| [pilot['position'], pilot['name']] })
          .to eq([[1, 'Wedge Antilles'], [2, 'Luke Skywalker'], [3, 'Howlrunner']])
      end

      it 'describes each pilot' do
        get pilots_path(format: :json), params: { use_ranking_data: 'swiss' }

        luke_json = response.parsed_body.detect { |pilot| pilot['id'] == luke.id }
        expect(luke_json).to include(
          'xws'                => 'lukeskywalker',
          'name'               => 'Luke Skywalker',
          'faction'            => 'Rebel Alliance',
          'squadron_count'     => 2,
          'tournaments_count'  => 2,
          'average_percentile' => 87.5,
          'link'               => pilot_url(luke, format: :json),
          'ship'               => { 'id' => xwing.id, 'name' => 'T-65 X-wing', 'link' => ship_url(xwing, format: :json) }
        )
      end
    end

    describe 'as CSV' do
      it 'has a header row and one row per pilot' do
        get pilots_path(format: :csv), params: { use_ranking_data: 'swiss', widespread_use_multiplier: 'false', large_tournament_multiplier: 'false' }

        rows = CSV.parse(response.body)
        expect(rows.size).to eq(4)
        expect(rows.first.grep(/translation missing/i)).to be_empty
        expect(rows[1]).to eq(['1', 'Wedge Antilles', pilot_url(wedge), 'T-65 X-wing', '1', '1', '100.0', '1.0', 'Rebel Alliance'])
      end
    end

    describe 'filter parameters' do
      def ranked_names(**params)
        get pilots_path(format: :json), params: params
        response.parsed_body.map { |pilot| pilot['name'] }
      end

      it 'defaults to the last month' do
        expect(ranked_names).not_to be_empty
        expect(ranked_names(ranking_start: (today - 500).to_s)).to include('Howlrunner')

        get pilots_path(format: :json), params: { ranking_start: (today - 500).to_s }
        howl = response.parsed_body.detect { |pilot| pilot['name'] == 'Howlrunner' }
        expect(howl['squadron_count']).to eq(2)
      end

      it 'honours the date range' do
        expect(ranked_names(ranking_start: (today - 6).to_s)).to eq(['Luke Skywalker'])
        expect(ranked_names(ranking_end: (today - 6).to_s)).to contain_exactly('Luke Skywalker', 'Wedge Antilles', 'Howlrunner')
      end

      it 'honours the tournament type and format' do
        expect(ranked_names(tournament_type: casual_type.id)).to eq(['Luke Skywalker'])
        expect(ranked_names(format_id: hyperspace.id)).to eq(['Luke Skywalker'])
      end

      it 'honours the ranking data and multiplier switches' do
        names = ranked_names(use_ranking_data: 'swiss', widespread_use_multiplier: 'false', large_tournament_multiplier: 'false')

        expect(names).to eq(['Wedge Antilles', 'Luke Skywalker', 'Howlrunner'])
      end

      it 'keeps a non-default filter on the links in the page' do
        get pilots_path, params: { use_ranking_data: 'swiss' }

        expect(response.body).to include("#{pilot_path(luke)}?use_ranking_data=swiss&amp;")
      end
    end
  end

  describe 'GET /pilots/:id' do
    it 'renders the pilot page with its upgrades, archetypes and notable squadrons' do
      get pilot_path(luke)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Luke Skywalker', 'Proton Torpedoes', 'Crack Shot', 'Double X', 'Alice')
    end

    it 'renders for a pilot nobody played in the period' do
      unplayed = create_pilot('Biggs Darklighter', ship: xwing, faction: rebels)

      get pilot_path(unplayed)

      expect(response).to have_http_status(:ok)
    end

    it 'returns just that pilot as JSON' do
      get pilot_path(howlrunner, format: :json)

      expect(response.parsed_body).to include('id' => howlrunner.id, 'name' => 'Howlrunner', 'position' => 1, 'squadron_count' => 1)
    end

    it 'returns just that pilot as CSV' do
      get pilot_path(howlrunner, format: :csv)

      expect(CSV.parse(response.body).drop(1).map { |row| row[1] }).to eq(['Howlrunner'])
    end

    it 'responds 404 for an unknown pilot' do
      get pilot_path(0)

      expect(response).to have_http_status(:not_found)
    end
  end
end
