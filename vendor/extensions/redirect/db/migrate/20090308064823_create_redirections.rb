class CreateRedirections < ActiveRecord::Migration
  def self.up
    create_table :redirections do |t|
      t.string :from_path
      t.string :to_path
      t.boolean :temporary
    end
    add_index :redirections, :from_path, :unique => true
  end

  def self.down
    drop_table :redirections
  end
end
