require 'rails_helper'

RSpec.describe '[SystemTest] ContentCategories', type: :system do
  let(:operator) { create :operator }
  let(:content_category) { create :content_category }

  before do
    login(operator)
  end

  context 'カテゴリー一覧' do
    it 'ログイン後、ナビバーの「カテゴリー」からカテゴリー一覧画面に遷移する' do
      click_on 'カテゴリー'
      expect(page).to have_content('カテゴリー一覧')
    end
  end

  context '新規カテゴリー作成' do
    it 'カテゴリー一覧から新規作成を行い、カテゴリー一覧に戻ってくる' do
      visit operator_content_categories_path
      click_on '新規作成'
      fill_in 'content_category[name]', with: 'New_Category'
      click_on '🐾 送信 🐾'
      expect(page).to have_content('New_Category')
    end
  end

  context 'カテゴリー編集・更新' do
    it 'カテゴリー一覧から編集・更新を行い、カテゴリー一覧に戻ってくる' do
      content_category
      visit operator_content_categories_path
      click_on 'Category'
      click_on '🐾 編集 🐾'
      fill_in 'content_category[name]', with: 'Update_Category'
      click_on '🐾 送信 🐾'
      expect(page).to have_content('カテゴリー一覧')
      expect(page).to have_content('Update_Category')
    end
  end
end
