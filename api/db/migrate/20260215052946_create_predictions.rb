class CreatePredictions < ActiveRecord::Migration[8.1]
  def change
    create_table :predictions do |t|
      t.references :currency, null: false, foreign_key: true
      t.string :model_version
      t.string :target
      t.integer :horizon
      t.date :prediction_date
      t.date :predicted_for
      t.decimal :yhat, precision: 18, scale: 6
      t.decimal :yhat_lower, precision: 18, scale: 6
      t.decimal :yhat_upper, precision: 18, scale: 6

      t.timestamps
    end
  end
end
