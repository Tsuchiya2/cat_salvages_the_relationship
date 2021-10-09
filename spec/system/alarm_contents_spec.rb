require 'rails_helper'

RSpec.describe '[SystemTest] AlarmContents', type: :system do
  let(:operator) { create :operator }
  let(:alarm_content) { create :alarm_content }

  before do
    login(operator)
    alarm_content
  end

  context 'アラームコンテンツ一覧' do
    it 'ログイン後、ナビバーの「アラームコンテンツ」からアラームコンテンツ一覧画面に遷移する。' do
      click_on 'アラームコンテンツ'
      expect(page).to have_content('アラームコンテンツ一覧')
    end
  end

  context '新規アラームコンテンツ作成' do
    it 'アラームコンテンツ一覧から新規作成を行い、アラームコンテンツ一覧に戻っってくる。その際、新規作成したアラームコンテンツが存在する。' do
      visit operator_alarm_contents_path
      click_on '新規作成'
      fill_in 'alarm_content[body]', with: 'New_AralmContent'
      select '呼びかけ', from: 'カテゴリー'
      click_on '🐾 送信 🐾'
      expect(page).to have_content('アラームコンテンツ一覧')
      expect(page).to have_content('New_AralmContent')
    end
  end

  context 'アラームコンテンツ編集・更新' do
    it 'アラームコンテンツ一覧から編集・更新を行い、アラームコンテンツ一覧に戻ってくる。その際、更新したアラームコンテンツが存在する。' do
      visit operator_alarm_contents_path
      click_on alarm_content.body.to_s
      click_on '🐾 編集 🐾'
      fill_in 'alarm_content[body]', with: 'Update_AlarmContent'
      click_on '🐾 送信 🐾'
      expect(page).to have_content('アラームコンテンツ一覧')
      expect(page).to have_content('Update_AlarmContent')
    end
  end
end
