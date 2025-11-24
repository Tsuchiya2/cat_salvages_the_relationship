# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/database_migration/progress_tracker'

RSpec.describe DatabaseMigration::ProgressTracker do
  let(:tables) { %w[users posts comments] }
  let(:tracker) { described_class.new(tables: tables) }

  describe '#initialize' do
    it 'initializes progress for all tables' do
      expect(tracker.tables).to eq(tables)
      expect(tracker.progress).to have_key('users')
      expect(tracker.progress).to have_key('posts')
      expect(tracker.progress).to have_key('comments')
    end

    it 'sets initial progress to zero' do
      expect(tracker.progress['users']).to eq(completed: 0, total: 0, percentage: 0.0)
    end
  end

  describe '#update_progress' do
    it 'updates progress for a table' do
      result = tracker.update_progress(table: 'users', completed: 50, total: 100)

      expect(result[:completed]).to eq(50)
      expect(result[:total]).to eq(100)
      expect(result[:percentage]).to eq(50.0)
    end

    it 'handles zero total gracefully' do
      result = tracker.update_progress(table: 'users', completed: 0, total: 0)

      expect(result[:percentage]).to eq(0.0)
    end

    it 'raises ArgumentError for unknown table' do
      expect do
        tracker.update_progress(table: 'unknown', completed: 10, total: 100)
      end.to raise_error(ArgumentError, /Unknown table/)
    end
  end

  describe '#overall_progress' do
    context 'with no progress' do
      it 'returns 0.0' do
        expect(tracker.overall_progress).to eq(0.0)
      end
    end

    context 'with partial progress' do
      before do
        tracker.update_progress(table: 'users', completed: 100, total: 100)
        tracker.update_progress(table: 'posts', completed: 50, total: 100)
        tracker.update_progress(table: 'comments', completed: 0, total: 100)
      end

      it 'calculates overall progress correctly' do
        # 150 completed out of 300 total = 50%
        expect(tracker.overall_progress).to eq(50.0)
      end
    end

    context 'with complete progress' do
      before do
        tracker.update_progress(table: 'users', completed: 100, total: 100)
        tracker.update_progress(table: 'posts', completed: 100, total: 100)
        tracker.update_progress(table: 'comments', completed: 100, total: 100)
      end

      it 'returns 100.0' do
        expect(tracker.overall_progress).to eq(100.0)
      end
    end
  end

  describe '#summary' do
    before do
      tracker.update_progress(table: 'users', completed: 100, total: 100)
      tracker.update_progress(table: 'posts', completed: 50, total: 100)
    end

    it 'returns comprehensive summary' do
      summary = tracker.summary

      expect(summary).to include(
        tables: instance_of(Hash),
        overall: instance_of(Float),
        total_completed: 150,
        total_rows: 200,
        completed_tables: 1,
        total_tables: 3,
        timestamp: instance_of(String)
      )
    end
  end

  describe '.migration_in_progress?' do
    let(:progress_flag) { Rails.root.join('tmp/migration_in_progress') }

    after do
      File.delete(progress_flag) if File.exist?(progress_flag)
    end

    it 'returns false when flag file does not exist' do
      File.delete(progress_flag) if File.exist?(progress_flag)
      expect(described_class.migration_in_progress?).to be false
    end

    it 'returns true when flag file exists' do
      FileUtils.touch(progress_flag)
      expect(described_class.migration_in_progress?).to be true
    end
  end

  describe '.mark_migration_started' do
    let(:progress_flag) { Rails.root.join('tmp/migration_in_progress') }

    after do
      File.delete(progress_flag) if File.exist?(progress_flag)
    end

    it 'creates migration in progress flag' do
      described_class.mark_migration_started
      expect(File.exist?(progress_flag)).to be true
    end
  end

  describe '.mark_migration_completed' do
    let(:progress_flag) { Rails.root.join('tmp/migration_in_progress') }

    before do
      FileUtils.touch(progress_flag)
    end

    it 'removes migration in progress flag' do
      described_class.mark_migration_completed
      expect(File.exist?(progress_flag)).to be false
    end
  end
end
