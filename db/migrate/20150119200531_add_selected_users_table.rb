class AddSelectedUsersTable < ActiveRecord::Migration
  def change
    create_table(:authorised_users) do |t|
      t.integer :user_id
      t.integer :authorised_user_id
    end
  end
end
