require 'rails_helper'

RSpec.describe Operator, type: :model do
  let(:operator) { build(:operator) }
  let(:created_operator) { create(:operator) }

  describe '正常系テスト' do
    context '全て有効な場合' do
      it '保存できる。' do
        expect(operator).to be_valid
      end
    end

    context 'name' do
      it '2つ以上の文字列が入力された場合、保存できる。' do
        operator[:name] = 'aZ'
        expect(operator).to be_valid
      end

      it '255以下の文字列が入力された場合、保存できる。' do
        operator[:name] = 'a' * 255
        expect(operator).to be_valid
      end
    end

    context 'email' do
      it '@マークを含む文字列が入力された場合、保存できる。' do
        operator[:email] = 'sample@example.com'
        expect(operator).to be_valid
      end
    end

    context 'password' do
      it '8つ以上の文字列が入力された場合、保存できる。' do
        operator = build(:operator, password: 'a' * 8, password_confirmation: 'a' * 8)
        expect(operator).to be_valid
      end
    end

    context 'role' do
      it '0以上の値が入力された場合、保存できる。' do
        operator[:role] = 0
        expect(operator).to be_valid
      end

      it '1以下の値が入力された場合、保存できる。' do
        operator[:role] = 1
        expect(operator).to be_valid
      end
    end
  end

  describe '異常系テスト' do
    context 'name' do
      it '空の状態だと、保存できない。' do
        operator = build(:operator, name: nil)
        operator.valid?
        expect(operator.errors.full_messages).to include('名前 が空白です')
      end

      it '1以下の文字列が入力された場合、保存できない。' do
        operator = build(:operator, name: 'a')
        operator.valid?
        expect(operator.errors.full_messages).to include('名前 が短すぎです')
      end

      it '256以上の文字列が入力された場合、保存できない。' do
        operator = build(:operator, name: 'a' * 256)
        operator.valid?
        expect(operator.errors.full_messages).to include('名前 が長すぎです')
      end
    end

    context 'email' do
      it '空の状態だと、保存できない。' do
        operator = build(:operator, email: nil)
        operator.valid?
        expect(operator.errors.full_messages).to include('メールアドレス が空白です')
      end

      it '一意な値ではない場合、保存できない。' do
        new_operator = build(:operator, email: created_operator.email)
        new_operator.valid?
        expect(new_operator.errors.full_messages).to include('メールアドレス が重複しています')
      end

      it '@マークを含まない文字列が入力された場合、保存できない。' do
        operator = build(:operator, email: 'operatorexampl.com')
        operator.valid?
        expect(operator.errors.full_messages).to include('メールアドレス が正しくありません')
      end

      it '@マークの前に文字列が含まれなかった場合、保存できない。' do
        operator = build(:operator, email: '@exampl.com')
        operator.valid?
        expect(operator.errors.full_messages).to include('メールアドレス が正しくありません')
      end

      it '@マークの後ろに文字列が含まれなかった場合、保存できない。' do
        operator = build(:operator, email: 'operator@.com')
        operator.valid?
        expect(operator.errors.full_messages).to include('メールアドレス が正しくありません')
      end
    end

    context 'password' do
      it '空の状態だと、保存できない。' do
        operator = build(:operator, password: nil)
        operator.valid?
        expect(operator.errors.full_messages).to include('パスワード が空白です')
      end

      it '7つ以下の文字列が入力された場合、保存できない。' do
        operator = build(:operator, password: 'a' * 7, password_confirmation: 'a' * 7)
        operator.valid?
        expect(operator.errors.full_messages).to include('パスワード が短すぎです')
      end
    end

    context 'password_confirmation' do
      it '空の状態だと、保存できない。' do
        operator = build(:operator, password_confirmation: nil)
        operator.valid?
        expect(operator.errors.full_messages).to include('パスワード(確認) が空白です')
      end

      it 'passwordと一致しない場合、保存できない。' do
        operator = build(:operator, password_confirmation: 'passtext')
        operator.valid?
        expect(operator.errors.full_messages).to include('パスワード(確認) が正しくありません')
      end
    end

    context 'role' do
      it '空の状態だと、保存できない。' do
        operator = build(:operator, role: nil)
        operator.valid?
        expect(operator.errors.full_messages).to include('役割 が空白です')
      end
    end
  end
end
