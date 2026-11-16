require 'rails_helper'

RSpec.describe ArchetypeNameSuggestion, type: :model do
  let(:ship_combo) { ShipCombo.create! }

  it 'defaults to the "new" status' do
    expect(ArchetypeNameSuggestion.new.status).to eq('new')
  end

  it 'only allows known statuses' do
    suggestion = ArchetypeNameSuggestion.new(ship_combo: ship_combo, name_suggestion: 'Rebel Beef')

    %w[new accepted rejected].each do |status|
      suggestion.status = status
      expect(suggestion).to be_valid
    end

    suggestion.status = 'maybe'
    expect(suggestion).not_to be_valid
  end

  describe '.pending' do
    it 'returns only suggestions awaiting moderation' do
      pending_suggestion = ArchetypeNameSuggestion.create!(ship_combo: ship_combo, name_suggestion: 'A')
      ArchetypeNameSuggestion.create!(ship_combo: ship_combo, name_suggestion: 'B', status: 'accepted')
      ArchetypeNameSuggestion.create!(ship_combo: ship_combo, name_suggestion: 'C', status: 'rejected')

      expect(ArchetypeNameSuggestion.pending).to eq([pending_suggestion])
    end
  end
end
