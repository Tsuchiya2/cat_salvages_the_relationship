# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailValidator, type: :validator do
  # Test model for validator integration testing
  class TestModel
    include ActiveModel::Validations

    attr_accessor :email

    validates :email, email: true

    def initialize(email = nil)
      @email = email
    end
  end

  describe 'ActiveModel統合テスト' do
    context '正常系テスト' do
      it '有効なメールアドレスの場合、バリデーションを通過する。' do
        model = TestModel.new('user@example.com')
        expect(model).to be_valid
      end

      it '数字を含むメールアドレスの場合、バリデーションを通過する。' do
        model = TestModel.new('user123@example456.com')
        expect(model).to be_valid
      end

      it 'アンダースコアを含むメールアドレスの場合、バリデーションを通過する。' do
        model = TestModel.new('user_name@example.com')
        expect(model).to be_valid
      end

      it 'ハイフンを含むメールアドレスの場合、バリデーションを通過する。' do
        model = TestModel.new('user-name@example.com')
        expect(model).to be_valid
      end

      it '空白の場合、バリデーションを通過する。（presence: trueと併用を想定）' do
        model = TestModel.new('')
        expect(model).to be_valid
      end

      it 'nilの場合、バリデーションを通過する。（presence: trueと併用を想定）' do
        model = TestModel.new(nil)
        expect(model).to be_valid
      end
    end

    context '異常系テスト' do
      it '@マークがない場合、バリデーションエラーになる。' do
        model = TestModel.new('userexample.com')
        expect(model).not_to be_valid
        expect(model.errors[:email]).to be_present
      end

      it '@マークの前が空の場合、バリデーションエラーになる。' do
        model = TestModel.new('@example.com')
        expect(model).not_to be_valid
        expect(model.errors[:email]).to be_present
      end

      it '@マークの後ろが空の場合、バリデーションエラーになる。' do
        model = TestModel.new('user@')
        expect(model).not_to be_valid
        expect(model.errors[:email]).to be_present
      end

      it 'ドメイン部分にドットがない場合、バリデーションエラーになる。' do
        model = TestModel.new('user@example')
        expect(model).not_to be_valid
        expect(model.errors[:email]).to be_present
      end

      it 'ドメインのドット後が空の場合、バリデーションエラーになる。' do
        model = TestModel.new('user@example.')
        expect(model).not_to be_valid
        expect(model.errors[:email]).to be_present
      end

      it '大文字を含む場合、バリデーションエラーになる。' do
        model = TestModel.new('USER@EXAMPLE.COM')
        expect(model).not_to be_valid
        expect(model.errors[:email]).to be_present
      end

      it 'スペースを含む場合、バリデーションエラーになる。' do
        model = TestModel.new('user @example.com')
        expect(model).not_to be_valid
        expect(model.errors[:email]).to be_present
      end

      it '特殊文字を含む場合、バリデーションエラーになる。' do
        model = TestModel.new('user+tag@example.com')
        expect(model).not_to be_valid
        expect(model.errors[:email]).to be_present
      end
    end
  end

  describe '.valid_format?' do
    context '正常系テスト' do
      it '有効なメールアドレスの場合、trueを返す。' do
        expect(described_class.valid_format?('user@example.com')).to be true
      end

      it '数字を含むメールアドレスの場合、trueを返す。' do
        expect(described_class.valid_format?('user123@example456.com')).to be true
      end

      it 'アンダースコアを含むメールアドレスの場合、trueを返す。' do
        expect(described_class.valid_format?('user_name@example.com')).to be true
      end

      it 'ハイフンを含むメールアドレスの場合、trueを返す。' do
        expect(described_class.valid_format?('user-name@example.com')).to be true
      end

      it 'ドメインとTLDの組み合わせの場合、trueを返す。' do
        expect(described_class.valid_format?('user@example.com')).to be true
      end
    end

    context '異常系テスト' do
      it '空白の場合、falseを返す。' do
        expect(described_class.valid_format?('')).to be false
      end

      it 'nilの場合、falseを返す。' do
        expect(described_class.valid_format?(nil)).to be false
      end

      it '@マークがない場合、falseを返す。' do
        expect(described_class.valid_format?('userexample.com')).to be false
      end

      it '@マークの前が空の場合、falseを返す。' do
        expect(described_class.valid_format?('@example.com')).to be false
      end

      it '@マークの後ろが空の場合、falseを返す。' do
        expect(described_class.valid_format?('user@')).to be false
      end

      it 'ドメイン部分にドットがない場合、falseを返す。' do
        expect(described_class.valid_format?('user@example')).to be false
      end

      it '大文字を含む場合、falseを返す。' do
        expect(described_class.valid_format?('USER@EXAMPLE.COM')).to be false
      end

      it 'スペースを含む場合、falseを返す。' do
        expect(described_class.valid_format?('user @example.com')).to be false
      end
    end

    context 'カスタムフォーマット' do
      it 'カスタム正規表現を使用できる。' do
        custom_format = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
        expect(described_class.valid_format?('USER+tag@EXAMPLE.COM', custom_format)).to be true
      end

      it 'カスタム正規表現で無効な場合、falseを返す。' do
        custom_format = /\A[a-z]+@[a-z]+\.[a-z]+\z/
        expect(described_class.valid_format?('user123@example.com', custom_format)).to be false
      end
    end
  end

  describe '.normalize' do
    context '正常系テスト' do
      it '大文字を小文字に変換する。' do
        expect(described_class.normalize('USER@EXAMPLE.COM')).to eq('user@example.com')
      end

      it '前後の空白を削除する。' do
        expect(described_class.normalize('  user@example.com  ')).to eq('user@example.com')
      end

      it '大文字と空白の両方を処理する。' do
        expect(described_class.normalize('  USER@EXAMPLE.COM  ')).to eq('user@example.com')
      end

      it '既に正規化されたメールアドレスはそのまま返す。' do
        expect(described_class.normalize('user@example.com')).to eq('user@example.com')
      end
    end

    context 'エッジケース' do
      it 'nilの場合、空文字列を返す。' do
        expect(described_class.normalize(nil)).to eq('')
      end

      it '空白文字のみの場合、空文字列を返す。' do
        expect(described_class.normalize('   ')).to eq('')
      end

      it '空文字列の場合、空文字列を返す。' do
        expect(described_class.normalize('')).to eq('')
      end

      it 'シンボルを渡した場合、文字列に変換して処理する。' do
        expect(described_class.normalize(:'USER@EXAMPLE.COM')).to eq('user@example.com')
      end
    end
  end

  describe '.sanitize' do
    context '正常系テスト' do
      it '有効なメールアドレスを正規化して返す。' do
        expect(described_class.sanitize('USER@EXAMPLE.COM')).to eq('user@example.com')
      end

      it '前後の空白を削除して正規化する。' do
        expect(described_class.sanitize('  user@example.com  ')).to eq('user@example.com')
      end

      it '大文字と空白を処理して正規化する。' do
        expect(described_class.sanitize('  USER@EXAMPLE.COM  ')).to eq('user@example.com')
      end

      it '数字を含むメールアドレスを正規化して返す。' do
        expect(described_class.sanitize('USER123@EXAMPLE456.COM')).to eq('user123@example456.com')
      end
    end

    context '異常系テスト' do
      it '無効なメールアドレスの場合、nilを返す。' do
        expect(described_class.sanitize('invalid@')).to be_nil
      end

      it '@マークがない場合、nilを返す。' do
        expect(described_class.sanitize('userexample.com')).to be_nil
      end

      it 'ドメインにドットがない場合、nilを返す。' do
        expect(described_class.sanitize('user@example')).to be_nil
      end

      it '正規化後に無効になる場合、nilを返す。' do
        # 正規化前は有効に見えても、正規化後に無効なパターン
        expect(described_class.sanitize('INVALID@')).to be_nil
      end
    end

    context 'エッジケース' do
      it 'nilの場合、nilを返す。' do
        expect(described_class.sanitize(nil)).to be_nil
      end

      it '空白文字のみの場合、nilを返す。' do
        expect(described_class.sanitize('   ')).to be_nil
      end

      it '空文字列の場合、nilを返す。' do
        expect(described_class.sanitize('')).to be_nil
      end
    end

    context 'カスタムフォーマット' do
      it 'カスタム正規表現で有効な場合、正規化して返す。' do
        custom_format = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
        result = described_class.sanitize('USER+TAG@EXAMPLE.COM', custom_format)
        expect(result).to eq('user+tag@example.com')
      end

      it 'カスタム正規表現で無効な場合、nilを返す。' do
        custom_format = /\A[a-z]+@[a-z]+\.[a-z]+\z/
        expect(described_class.sanitize('user123@example.com', custom_format)).to be_nil
      end
    end
  end
end
