require 'rails_helper'

RSpec.describe ContentCategory, type: :model do
  let(:content_category) { build(:content_category) }

  describe '正常系テスト' do
    context '全て有効な場合' do
      it '保存できる。' do
        expect(content_category).to be_valid
      end
    end

    context 'name' do
      it '文字列が2以上の入の場合、保存できる。' do
        content_category[:name] = 'a' * 2
        expect(content_category).to be_valid
      end

      it '文字列が255以下の入力の場合、保存できる' do
        content_category[:name] = 'a' * 255
        expect(content_category).to be_valid
      end
    end
  end

  describe '異常系テスト' do
    context 'name' do
      it '空の状態だと、保存できない。' do
        content_category[:name] = nil
        content_category.valid?
        expect(content_category.errors.full_messages).to include('カテゴリー名 が空白です')
      end

      it '1以下の文字列が入力された場合、保存できない。' do
        content_category[:name] = 'a' * 1
        content_category.valid?
        expect(content_category.errors.full_messages).to include('カテゴリー名 が短すぎです')
      end

      it '256以上の文字列が入力された場合、保存できない。' do
        content_category[:name] = 'a' * 256
        content_category.valid?
        expect(content_category.errors.full_messages).to include('カテゴリー名 が長すぎです')
      end
    end
  end
end
