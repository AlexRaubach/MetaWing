require 'rails_helper'

RSpec.describe FilterHelper, type: :helper do
  describe '#show_filter?' do
    it 'is true for the index and show pages of the ranked resources' do
      %w[ships pilots ship_combos upgrades squadrons].product(%w[index show]).each do |controller, action|
        expect(helper.show_filter?(controller, action)).to be(true), "#{controller}##{action}"
      end
    end

    it 'is false for other pages' do
      expect(helper.show_filter?('abouts', 'show')).to be(false)
      expect(helper.show_filter?('overviews', 'index')).to be(false)
      expect(helper.show_filter?('ship_combos', 'update')).to be(false)
    end
  end

  describe '#preset_dates' do
    it 'starts with a blank choice and ends with today' do
      expect(helper.preset_dates.first).to eq(['', nil])
      expect(helper.preset_dates.last).to eq(['Today', Date.today])
    end

    it 'lists the game milestones in chronological order with a label each' do
      labels, dates = helper.preset_dates[1..].transpose

      expect(dates).to eq(dates.sort)
      expect(dates.first).to eq(Date.new(2018, 9, 13))
      expect(labels).to all(be_present)
      expect(labels.grep(/translation missing/i)).to be_empty
    end
  end

  describe '#preset_ranking_data' do
    it 'offers exactly the values the rankers understand' do
      expect(helper.preset_ranking_data.map(&:last)).to eq(%w[swiss elimination all])

      helper.preset_ranking_data.each do |_label, value|
        expect { Rankers::WeightQueryBuilder.new(use_ranking_data: value).build_weight_query }.not_to raise_error
      end
    end
  end
end
