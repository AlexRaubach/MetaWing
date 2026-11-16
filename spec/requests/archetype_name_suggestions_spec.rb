require 'rails_helper'

RSpec.describe 'Archetype name suggestions (moderation)', type: :request do
  let(:xwing)      { create_ship('T-65 X-wing') }
  let(:ship_combo) { create_ship_combo(xwing, archetype_name: 'Old Name') }
  let!(:suggestion) do
    ArchetypeNameSuggestion.create!(ship_combo: ship_combo, name_suggestion: 'New Name', comment: 'because', ip_address: '203.0.113.9')
  end
  let(:moderator) { User.create!(email: 'moderator@example.test', password: 'correct horse battery') }

  def moderate(action)
    patch archetype_name_suggestion_path(suggestion, mod_action: action)
  end

  context 'when signed out' do
    it 'sends visitors to the sign-in page instead of the queue' do
      get archetype_name_suggestions_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'refuses to moderate' do
      moderate('accept_replace')

      expect(response).to redirect_to(new_user_session_path)
      expect(suggestion.reload.status).to eq('new')
      expect(ship_combo.reload.archetype_name).to eq('Old Name')
    end
  end

  context 'when signed in' do
    before { sign_in moderator }

    describe 'GET /archetype_name_suggestions' do
      it 'lists the pending suggestions' do
        ArchetypeNameSuggestion.create!(ship_combo: ship_combo, name_suggestion: 'Already Handled', status: 'rejected')

        get archetype_name_suggestions_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('New Name', 'Old Name', 'because', '203.0.113.9', 'T-65 X-wing')
        expect(response.body).not_to include('Already Handled')
      end
    end

    describe 'PATCH /archetype_name_suggestions/:id' do
      it 'accept_replace renames the archetype and drops the old name' do
        moderate('accept_replace')

        expect(ship_combo.reload).to have_attributes(archetype_name: 'New Name', alternate_names: nil)
        expect(suggestion.reload.status).to eq('accepted')
        expect(response).to redirect_to(archetype_name_suggestions_path)
      end

      it 'accept_bump renames the archetype and keeps the old name as an alternate' do
        moderate('accept_bump')

        expect(ship_combo.reload).to have_attributes(archetype_name: 'New Name', alternate_names: ['Old Name'])
        expect(suggestion.reload.status).to eq('accepted')
      end

      it 'accept_bump on an unnamed archetype just names it' do
        ship_combo.update!(archetype_name: nil)

        moderate('accept_bump')

        expect(ship_combo.reload).to have_attributes(archetype_name: 'New Name', alternate_names: nil)
      end

      it 'accept_alternate adds the suggestion to the alternate names' do
        ship_combo.update!(alternate_names: ['Earlier Alternate'])

        moderate('accept_alternate')

        expect(ship_combo.reload).to have_attributes(archetype_name: 'Old Name', alternate_names: ['Earlier Alternate', 'New Name'])
        expect(suggestion.reload.status).to eq('accepted')
      end

      it 'reject leaves the archetype alone' do
        moderate('reject')

        expect(ship_combo.reload).to have_attributes(archetype_name: 'Old Name', alternate_names: nil)
        expect(suggestion.reload.status).to eq('rejected')
      end

      it 'takes the handled suggestion out of the queue' do
        moderate('reject')
        follow_redirect!

        expect(response.body).not_to include('New Name')
      end

      it 'rejects an unknown action without changing anything' do
        moderate('delete_everything')

        expect(response).to have_http_status(:internal_server_error)
        expect(suggestion.reload.status).to eq('new')
        expect(ship_combo.reload.archetype_name).to eq('Old Name')
      end
    end
  end
end
