require 'rails_helper'

RSpec.describe ShipCombo, type: :model do
  describe '#suggest_archetype_name!' do
    let(:ship_combo) { ShipCombo.create! }

    it 'records a pending suggestion with the submitter ip and comment' do
      suggestion = ship_combo.suggest_archetype_name!('203.0.113.9', name_suggestion: 'Rebel Beef', comment: 'it is beefy')

      expect(suggestion).to be_persisted
      expect(suggestion).to have_attributes(
        ship_combo:      ship_combo,
        ip_address:      '203.0.113.9',
        name_suggestion: 'Rebel Beef',
        comment:         'it is beefy',
        status:          'new'
      )
    end

    it 'ignores blank suggestions' do
      expect {
        ship_combo.suggest_archetype_name!('203.0.113.9', name_suggestion: '   ')
        ship_combo.suggest_archetype_name!('203.0.113.9', {})
      }.not_to change(ArchetypeNameSuggestion, :count)
    end
  end
end
