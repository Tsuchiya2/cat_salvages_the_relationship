require 'rails_helper'

RSpec.describe '[SystemTest] Contents', type: :system do
  let(:operator) { create :operator }
  let(:content) { create :content }

  before do
    login(operator)
    content
  end

  describe 'コンテンツ一覧' do
    it 'ログイン後、ナビバーの「コンテンツ」からコンテンツ一覧画面に遷移する。' do
      click_on 'コンテンツ'
      expect(page).to have_content('コンテンツ一覧')
    end
  end

  describe '新規コンテンツ作成' do
    it 'コンテンツ一覧から新規作成を行い、コンテンツ一覧に戻っってくる。その際、新規作成したコンテンツが存在する。' do
      visit operator_contents_path
      click_on '新規作成'
      fill_in 'content[body]', with: 'New_Content'
      select '呼びかけ', from: 'カテゴリー'
      click_on '🐾 送信 🐾'
      expect(page).to have_content('コンテンツ一覧')
      expect(page).to have_content('New_Content')
    end
  end

  describe 'コンテンツ編集・更新' do
    it 'コンテンツ一覧から編集・更新を行い、コンテンツ一覧に戻ってくる。その際、更新したコンテンツが存在する。' do
      visit operator_contents_path
      click_on content.body.to_s
      click_on '🐾 編集 🐾'
      fill_in 'content[body]', with: 'Update_Content'
      click_on '🐾 送信 🐾'
      expect(page).to have_content('コンテンツ一覧')
      expect(page).to have_content('Update_Content')
    end
  end
end
