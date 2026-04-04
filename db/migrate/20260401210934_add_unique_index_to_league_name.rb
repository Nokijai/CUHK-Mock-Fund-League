class AddUniqueIndexToLeagueName < ActiveRecord::Migration[8.1]
  def up
    # Find and rename duplicate league names
    duplicates = League.select(:name).group(:name).having("count(*) > 1").pluck(:name)

    duplicates.each do |name|
      leagues = League.where(name: name).order(:created_at)
      leagues.each_with_index do |league, index|
        if index > 0
          league.update_column(:name, "#{name} (#{index + 1})")
        end
      end
    end

    # Now add the unique index
    add_index :leagues, :name, unique: true
  end

  def down
    remove_index :leagues, :name
  end
end
