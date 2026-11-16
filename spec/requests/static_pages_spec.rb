require 'rails_helper'

RSpec.describe 'Static pages', type: :request do
  it 'serves the overview at the root' do
    get root_path

    expect(response).to have_http_status(:ok)
  end

  it 'renders ABOUT.md on the about page' do
    get about_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<h3>Many thanks to...</h3>')
  end

  it 'renders CHANGELOG.md on the news page' do
    get news_index_path

    expect(response).to have_http_status(:ok)
    first_heading = File.read(Rails.root.join('CHANGELOG.md'))[/^#+\s*(.+)$/, 1]
    expect(response.body).to include(ERB::Util.html_escape(first_heading.strip))
  end

  it 'serves the turning test tool' do
    get turning_test_path

    expect(response).to have_http_status(:ok)
  end

  describe 'maintenance page' do
    it 'redirects home when maintenance mode is off' do
      get maintenance_mode_path

      expect(response).to redirect_to(root_path)
    end

    it 'redirects home when maintenance mode was switched off again' do
      KeyValueStoreRecord.set!('maintenance', false)

      get maintenance_mode_path

      expect(response).to redirect_to(root_path)
    end

    it 'is shown while maintenance mode is on' do
      KeyValueStoreRecord.set!('maintenance', true)

      get maintenance_mode_path

      expect(response).to have_http_status(:ok)
    end
  end

  it 'renders ranking pages on an empty database' do
    [pilots_path, ships_path, upgrades_path, ship_combos_path].each do |path|
      get path

      expect(response).to have_http_status(:ok), "GET #{path} returned #{response.status}"
    end
  end
end
