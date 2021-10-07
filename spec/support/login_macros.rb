module LoginMacros
  def login(operator)
    visit operator_cat_in_path
    fill_in 'email', with: operator.email
    fill_in 'password', with: 'password'
    click_button '🐾 キャットイン 🐾'
  end
end
