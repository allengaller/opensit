class RemoveAuthorisedUsersAttributeFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :authorised_users
  end
end
