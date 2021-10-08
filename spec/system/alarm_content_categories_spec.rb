require 'rails_helper'

RSpec.describe '[SystemTest] AlarmContentCategories', type: :system do
  let(:operator) { create :operator }
  let(:alarm_content_category) { create :alarm_content_category }

  before do
    login(operator)
    alarm_content_category
  end

  context 'アラームカテゴリー一覧' do
    it 'ログイン後、ナビバーの「アラームカテゴリー」からアラームカテゴリー一覧画面に遷移する。' do
      click_on 'アラームカテゴリー'
      expect(page).to have_content('アラームカテゴリー一覧')
    end
  end

  context '新規アラームカテゴリー作成' do
    it 'アラームカテゴリー一覧から新規作成を行い、アラームカテゴリー一覧に戻ってくる。その際、新規作成したアラームカテゴリーが存在する。' do
      visit operator_alarm_content_categories_path
      click_on '新規作成'
      fill_in 'alarm_content_category[name]', with: 'New_Alarm_Category'
      click_on '🐾 送信 🐾'
      expect(page).to have_content('アラームカテゴリー一覧')
      expect(page).to have_content('New_Alarm_Category')
    end
  end

  context 'アラームカテゴリー編集・更新' do
    it 'アラームカテゴリー一覧から編集・更新を行い、アラームカテゴリー一覧に戻ってくる。その際、更新しアラームカテゴリーが存在する。' do
      visit operator_alarm_content_categories_path
      click_on alarm_content_category.name.to_s
      click_on '🐾 編集 🐾'
      fill_in 'alarm_content_category[name]', with: 'Update_Alarm_Category'
      click_on '🐾 送信 🐾'
      expect(page).to have_content('アラームカテゴリー一覧')
      expect(page).to have_content('Update_Alarm_Category')
    end
  end
end
