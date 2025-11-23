# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Scheduler, type: :model do
  describe '.call_messages' do
    let(:sampler) { instance_double(Line::AlarmContentSampler) }

    before do
      allow(sampler).to receive(:available?).and_return(true, true)
    end

    it 'falls back when body is missing' do
      allow(sampler).to receive(:sample).and_return(nil)

      messages = described_class.call_messages(sampler)
      expect(messages[0][:text]).to eq('管理者へ連絡お願いします。')
      expect(messages[1][:text]).to eq('呼びかけメッセージを用意できなかったニャ…🐱')
    end
  end

  describe '.wait_messages' do
    let(:sampler) { instance_double(Line::ContentSampler) }

    before do
      allow(sampler).to receive(:available?).and_return(true, true, true)
    end

    it 'returns sample bodies when present' do
      allow(sampler).to receive(:sample).and_return(
        double(body: 'contact'),
        double(body: 'free'),
        double(body: 'text')
      )

      messages = described_class.wait_messages(sampler)
      expect(messages.map { |m| m[:text] }).to eq(%w[contact free text])
    end

    it 'uses fallbacks when samples are nil' do
      allow(sampler).to receive(:sample).and_return(nil, nil, nil)

      messages = described_class.wait_messages(sampler)
      expect(messages[0][:text]).to eq('いつでも声をかけてニャ！')
      expect(messages[1][:text]).to eq('今日はどんな一日だった？')
      expect(messages[2][:text]).to eq('もう少し仲良くなりたいニャ🐾')
    end
  end

  describe '.scheduler' do
    let(:sampler) { instance_double(Line::ContentSampler) }
    let(:group) { create(:line_group) }

    before do
      # Mock Rails credentials to prevent ApplicationMailer initialization error
      allow(Rails.application).to receive(:credentials).and_return(
        double(operator: { email: 'test@example.com' })
      )
    end

    it 'raises when required content is missing' do
      allow(sampler).to receive(:available?).and_return(false, true, true)
      allow(LineMailer).to receive(:error_email).and_return(double(deliver_later: true))

      expect do
        described_class.scheduler(LineGroup.where(id: group.id), sampler, :wait)
      end.to raise_error(StandardError, /コンテンツ未登録/)
    end
  end
end
