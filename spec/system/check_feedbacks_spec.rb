require 'rails_helper'

RSpec.describe '[SystemTest] CheckFeedbacks', type: :system do
  let(:operator) { create :operator }
  let(:feedback) { create :feedback }

  before do
    login(operator)
    feedback
  end

  describe 'フィードバック一覧' do
    it 'ログイン後、ナビバーの「フィードバック」からフィードバック一覧画面に遷移する。' do
      click_on 'フィードバック'
      expect(page).to have_content('フィードバック一覧')
    end
  end

  describe 'フィードバック詳細' do
    it 'フィードバック一覧から詳細ページに遷移する。' do
      visit operator_feedbacks_path
      click_on feedback.text.truncate(10)
      expect(page).to have_content(feedback.text)
    end
  end

  describe 'フィードバック削除' do
    it 'フィードバック一覧から詳細ページへ遷移し、フィードバックを削除して、フィードバック一覧画面に遷移する' do
      visit operator_feedbacks_path
      click_on feedback.text.truncate(10)
      click_on '- 削除 -'
      page.driver.browser.switch_to.alert.accept
      expect(page).to have_content('フィードバック一覧')
      expect(page).not_to have_content(feedback.text.truncate(10))
    end
  end
end
