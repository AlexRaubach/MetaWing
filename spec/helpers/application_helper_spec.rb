require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  # raw_ranking_configuration is a controller helper method; stand in for it
  def with_filter(filter)
    helper.define_singleton_method(:raw_ranking_configuration) { filter }
  end

  # The views always call it link_to-with-a-block style: (path, html_options) { content }
  describe '#link_with_filter_to' do
    it 'links to the plain path, plus "?", when no filter is active' do
      with_filter({})

      expect(helper.link_with_filter_to('/ships') { 'Ships' }).to eq('<a href="/ships?">Ships</a>')
    end

    it 'carries the active filter along in the query string' do
      with_filter(use_ranking_data: 'swiss', format_id: '2')

      html = helper.link_with_filter_to('/ships') { 'Ships' }

      expect(html).to include('href="/ships?use_ranking_data=swiss&amp;format_id=2&amp;"')
    end

    it 'appends to a query string that is already there' do
      with_filter(format_id: '2')

      expect(helper.link_with_filter_to('/squadrons?ship_id=4') { 'Squadrons' }).to include('href="/squadrons?ship_id=4&amp;format_id=2&amp;"')
    end

    it 'url-encodes filter values' do
      with_filter(tournament_type: 'a b&c')

      expect(helper.link_with_filter_to('/ships') { 'Ships' }).to include('tournament_type=a+b%26c')
    end

    it 'passes html options through to link_to' do
      with_filter({})

      html = helper.link_with_filter_to('/pilots/1', class: 'link-with-hover-image') { 'Luke' }

      expect(html).to eq('<a class="link-with-hover-image" href="/pilots/1?">Luke</a>')
    end
  end
end
