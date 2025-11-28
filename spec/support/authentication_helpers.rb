module AuthenticationHelpers
  # For request specs - simulate login by posting to login endpoint
  def login_as(operator)
    post operator_cat_in_path, params: { email: operator.email, password: 'Password123' }
  end

  # For request specs - simulate logout
  def logout
    delete operator_cat_out_path
  end

  # For request specs - set session directly (alternative to login_as)
  def sign_in_operator(operator)
    # Set session directly for request specs
    allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return({ operator_id: operator.id })
  end

  # For system specs - full browser login flow
  def system_login(operator)
    visit operator_cat_in_path
    fill_in 'email', with: operator.email
    fill_in 'password', with: 'Password123'
    click_button '🐾 キャットイン 🐾'
    # Wait for redirect to complete
    expect(page).to have_current_path(operator_operates_path)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
  config.include AuthenticationHelpers, type: :system
end
