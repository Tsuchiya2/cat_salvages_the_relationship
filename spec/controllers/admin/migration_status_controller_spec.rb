# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::MigrationStatusController, type: :controller do
  let(:admin_operator) { create(:operator, role: :operator) }
  let(:regular_operator) { create(:operator, role: :guest) }

  describe 'GET #show' do
    context 'when not authenticated' do
      it 'returns unauthorized status' do
        get :show
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns error message' do
        get :show
        body = JSON.parse(response.body)
        expect(body['error']).to eq('Authentication required')
      end
    end

    context 'when authenticated as regular operator' do
      before do
        session[:operator_id] = regular_operator.id
      end

      it 'returns forbidden status' do
        get :show
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns error message' do
        get :show
        body = JSON.parse(response.body)
        expect(body['error']).to eq('Admin access required')
      end
    end

    context 'when authenticated as admin' do
      before do
        session[:operator_id] = admin_operator.id
      end

      it 'returns success status' do
        get :show
        expect(response).to have_http_status(:success)
      end

      it 'returns migration status information' do
        get :show
        body = JSON.parse(response.body)

        expect(body).to include(
          'migration_in_progress',
          'progress',
          'current_database',
          'timestamp'
        )
      end

      context 'when migration is in progress' do
        let(:progress_flag) { Rails.root.join('tmp/migration_in_progress') }

        before do
          FileUtils.touch(progress_flag)
        end

        after do
          File.delete(progress_flag) if File.exist?(progress_flag)
        end

        it 'indicates migration in progress' do
          get :show
          body = JSON.parse(response.body)
          expect(body['migration_in_progress']).to be true
        end
      end

      context 'when no migration in progress' do
        before do
          # Clean up migration files
          FileUtils.rm_f(Rails.root.join('tmp/migration_in_progress'))
          FileUtils.rm_f(Rails.root.join('tmp/migration_progress.json'))
        end

        it 'indicates no migration' do
          get :show
          body = JSON.parse(response.body)
          expect(body['migration_in_progress']).to be false
        end

        it 'returns not_started status' do
          get :show
          body = JSON.parse(response.body)
          expect(body['progress']['status']).to eq('not_started')
        end
      end

      it 'returns current database information' do
        get :show
        body = JSON.parse(response.body)

        expect(body['current_database']).to include(
          'adapter',
          'database',
          'version'
        )
      end
    end
  end
end
