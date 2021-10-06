FactoryBot.define do
  factory :operator do
    name { 'operator' }
    email { 'operator@exampl.com' }
    password { 'password' }
    password_confirmation { 'password' }
    role { :operator }

    trait :guest do
      name { 'guest' }
      email { 'guest@example.com' }
      password { 'password' }
      password_confirmation { 'password' }
      role { :guest }
    end
  end
end
