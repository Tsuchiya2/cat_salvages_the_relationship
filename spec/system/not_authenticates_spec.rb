require 'rails_helper'

RSpec.describe '[SystemTest] NotAuthenticates', type: :system do
  describe 'cat_inしていない状態' do
    it 'operator_operates_pathへアクセスすると、ログインページへリダイレクトする。' do
      visit operator_operates_path
      # 新しい認証システムではoperator_cat_in_pathにリダイレクトされる
      expect(page).to have_content('ReLINE')
      expect(page).not_to have_content('キャットアウト')
    end
  end
end
