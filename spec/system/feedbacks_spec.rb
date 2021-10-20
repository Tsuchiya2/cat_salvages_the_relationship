require 'rails_helper'

RSpec.describe '[SystemTest] Feedbacks', type: :system do
  let(:feedback) { build :feedback }

  describe 'フィードバックを投稿' do
    context '正常系テスト' do
      it 'トップページからフィードバックへ遷移し、投稿が成功し、トップページに戻ってくる' do
        visit root_path
        click_on 'フィードバック'
        fill_in 'feedback[text]', with: feedback.text
        click_on '🐾 送信 🐾'
        expect(page).to have_content('フィードバックありがとうございます！')
        expect(Feedback.count).to eq 1
        expect(page).to have_current_path root_path
      end

      it '100文字の投稿を行うと、トップページに戻ってくる' do
        visit new_feedback_path
        fill_in 'feedback[text]', with: 'a' * 100
        click_on '🐾 送信 🐾'
        expect(page).to have_content('フィードバックありがとうございます！')
        expect(Feedback.count).to eq 1
        expect(page).to have_current_path root_path
      end

      it '300文字の投稿を行うと、トップページに戻ってくる' do
        visit new_feedback_path
        fill_in 'feedback[text]', with: 'a' * 300
        click_on '🐾 送信 🐾'
        expect(page).to have_content('フィードバックありがとうございます！')
        expect(Feedback.count).to eq 1
        expect(page).to have_current_path root_path
      end
    end

    context '異常系テスト' do
      it '空の投稿を行うと、フラッシュメッセージが表示される' do
        visit new_feedback_path
        click_on '🐾 送信 🐾'
        expect(page).to have_content('100〜300文字でお願いします！🐾')
        expect(Feedback.count).to eq 0
        expect(page).to have_current_path feedbacks_path
      end

      it '99文字以下の投稿を行うと、フラッシュメッセージが表示される' do
        # 301以上はtext_areaのmaxlengthオプションにより入力できない
        visit new_feedback_path
        fill_in 'feedback[text]', with: 'a' * 99
        click_on '🐾 送信 🐾'
        expect(page).to have_content('100〜300文字でお願いします！🐾')
        expect(Feedback.count).to eq 0
        expect(page).to have_current_path feedbacks_path
      end
    end
  end
end
