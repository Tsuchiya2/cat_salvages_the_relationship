require 'rails_helper'

RSpec.describe '[SystemTest] NotAuthenticates', type: :system do
  describe 'cat_inしていない状態' do
    it 'operator_operates_pathへアクセスすると、root_pathへリダイレクトする。' do
      visit operator_operates_path
      expect(page).to have_content('利用規約')
      expect(page).not_to have_content('キャットアウト')
    end
  end
end
