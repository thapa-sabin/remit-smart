class CreateExchangeRates < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_rates do |t|
      t.references :currency, null: false, foreign_key: true
      t.date :date
      t.datetime :published_on
      t.datetime :modified_on
      t.decimal :buy_raw, precision: 18, scale: 6
      t.decimal :sell_raw, precision: 18, scale: 6
      t.decimal :buy, precision: 18, scale: 6
      t.decimal :sell, precision: 18, scale: 6
      t.decimal :mid, precision: 18, scale: 6
      t.string :source

      t.timestamps
    end
  end
end
