require 'rails_helper'

RSpec.describe Feedback, type: :model do
  let(:feedback) { build(:feedback) }

  describe '正常系テスト' do
    context '全て有効な場合' do
      it '保存できる。' do
        expect(feedback).to be_valid
      end
    end

    context 'text' do
      it '文字列が30上の場合、保存できる。' do
        feedback[:text] = 'a' * 30
        expect(feedback).to be_valid
      end

      it '文字列が500以下の場合、保存できる。' do
        feedback[:text] = 'a' * 500
        expect(feedback).to be_valid
      end
    end
  end

  describe '異常系テスト' do
    context 'text' do
      it '空の状態だと、保存できない。' do
        feedback[:text] = nil
        feedback.valid?
        expect(feedback.errors.full_messages).to include('内容 が空白です')
      end

      it '29以下の文字列が入力された場合、保存できない。' do
        feedback[:text] = 'a' * 29
        feedback.valid?
        expect(feedback.errors.full_messages).to include('内容 が短すぎです')
      end

      it '501以上の文字列が入力された場合、保存できない。' do
        feedback[:text] = 'a' * 501
        feedback.valid?
        expect(feedback.errors.full_messages).to include('内容 が長すぎです')
      end
    end
  end
end
