require 'rails_helper'

RSpec.describe Operator, type: :model do
  let(:operator) { create(:operator) }

  describe '正常系テスト' do
    context 'name' do
      it '2つ以上の文字列が入力された場合、保存できる。' do
      end

      it '255以下の文字列が入力された場合、保存できる。' do
      end
    end

    context 'email' do
      it '@マークを含む文字列が入力された場合、保存できる。' do
      end
    end

    context 'password' do
      it '8つ以上の文字列が入力された場合、保存できる。' do
      end
    end

    context 'role' do
      it '0以上の値が入力された場合、保存できる。' do
      end

      it '1以下の値が入力された場合、保存できる。' do
      end
    end
  end

  describe '異常系テスト' do
    context 'name' do
      it '空の状態だと、保存できない。' do
      end

      it '1以下の文字列が入力された場合、保存できない。' do
      end

      it '256以上の文字列が入力された場合、保存できない。' do
      end
    end

    context 'email' do
      it '空の状態だと、保存できない。' do
      end

      it '@マークを含まない文字列が入力された場合、保存できない。' do
      end

      it '@マークの前に文字列が含まれなかった場合、保存できない。' do
      end

      it '@マークの後ろに文字列が含まれなかった場合、保存できない。' do
      end
    end

    context 'password' do
      it '空の状態だと、保存できない。' do
      end

      it '7つ以下の文字列が入力された場合、保存できない。' do
      end
    end

    context 'password_confirmation' do
      it '空の状態だと、保存できない。' do
      end

      it 'passwordと一致しない場合、保存できない。' do
      end
    end

    context 'role' do
      it '空の状態だと、保存できない。' do
      end

      it '2以上の値が入力された場合、保尊できない。' do
      end
    end
  end
end
