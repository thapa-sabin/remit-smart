class AddUniqueIndexToExchangeRates < ActiveRecord::Migration[7.1]
  def change
    add_index :exchange_rates,
              [:currency_id, :date],
              unique: true,
              name: "idx_exchange_rates_currency_date"
  end
end
