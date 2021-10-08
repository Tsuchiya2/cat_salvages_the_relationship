require 'rails_helper'

RSpec.describe Content, type: :model do
  let(:content) { create(:content) }

  describe '正常系テスト' do
    context '全て有効な場合' do
      it '保存できる。' do
        expect(content).to be_valid
      end
    end

    context 'body' do
      it '文字列が2以上の場合、保存できる。' do
        content[:body] = 'a' * 2
        expect(content).to be_valid
      end

      it '文字列が65_535以下の場合、保存できる。' do
        content[:body] = 'a' * 65_535
        expect(content).to be_valid
      end
    end
  end

  describe '異常系テスト' do
    context 'body' do
      it '空の状態だと、保存できない。' do
        content[:body] = nil
        content.valid?
        expect(content.errors.full_messages).to include('内容 が空白です')
      end

      it '1以下の文字列が入力された場合、保存できない。' do
        content[:body] = 'a' * 1
        content.valid?
        expect(content.errors.full_messages).to include('内容 が短すぎです')
      end

      it '65_536以上の文字列が入力された場合、保存できない。' do
        content[:body] = 'a' * 65_536
        content.valid?
        expect(content.errors.full_messages).to include('内容 が長すぎです')
      end
    end

    context 'content_category_id' do
      it '空の状態だと、保存できない。' do
        content[:content_category_id] = nil
        content.valid?
        expect(content.errors.full_messages).to include('カテゴリー が空白です')
      end
    end
  end
end