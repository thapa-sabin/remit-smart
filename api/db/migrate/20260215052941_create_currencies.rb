class CreateCurrencies < ActiveRecord::Migration[8.1]
  def change
    create_table :currencies do |t|
      t.string :iso3
      t.string :name
      t.integer :unit

      t.timestamps
    end
    add_index :currencies, :iso3, unique: true
  end
end
