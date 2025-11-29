module LoginMacros
  def login(operator)
    visit operator_cat_in_path
    fill_in 'email', with: operator.email
    fill_in 'password', with: 'Password123'
    click_button '🐾 キャットイン 🐾'
    # Wait for redirect to complete
    expect(page).to have_current_path(operator_operates_path)
  end
end

RSpec.configure do |config|
  config.include LoginMacros, type: :system
end
