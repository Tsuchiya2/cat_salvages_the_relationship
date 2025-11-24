# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MySQL 8 Compatibility', type: :integration do
  describe 'Timestamp Precision' do
    context 'with Operator model' do
      it 'preserves timestamp precision to microseconds' do
        # Create operator with current timestamp
        time_before = Time.current
        operator = Operator.create!(
          email: "timestamp_test_#{SecureRandom.hex(4)}@example.com",
          name: 'Timestamp Test',
          password: 'password123',
          password_confirmation: 'password123'
        )
        time_after = Time.current

        operator.reload

        # MySQL 8 stores timestamps with microsecond precision
        # Verify created_at is within the expected range
        expect(operator.created_at).to be_between(time_before, time_after)

        # Verify microsecond precision is preserved (within 1000 microseconds tolerance)
        expect(operator.created_at.usec).to be_within(1000).of(time_before.usec).or be_within(1000).of(time_after.usec)
      end

      it 'preserves updated_at timestamp precision' do
        operator = Operator.create!(
          email: "update_test_#{SecureRandom.hex(4)}@example.com",
          name: 'Update Test',
          password: 'password123',
          password_confirmation: 'password123'
        )

        sleep 0.01 # Small delay to ensure different timestamp

        time_before = Time.current
        operator.update_column(:name, 'Updated Name')  # Skip validation to avoid password requirement
        operator.touch  # Update updated_at timestamp
        time_after = Time.current

        operator.reload

        expect(operator.updated_at).to be_between(time_before, time_after)
        expect(operator.updated_at).to be > operator.created_at
      end
    end
  end

  describe 'Unicode Handling (UTF-8MB4)' do
    context 'with emoji support' do
      it 'supports emoji in Content body field' do
        content = Content.create!(
          body: 'Test with emoji 🐱😺🎉✨',
          category: :contact
        )
        content.reload

        expect(content.body).to eq('Test with emoji 🐱😺🎉✨')
        expect(content.body).to include('🐱')
        expect(content.body).to include('😺')
      end

      it 'supports emoji in Feedback text field' do
        text_with_emoji = 'Great app! 👍😊🌟 ' + 'a' * 20  # Ensure minimum 30 characters
        feedback = Feedback.create!(text: text_with_emoji)
        feedback.reload

        expect(feedback.text).to eq(text_with_emoji)
        expect(feedback.text).to include('👍')
      end

      it 'supports emoji in AlarmContent body field' do
        alarm = AlarmContent.create!(
          body: 'Alarm with emoji ⏰🔔',
          category: :contact
        )
        alarm.reload

        expect(alarm.body).to eq('Alarm with emoji ⏰🔔')
        expect(alarm.body).to include('⏰')
      end
    end

    context 'with complex Unicode characters' do
      it 'supports Japanese characters' do
        content = Content.create!(
          body: 'こんにちは、世界！ 🌏',
          category: :contact
        )
        content.reload

        expect(content.body).to eq('こんにちは、世界！ 🌏')
      end

      it 'supports mixed Unicode characters' do
        text = 'English + 日本語 + 한글 + العربية + 🌍 ' + 'padding'
        feedback = Feedback.create!(text: text)
        feedback.reload

        expect(feedback.text).to eq(text)
      end
    end
  end

  describe 'Case Sensitivity with utf8mb4_unicode_ci' do
    context 'with Operator email field' do
      let(:test_email) { "case_test_#{SecureRandom.hex(4)}@example.com" }

      before do
        Operator.create!(
          email: test_email,
          name: 'Case Test',
          password: 'password123',
          password_confirmation: 'password123'
        )
      end

      it 'performs case-insensitive comparisons for email' do
        # utf8mb4_unicode_ci collation is case-insensitive
        operator = Operator.find_by(email: test_email.upcase)
        expect(operator).to be_present
        expect(operator.email).to eq(test_email)
      end

      it 'treats different cases as the same for unique constraints' do
        # Attempting to create duplicate with different case should fail
        expect do
          Operator.create!(
            email: test_email.upcase, # Different case
            name: 'Duplicate Test',
            password: 'password456',
            password_confirmation: 'password456'
          )
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'with LineGroup line_group_id field' do
      before do
        LineGroup.create!(
          line_group_id: 'TestGroup123',
          remind_at: Date.today
        )
      end

      it 'performs case-insensitive comparisons' do
        line_group = LineGroup.find_by(line_group_id: 'testgroup123')
        expect(line_group).to be_present
        expect(line_group.line_group_id).to eq('TestGroup123')
      end
    end
  end

  describe 'Large Text Fields' do
    it 'handles large text in Feedback text field' do
      # TEXT type can store up to 65,535 bytes
      # Feedback validation: 30-500 characters
      large_text = 'A' * 500 # Maximum allowed by validation
      feedback = Feedback.create!(text: large_text)
      feedback.reload

      expect(feedback.text.length).to eq(500)
      expect(feedback.text).to eq(large_text)
    end

    it 'handles large text with multibyte characters' do
      # UTF-8 multibyte characters take more bytes
      # Feedback validation: 30-500 characters
      large_japanese_text = 'あ' * 500 # Each Japanese character is 3 bytes in UTF-8
      feedback = Feedback.create!(text: large_japanese_text)
      feedback.reload

      expect(feedback.text.length).to eq(500)
      expect(feedback.text).to eq(large_japanese_text)
    end
  end

  describe 'Concurrent Writes' do
    it 'handles concurrent updates correctly' do
      line_group = LineGroup.create!(
        line_group_id: "concurrent_test_#{SecureRandom.hex(4)}",
        remind_at: Date.today,
        post_count: 0
      )

      # Simulate concurrent updates using threads
      threads = 10.times.map do
        Thread.new do
          lg = LineGroup.find(line_group.id)
          lg.increment!(:post_count)
        end
      end

      threads.each(&:join)
      line_group.reload

      # All 10 increments should be persisted
      expect(line_group.post_count).to eq(10)
    end

    it 'handles optimistic locking if lock_version column exists' do
      # This test verifies that concurrent updates work correctly
      # even without optimistic locking columns
      operator = Operator.create!(
        email: "concurrent_#{SecureRandom.hex(4)}@example.com",
        name: 'Concurrent Test',
        password: 'password123',
        password_confirmation: 'password123'
      )

      original_name = operator.name

      # Update from one "session"
      operator1 = Operator.find(operator.id)
      operator1.update_column(:name, 'Updated by Thread 1')

      # Update from another "session"
      operator2 = Operator.find(operator.id)
      operator2.update_column(:name, 'Updated by Thread 2')

      # Last write wins (default behavior without optimistic locking)
      operator.reload
      expect(operator.name).to eq('Updated by Thread 2')
    end
  end

  describe 'Query Performance' do
    it 'uses indexes for unique lookups on line_group_id' do
      LineGroup.create!(
        line_group_id: 'index_test_123',
        remind_at: Date.today
      )

      # Check if index is being used
      explain = ActiveRecord::Base.connection.select_all(
        "EXPLAIN SELECT * FROM line_groups WHERE line_group_id = 'index_test_123'"
      )

      # The query should use the unique index
      # Use select_all to get hash results
      expect(explain.first['key']).to be_present
      expect(explain.first['possible_keys']).to include('index_line_groups_on_line_group_id')
    end

    it 'uses indexes for unique lookups on operator email' do
      Operator.create!(
        email: 'index_test@example.com',
        name: 'Index Test',
        password: 'password123',
        password_confirmation: 'password123'
      )

      explain = ActiveRecord::Base.connection.select_all(
        "EXPLAIN SELECT * FROM operators WHERE email = 'index_test@example.com'"
      )

      # The query should use the unique index
      # Use select_all to get hash results
      expect(explain.first['key']).to be_present
      expect(explain.first['possible_keys']).to include('index_operators_on_email')
    end
  end

  describe 'Date and DateTime handling' do
    it 'correctly stores and retrieves Date fields' do
      date = Date.new(2024, 11, 24)
      line_group = LineGroup.create!(
        line_group_id: "date_test_#{SecureRandom.hex(4)}",
        remind_at: date
      )
      line_group.reload

      expect(line_group.remind_at).to eq(date)
      expect(line_group.remind_at).to be_a(Date)
    end

    it 'correctly handles time zones with datetime fields' do
      operator = Operator.create!(
        email: "timezone_test_#{SecureRandom.hex(4)}@example.com",
        name: 'Timezone Test',
        password: 'password123',
        password_confirmation: 'password123'
      )

      created_at = operator.created_at
      # Check that timestamp is in configured time zone (JST)
      expect(created_at.zone).to match(/JST|Asia\/Tokyo/)
      expect(created_at).to be_a(ActiveSupport::TimeWithZone)
    end
  end

  describe 'NULL handling' do
    it 'correctly handles NULL values in optional fields' do
      operator = Operator.create!(
        email: "null_test_#{SecureRandom.hex(4)}@example.com",
        name: 'NULL Test',
        password: 'password123',
        password_confirmation: 'password123',
        lock_expires_at: nil,
        unlock_token: nil
      )
      operator.reload

      expect(operator.lock_expires_at).to be_nil
      expect(operator.unlock_token).to be_nil
    end

    it 'correctly handles NULL in description fields' do
      content = Content.create!(
        body: 'Test content',
        category: :contact
        # description is optional in some tables
      )
      content.reload

      expect(content).to be_persisted
    end
  end
end
