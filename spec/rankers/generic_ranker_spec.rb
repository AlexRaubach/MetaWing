require 'rails_helper'

RSpec.describe Rankers::GenericRanker do
  include_context 'meta scenario'

  def numbers(start_date: today - 30, end_date: today, tournament_type: nil, game_format: nil)
    described_class.new(start_date, end_date, tournament_type, game_format).numbers
  end

  it 'counts the tournaments and squadrons in the date range' do
    expect(numbers).to eq([2, 3])
  end

  it 'includes tournaments on the boundary dates' do
    expect(numbers(start_date: today - 10, end_date: today - 5)).to eq([2, 3])
    expect(numbers(start_date: today - 9, end_date: today - 6)).to eq([0, 0])
  end

  it 'filters by tournament type' do
    expect(numbers(tournament_type: casual_type.id)).to eq([1, 1])
  end

  it 'filters by format' do
    expect(numbers(game_format: extended.id)).to eq([1, 2])
  end

  it 'treats a blank type and format as no filter' do
    expect(numbers(tournament_type: '', game_format: '')).to eq([2, 3])
  end
end
