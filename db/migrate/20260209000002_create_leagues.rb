class CreateLeagues < ActiveRecord::Migration[8.0]
  def change
    create_table :leagues do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :starting_capital, precision: 15, scale: 2, default: 0
      t.date :start_date
      t.date :end_date
      t.jsonb :rules, default: {}

      t.timestamps
    end
  end
end
