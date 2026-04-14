class AddOauthEmailAndUsernameFinalizedToUsers < ActiveRecord::Migration[8.1]
  def change
    # OAuth identities should be independent accounts even if they share the same email address.
    # We store the provider-returned email separately and keep Devise's `email` unique via a synthetic value.
    add_column :users, :oauth_email, :string

    # Track whether the user explicitly picked a username (vs a generated placeholder).
    add_column :users, :username_finalized, :boolean, null: false, default: false
    add_index :users, :username_finalized
  end
end
