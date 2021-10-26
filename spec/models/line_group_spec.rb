require 'rails_helper'

RSpec.describe LineGroup, type: :model do
  let(:line_group) { create(:line_group) }

  describe '正常系テスト' do
    context '全て有効な場合' do
      it '保存できる。' do
        expect(line_group).to be_valid
      end
    end

    context 'line_group_id' do
      it '文字列が255以下の場合、保存できる。' do
        line_group[:line_group_id] = 'a' * 255
        expect(line_group).to be_valid
      end
    end

    context 'post_count' do
      it '数値が0以上の場合、保存できる。' do
        line_group[:post_count] = 0
        expect(line_group).to be_valid
      end

      it '数値が100_000_000以下の場合、保存できる。' do
        line_group[:post_count] = 100_000_000
        expect(line_group).to be_valid
      end
    end
  end

  describe '異常系テスト' do
    context 'line_group_id' do
      it '空の状態だと、保存できない。' do
        line_group[:line_group_id] = nil
        line_group.valid?
        expect(line_group.errors.full_messages).to include('グループID が空白です')
      end

      it '一意な値ではない場合、保存できない。' do
        new_line_group = build(:line_group, line_group_id: line_group.line_group_id)
        new_line_group.valid?
        expect(new_line_group.errors.full_messages).to include('グループID が重複しています')
      end

      it '256以上の文字列が入力された場合、保存できない。' do
        line_group[:line_group_id] = 'a' * 256
        line_group.valid?
        expect(line_group.errors.full_messages).to include('グループID が長すぎです')
      end
    end

    context 'remind_at' do
      it '空の状態だと、保存できない。' do
        line_group[:remind_at] = nil
        line_group.valid?
        expect(line_group.errors.full_messages).to include('リマインド が空白です')
      end
    end

    context 'status' do
      it '空の状態だと、保存できない。' do
        line_group[:status] = nil
        line_group.valid?
        expect(line_group.errors.full_messages).to include('状態 が空白です')
      end
    end

    context 'post_count' do
      it '空の状態だと、保存できない。' do
        line_group[:post_count] = nil
        line_group.valid?
        expect(line_group.errors.full_messages).to include('投稿数 が空白です')
      end

      it '数値が0未満の場合、保存できない。' do
        line_group[:post_count] = -1
        line_group.valid?
        expect(line_group.errors.full_messages).to include('投稿数 が0より小さい値です')
      end

      it '数値が100_000_001以上の場合、保存できない。' do
        line_group[:post_count] = 100_000_001
        line_group.valid?
        expect(line_group.errors.full_messages).to include('投稿数 が100_000_000より大きい値です')
      end

      it '文字列"abc"が入力された場合、保存できない。' do
        line_group[:post_count] = 'abc'
        line_group.valid?
        expect(line_group.errors.full_messages).to include('投稿数 が数値ではありません')
      end
    end
  end
end
