FactoryGirl.define do
  factory :notification do
    message { Faker::Lorem.sentence(10) }
    sequence :user_id do |n|
      n
    end

  end
end

# == Schema Information
#
# Table name: notifications
#
#  created_at  :datetime
#  id          :integer          not null, primary key
#  initiator   :integer
#  link        :string(255)
#  message     :string(255)
#  object_id   :integer
#  object_type :string
#  updated_at  :datetime
#  user_id     :integer
#  viewed      :boolean          default(FALSE)
#
