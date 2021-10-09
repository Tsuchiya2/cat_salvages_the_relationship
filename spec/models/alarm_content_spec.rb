require 'rails_helper'

RSpec.describe AlarmContent, type: :model do
  let(:alarm_content) { build(:alarm_content) }

  describe '正常系テスト' do
    context '全て有効な場合' do
      it '保存できる。' do
        expect(alarm_content).to be_valid
      end
    end

    context 'body' do
      it '文字列が2以上の場合、保存できる。' do
        alarm_content[:body] = 'a' * 2
        expect(alarm_content).to be_valid
      end

      it '文字列が255以下の場合、保存できる。' do
        alarm_content[:body] = 'a' * 255
        expect(alarm_content).to be_valid
      end
    end
  end

  describe '異常系テスト' do
    context 'body' do
      it '空の状態だと、保存できない。' do
        alarm_content[:body] = nil
        alarm_content.valid?
        expect(alarm_content.errors.full_messages).to include('内容 が空白です')
      end

      it '1以下の文字列が入力された場合、保存できない。' do
        alarm_content[:body] = 'a' * 1
        alarm_content.valid?
        expect(alarm_content.errors.full_messages).to include('内容 が短すぎです')
      end

      it '256以上の文字列が入力された場合、保存できない。' do
        alarm_content[:body] = 'a' * 256
        alarm_content.valid?
        expect(alarm_content.errors.full_messages).to include('内容 が長すぎです')
      end
    end

    context 'category' do
      it '空の状態だと、保存できない。' do
        alarm_content[:category] = nil
        alarm_content.valid?
        expect(alarm_content.errors.full_messages).to include('カテゴリー が空白です')
      end
    end
  end
end
