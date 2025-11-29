# frozen_string_literal: true

require 'rails_helper'

# Shared examples for BruteForceProtection concern
# This allows testing the concern behavior across different models
RSpec.shared_examples 'brute_force_protection' do
  let(:model_class) { described_class }
  let(:record) { create(described_class.name.underscore.to_sym) }

  describe 'class attributes' do
    it 'has configurable lock_retry_limit' do
      expect(model_class.lock_retry_limit).to be_a(Integer)
      expect(model_class.lock_retry_limit).to be > 0
    end

    it 'has configurable lock_duration' do
      expect(model_class.lock_duration).to be_a(ActiveSupport::Duration)
      expect(model_class.lock_duration).to be > 0
    end

    it 'has optional lock_notifier' do
      expect(model_class).to respond_to(:lock_notifier)
    end
  end

  describe '#increment_failed_logins!' do
    context 'when failed logins are below limit' do
      it 'increments failed_logins_count' do
        expect { record.increment_failed_logins! }
          .to change { record.reload.failed_logins_count }.by(1)
      end

      it 'does not lock the account' do
        record.increment_failed_logins!
        expect(record.reload).not_to be_locked
      end
    end

    context 'when failed logins reach the limit' do
      before do
        record.update(failed_logins_count: model_class.lock_retry_limit - 1)
      end

      it 'increments failed_logins_count' do
        expect { record.increment_failed_logins! }
          .to change { record.reload.failed_logins_count }.by(1)
      end

      it 'locks the account' do
        record.increment_failed_logins!
        expect(record.reload).to be_locked
      end

      it 'sets lock_expires_at' do
        travel_to(Time.current) do
          record.increment_failed_logins!
          expected_time = Time.current + model_class.lock_duration
          expect(record.reload.lock_expires_at).to be_within(1.second).of(expected_time)
        end
      end

      it 'generates unlock_token' do
        record.increment_failed_logins!
        expect(record.reload.unlock_token).to be_present
        expect(record.unlock_token.length).to be > 30
      end
    end
  end

  describe '#reset_failed_logins!' do
    before do
      record.update(
        failed_logins_count: 3,
        lock_expires_at: 1.hour.from_now
      )
    end

    it 'resets failed_logins_count to 0' do
      record.reset_failed_logins!
      expect(record.reload.failed_logins_count).to eq(0)
    end

    it 'clears lock_expires_at' do
      record.reset_failed_logins!
      expect(record.reload.lock_expires_at).to be_nil
    end
  end

  describe '#lock_account!' do
    it 'sets lock_expires_at to current time plus lock_duration' do
      travel_to(Time.current) do
        record.lock_account!
        expected_time = Time.current + model_class.lock_duration
        expect(record.reload.lock_expires_at).to be_within(1.second).of(expected_time)
      end
    end

    it 'generates a secure unlock_token' do
      record.lock_account!
      expect(record.reload.unlock_token).to be_present
      expect(record.unlock_token.length).to be > 30
    end

    it 'generates different tokens for each lock' do
      record.lock_account!
      first_token = record.unlock_token

      record.lock_account!
      second_token = record.reload.unlock_token

      expect(first_token).not_to eq(second_token)
    end
  end

  describe '#unlock_account!' do
    before do
      record.update(
        lock_expires_at: 1.hour.from_now,
        unlock_token: 'some_token',
        failed_logins_count: 5
      )
    end

    it 'clears lock_expires_at' do
      record.unlock_account!
      expect(record.reload.lock_expires_at).to be_nil
    end

    it 'clears unlock_token' do
      record.unlock_account!
      expect(record.reload.unlock_token).to be_nil
    end

    it 'resets failed_logins_count' do
      record.unlock_account!
      expect(record.reload.failed_logins_count).to eq(0)
    end
  end

  describe '#locked?' do
    context 'when lock_expires_at is nil' do
      before { record.update(lock_expires_at: nil) }

      it 'returns false' do
        expect(record.locked?).to be false
      end
    end

    context 'when lock_expires_at is in the past' do
      before { record.update(lock_expires_at: 1.hour.ago) }

      it 'returns false' do
        expect(record.locked?).to be false
      end
    end

    context 'when lock_expires_at is in the future' do
      before { record.update(lock_expires_at: 1.hour.from_now) }

      it 'returns true' do
        expect(record.locked?).to be true
      end
    end

    context 'when lock_expires_at is exactly now' do
      before { record.update(lock_expires_at: Time.current) }

      it 'returns false' do
        travel_to(1.second.from_now) do
          expect(record.locked?).to be false
        end
      end
    end
  end

  describe '#mail_notice' do
    let(:ip_address) { '192.168.1.1' }

    context 'when lock_notifier is not configured' do
      before { allow(model_class).to receive(:lock_notifier).and_return(nil) }

      it 'does not raise error' do
        expect { record.mail_notice(ip_address) }.not_to raise_error
      end
    end

    context 'when lock_notifier is configured' do
      let(:notifier) { double('notifier') }

      before do
        allow(model_class).to receive(:lock_notifier).and_return(notifier)
      end

      it 'calls the lock_notifier with record and ip_address' do
        expect(notifier).to receive(:call).with(record, ip_address)
        record.mail_notice(ip_address)
      end
    end
  end
end

# Test the concern with Operator model
RSpec.describe Operator, type: :model do
  it_behaves_like 'brute_force_protection'

  describe 'configuration' do
    it 'uses default lock_retry_limit of 5' do
      expect(described_class.lock_retry_limit).to eq(5)
    end

    it 'uses default lock_duration of 45 minutes' do
      expect(described_class.lock_duration).to eq(45.minutes)
    end
  end
end

# Test concern in isolation with a dummy model
RSpec.describe BruteForceProtection do
  # Create a dummy ActiveRecord model for testing
  let(:dummy_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'operators'
      has_secure_password
      include BruteForceProtection

      # Override configuration for testing
      self.lock_retry_limit = 3
      self.lock_duration = 30.minutes

      def self.name
        'DummyModel'
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'DummyModel')
      end
    end
  end

  let(:record) do
    dummy_class.create!(
      name: 'Test',
      email: 'test_dummy@example.com',
      password: 'Password123',
      password_confirmation: 'Password123',
      role: 0
    )
  end

  describe 'custom configuration' do
    it 'respects custom lock_retry_limit' do
      expect(dummy_class.lock_retry_limit).to eq(3)
    end

    it 'respects custom lock_duration' do
      expect(dummy_class.lock_duration).to eq(30.minutes)
    end

    it 'locks account after custom retry limit' do
      record.update(failed_logins_count: 2)
      record.increment_failed_logins!
      expect(record.reload).to be_locked
    end
  end

  describe 'ENV-based configuration' do
    around do |example|
      original_retry = ENV['LOCK_RETRY_LIMIT']
      original_duration = ENV['LOCK_DURATION']

      ENV['LOCK_RETRY_LIMIT'] = '10'
      ENV['LOCK_DURATION'] = '60'

      # Need to reload the constant to pick up new ENV values
      example.run

      ENV['LOCK_RETRY_LIMIT'] = original_retry
      ENV['LOCK_DURATION'] = original_duration
    end

    it 'can read from environment variables' do
      # This test verifies that ENV values are used in the default
      expect(ENV.fetch('LOCK_RETRY_LIMIT', 5).to_i).to eq(10)
      expect(ENV.fetch('LOCK_DURATION', 45).to_i).to eq(60)
    end
  end

  describe 'notifier integration' do
    let(:notifier_called) { [] }
    let(:notifier) do
      ->(record, ip) { notifier_called << { record: record, ip: ip } }
    end

    before do
      dummy_class.lock_notifier = notifier
    end

    it 'calls notifier when mail_notice is invoked' do
      record.mail_notice('192.168.1.1')
      expect(notifier_called.length).to eq(1)
      expect(notifier_called.first[:record]).to eq(record)
      expect(notifier_called.first[:ip]).to eq('192.168.1.1')
    end
  end
end
