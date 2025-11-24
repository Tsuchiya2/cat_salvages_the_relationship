require 'rails_helper'

RSpec.describe '[SystemTest] LineGroups', type: :system do
  let!(:operator)    { create :operator }
  let!(:line_group)  { create :line_group }

  before do
    login(operator)
  end

  describe 'LienGroupsControllersのshow, update, destroy' do
    context 'showアクション' do
      it 'indexからshowへのアクセスが成功する。' do
        line_group
        visit operator_line_groups_path
        click_link line_group.status_i18n
        expect(page).to have_content('グループ詳細')
        expect(page).to have_content(line_group.line_group_id)
      end
    end

    context 'updateアクション' do
      it 'showから編集・更新を行い、グループ一覧に戻ってくる。' do
        visit operator_line_group_path(line_group)
        click_on '🐾 編集 🐾'
        fill_in 'line_group[remind_at]', with: '2021-11-01'
        click_on '🐾 送信 🐾'
        expect(page).to have_content('LINEグループ情報の一部を更新しました。')
        expect(page).to have_content(line_group.status_i18n)
      end

      it 'showから編集・更新を行った際、入力に不備があると、「送信」をクリックしても入力画面が表示された状態になる。' do
        visit operator_line_group_path(line_group)
        click_on '🐾 編集 🐾'
        expect(page).to have_content('グループの編集', wait: 5)
        # Clear the remind_at field and submit
        field = find_field('line_group[remind_at]')
        page.execute_script('arguments[0].value = ""', field.native)
        page.execute_script('arguments[0].form.submit()', field.native)
        sleep 1
        expect(page).to have_content('グループの編集')
        expect(page).to have_content('入力に不備がありました。')
      end
    end

    context 'destroyアクション' do
      it 'showから削除を行い、グループ一覧に戻ってくる。' do
        skip 'Requires implementation of delete functionality'
        visit operator_line_group_path(line_group)
        click_button '- 削除 -'
        expect(page).to have_content('LINEグループ情報を削除しました。')
        expect(page).not_to have_content(line_group.status)
      end
    end
  end
end
