require 'rails_helper'

RSpec.describe Rankers::WeightQueryBuilder do
  def builder(**configuration)
    described_class.new({ use_ranking_data: 'swiss' }.merge(configuration))
  end

  def squish(sql)
    sql.squish
  end

  describe '#build_weight_query' do
    it 'averages the swiss percentile' do
      expect(squish(builder.build_weight_query))
        .to eq('avg( ( case when squadrons.swiss_percentile is not null then squadrons.swiss_percentile else 0 end ) ) as weight')
    end

    it 'averages the elimination percentile' do
      sql = squish(builder(use_ranking_data: 'elimination').build_weight_query)

      expect(sql).to include('squadrons.elimination_percentile')
      expect(sql).not_to include('swiss_percentile')
    end

    it 'adds swiss and elimination percentiles together for "all"' do
      sql = squish(builder(use_ranking_data: 'all').build_weight_query)

      expect(sql).to match(/swiss_percentile else 0 end \+ case when squadrons\.elimination_percentile/)
    end

    it 'scales by tournament size inside the average when asked to' do
      sql = squish(builder(large_tournament_multiplier: true).build_weight_query)

      expect(sql).to match(/\) \* case when tournaments\.num_players is not null and tournaments\.num_players > 0 then log\(tournaments\.num_players\) else 0 end \) as weight\z/)
    end

    it 'scales the average by how widely the entry is used when asked to' do
      sql = squish(builder(widespread_use_multiplier: true).build_weight_query)

      expect(sql).to end_with(') * (log(count(distinct squadrons.id) + 1)) as weight')
    end

    it 'leaves both multipliers out by default' do
      sql = builder.build_weight_query

      expect(sql).not_to include('num_players')
      expect(sql).not_to include('count(distinct')
    end
  end

  describe '#build_average_query' do
    it 'halves the combined percentile for "all" so it stays between 0 and 1' do
      expect(squish(builder(use_ranking_data: 'all').build_average_query)).to end_with(') / 2')
    end

    it 'uses a single percentile otherwise' do
      expect(squish(builder(use_ranking_data: 'swiss').build_average_query)).not_to include('/ 2')
      expect(squish(builder(use_ranking_data: 'elimination').build_average_query)).to include('elimination_percentile')
    end
  end

  describe '#build_win_loss_query' do
    it 'picks the win/loss ratio matching the ranking data' do
      expect(squish(builder(use_ranking_data: 'swiss').build_win_loss_query)).to eq('avg(squadrons.win_loss_ratio_swiss)')
      expect(squish(builder(use_ranking_data: 'elimination').build_win_loss_query)).to eq('avg(squadrons.win_loss_ratio_elimination)')
      expect(squish(builder(use_ranking_data: 'all').build_win_loss_query)).to include('win_loss_ratio_swiss + squadrons.win_loss_ratio_elimination')
    end
  end

  it 'rejects unknown ranking data' do
    bogus = builder(use_ranking_data: 'bogus')

    expect { bogus.build_weight_query }.to raise_error(RuntimeError)
    expect { bogus.build_average_query }.to raise_error(RuntimeError)
    expect { bogus.build_win_loss_query }.to raise_error(RuntimeError)
  end
end
