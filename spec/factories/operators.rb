FactoryBot.define do
  factory :operator do
    sequence(:email) { |n| "operator#{n}@example.com" }
    sequence(:name) { |n| "Operator #{n}" }
    # Password must meet complexity requirements: lowercase, uppercase, digit
    password { 'Password123' }
    password_confirmation { 'Password123' }
    role { :operator }

    trait :guest do
      role { :guest }
    end

    trait :locked do
      failed_logins_count { 5 }
      lock_expires_at { 45.minutes.from_now }
      unlock_token { SecureRandom.urlsafe_base64(32) }
    end

    trait :unlocked do
      failed_logins_count { 0 }
      lock_expires_at { nil }
      unlock_token { nil }
    end
  end
end
