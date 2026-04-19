class AddUniqueIndexToPredictions < ActiveRecord::Migration[7.1]
  def change
    add_index :predictions,
              [:currency_id, :target, :horizon, :predicted_for, :model_version],
              unique: true,
              name: "idx_pred_unique"
  end
end
