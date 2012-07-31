class CreateBlahs < ActiveRecord::Migration
  def self.up
    create_table :blahs do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :blahs
  end
end
