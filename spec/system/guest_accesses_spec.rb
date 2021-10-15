require 'rails_helper'

RSpec.describe '[SystemTest] GuestAccesses', type: :system do
  let(:guest) { create :operator, :guest }
  let(:content) { create :content }
  let(:alarm_content) { create :alarm_content }

  before do
    driven_by(:rack_test)
    login(guest)
  end

  describe 'Content関連へのアクセス' do
    before do
      content
    end

    context 'indexアクション' do
      it 'ゲストログイン後、indexへのアクセスが成功して、Content一覧とContentの中身が表示される' do
        visit operator_contents_path
        expect(page).to have_content('コンテンツ一覧')
        expect(page).to have_content(content.body)
      end

      it 'ゲストログイン後、indexへのアクセスが成功するが、Contentの詳細(show)へのリンクは表示されない' do
        visit operator_contents_path
        expect(page).not_to have_link(content.body)
      end

      it 'ゲストログイン後、indexへのアクセスが成功するが、新規作成(new)へのリンクは表示されない' do
        visit operator_contents_path
        expect(page).not_to have_link('新規作成')
      end
    end

    context 'showアクション' do
      it 'アクセスに失敗して、403ページが表示される' do
        visit operator_content_path(content)
        expect(page).to have_http_status(403)
        expect(page).not_to have_content(content.body)
      end
    end

    context 'newアクション' do
      it 'アクセスに失敗して、403ページが表示される' do
        visit new_operator_content_path
        expect(page).to have_http_status(403)
        expect(page).not_to have_content('新規コンテンツ作成')
      end
    end

    context 'editアクション' do
      it 'アクセスに失敗して、403ページが表示される' do
        visit edit_operator_content_path(content)
        expect(page).to have_http_status(403)
        expect(page).not_to have_content('コンテンツ編集')
      end
    end
  end

  describe 'AlarmContent関連へのアクセス' do
    before do
      alarm_content
    end

    context 'indexアクション' do
      it 'ゲストログイン後、indexへのアクセスが成功して、AlarmContent一覧とAlarmContentの中身が表示される' do
        visit operator_alarm_contents_path
        expect(page).to have_content('アラームコンテンツ一覧')
        expect(page).to have_content(alarm_content.body)
      end

      it 'ゲストログイン後、indexへのアクセスは成功するが、AlarmContentの詳細(show)へのリンクは表示されない' do
        visit operator_alarm_contents_path
        expect(page).not_to have_link(alarm_content.body)
      end

      it 'ゲストログイン後、indexへのアクセスは成功するが、新規作成(new)へのリンクは表示されない' do
        visit operator_alarm_contents_path
        expect(page).not_to have_link('新規作成')
      end
    end

    context 'showアクション' do
      it 'アクセスに失敗して、403ページが表示される' do
        visit operator_alarm_content_path(alarm_content)
        expect(page).to have_http_status(403)
        expect(page).not_to have_content(alarm_content.body)
      end
    end

    context 'newアクション' do
      it 'アクセスに失敗して、403ページが表示される' do
        visit new_operator_alarm_content_path
        expect(page).to have_http_status(403)
        expect(page).not_to have_content('新規アラームコンテンツ作成')
      end
    end

    context 'editアクション' do
      it 'アクセスに失敗して、403ページが表示される' do
        visit edit_operator_alarm_content_path(alarm_content)
        expect(page).to have_http_status(403)
        expect(page).not_to have_content('アラームコンテンツ編集')
      end
    end
  end
end
