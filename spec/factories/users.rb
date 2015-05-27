FactoryGirl.define do
  factory :user do
    sequence :username do |n|
      "#{Faker::Name.first_name}#{n}"
    end
    email { Faker::Internet.email }
    password { Faker::Lorem.characters(12) }

    factory :buddha do
      username "buddha"
    end

    factory :ananda do
      username "ananda"
    end

    trait :private_journal do
      privacy_setting 'private'
    end

    trait :has_first_name do
      first_name { Faker::Name.first_name }
    end

    trait :no_first_name do
      first_name nil
    end

    trait :has_last_name do
      last_name { Faker::Name.last_name }
    end

    trait :no_last_name do
      last_name nil
    end
  end
end