require 'rails_helper'

RSpec.describe '[SystemTest] Contents', type: :system do
  let(:operator)  { create :operator }
  let(:content)   { create :content }

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
      expect(page).to have_content('New_Content'.truncate(10))
    end

    it 'コンテンツ一覧から新規作成を行った際、入力に不備があると、「送信」をクリックしても入力画面が表示された状態になる。' do
      visit operator_contents_path
      click_on '新規作成'
      fill_in 'content[body]', with: nil
      select '呼びかけ', from: 'カテゴリー'
      click_on '🐾 送信 🐾'
      expect(page).to have_content('新規コンテンツ作成')
      expect(page).to have_content('入力に不備がありました。')
    end
  end

  describe 'コンテンツ編集・更新' do
    it 'コンテンツ一覧から編集・更新を行い、コンテンツ一覧に戻ってくる。その際、更新したコンテンツが存在する。' do
      visit operator_contents_path
      click_on content.body.truncate(10)
      click_on '🐾 編集 🐾'
      fill_in 'content[body]', with: 'Update_Content'
      click_on '🐾 送信 🐾'
      expect(page).to have_content('コンテンツ一覧')
      expect(page).to have_content('Update_Content'.truncate(10))
    end

    it 'コンテンツ一覧から編集・更新を行った際、入力に不備があると、「送信」をクリックしても入力画面が表示された状態になる。' do
      visit operator_contents_path
      click_on content.body.truncate(10)
      click_on '🐾 編集 🐾'
      fill_in 'content[body]', with: nil
      click_on '🐾 送信 🐾'
      expect(page).to have_content('コンテンツ編集')
      expect(page).to have_content('入力に不備がありました。')
    end
  end

  describe 'コンテンツ削除' do
    it 'コンテンツ一覧から詳細→削除を行い、コンテンツ一覧に戻ってくる。その際、削除したコンテンツは存在しない。' do
      visit operator_contents_path
      click_on content.body.truncate(10)
      click_on '- 削除 -'
      page.driver.browser.switch_to.alert.accept
      expect(page).to have_content('コンテンツ一覧')
      expect(page).not_to have_content(content.body.truncate(10))
    end
  end
end
