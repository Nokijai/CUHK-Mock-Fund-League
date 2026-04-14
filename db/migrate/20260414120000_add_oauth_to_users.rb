class AddOauthToUsers < ActiveRecord::Migration[8.1]
  def change
    # OAuth accounts are identified by (provider, uid). We also store a display name
    # for nicer UI, but treat it as optional.
    add_column :users, :oauth_provider, :string
    add_column :users, :oauth_uid, :string
    add_column :users, :oauth_name, :string

    add_index :users, [ :oauth_provider, :oauth_uid ], unique: true
  end
end
