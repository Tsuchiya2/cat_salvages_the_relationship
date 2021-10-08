require 'rails_helper'

RSpec.describe Content, type: :model do
  let(:content) { build(:content) }

  describe '正常系テスト' do
    context '全て有効な場合' do
      it '保存できる。' do
      end
    end

    context 'body' do
      it '文字列が2以上の場合、保存できる。' do
      end

      it '文字列が255以下の場合、保存できる。' do
      end
    end
  end

  describe '異常系テスト' do
    context 'body' do
      it '空の状態だと、保存できない。' do
      end

      it '1以下の文字列が入力された場合、保存できない。' do
      end

      it '256以上の文字列が入力された場合、保存できない。' do
      end
    end

    context 'content_category_id' do
      it '空の状態だと、保存できない。' do
      end
    end
  end
end
