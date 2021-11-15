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

      it '数値が1_000_000_000以下の場合、保存できる。' do
        line_group[:post_count] = 1_000_000_000
        expect(line_group).to be_valid
      end
    end

    context 'member_count' do
      it '数値が0以上の場合、保存できる。' do
        line_group[:member_count] = 0
        expect(line_group).to be_valid
      end

      it '数値が50以下の場合、保存できる。' do
        line_group[:member_count] = 50
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

      it '数値が1_000_000_001以上の場合、保存できない。' do
        line_group[:post_count] = 1_000_000_001
        line_group.valid?
        expect(line_group.errors.full_messages).to include('投稿数 が100_000_000より大きい値です')
      end

      it '文字列"abc"が入力された場合、保存できない。' do
        line_group[:post_count] = 'abc'
        line_group.valid?
        expect(line_group.errors.full_messages).to include('投稿数 が数値ではありません')
      end
    end

    context 'member_count' do
      it '空の状態だと、保存できない。' do
        line_group[:member_count] = nil
        line_group.valid?
        expect(line_group.errors.full_messages).to include('人数 が空白です')
      end

      it '数値が0未満の場合、保存できない。' do
        line_group[:member_count] = -1
        line_group.valid?
        expect(line_group.errors.full_messages).to include('人数 が0より小さい値です')
      end

      it '数値が51以上の場合、保存できない。' do
        line_group[:member_count] = 51
        line_group.valid?
        expect(line_group.errors.full_messages).to include('人数 が50より大きい値です')
      end

      it '文字列"abc"が入力された場合、保存できない。' do
        line_group[:member_count] = 'abc'
        line_group.valid?
        expect(line_group.errors.full_messages).to include('人数 が数値ではありません')
      end
    end

    context 'set_span' do
      it '空の状態だと、保存できない。' do
        line_group[:set_span] = nil
        line_group.valid?
        expect(line_group.errors.full_messages).to include('期間 が空白です')
      end
    end
  end

  describe 'インスタンスメソッド' do
    context 'auto_change_status' do
      it 'faster設定' do
        before_remind_at = line_group.remind_at
        line_group.faster!
        line_group.update_line_group_record(5)
        expect(line_group.status).to eq 'wait'
        expect(line_group.remind_at).not_to eq before_remind_at
        expect(line_group.post_count).to be 1
        expect(line_group.member_count).to be 5
      end

      it 'latter設定' do
        before_remind_at = line_group.remind_at
        line_group.latter!
        line_group.update_line_group_record(5)
        expect(line_group.status).to eq 'wait'
        expect(line_group.remind_at).not_to eq before_remind_at
        expect(line_group.post_count).to be 1
        expect(line_group.member_count).to be 5
      end

      it 'random設定' do
        before_remind_at = line_group.remind_at
        line_group.update_line_group_record(5)
        expect(line_group.status).to eq 'wait'
        expect(line_group.remind_at).not_to eq before_remind_at
        expect(line_group.post_count).to be 1
        expect(line_group.member_count).to be 5
      end
    end
  end
end
