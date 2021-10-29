require 'rails_helper'

RSpec.describe '[SystemTest] OperatorSessions', type: :system do
  let(:guest) { create :operator, :guest }

  describe 'session関係' do
    it 'キャットインを行い、operator_operates_pathにリダイレクトされる。' do
      visit operator_cat_in_path
      fill_in 'email', with: guest.email
      fill_in 'password', with: 'password'
      click_button '🐾 キャットイン 🐾'
      expect(page).to have_content("Let's bring warmth to the world!!")
    end

    it 'キャットインを行う際、入力に不備があると、「🐾 キャットイン 🐾」をクリックしても入力画面が表示された状態になる。' do
      visit operator_cat_in_path
      fill_in 'email', with: guest.email
      fill_in 'password', with: 'helloworld'
      click_button '🐾 キャットイン 🐾'
      expect(page).not_to have_content("Let's bring warmth to the world!!")
      expect(page).to have_content('メールアドレス')
    end

    it 'キャットアウトを行い、operator_cat_in_pathにリダイレクトされる。' do
      visit operator_cat_in_path
      fill_in 'email', with: guest.email
      fill_in 'password', with: 'password'
      click_button '🐾 キャットイン 🐾'
      expect(page).to have_content("Let's bring warmth to the world!!")
      click_link 'キャットアウト'
      expect(page).to have_content('キャットアウトしました。')
      expect(page).to have_content('メールアドレス')
    end
  end
end
