class CreateMlModels < ActiveRecord::Migration[8.1]
  def change
    create_table :ml_models do |t|
      t.string :version
      t.string :framework
      t.string :artifact_path
      t.string :scaler_path
      t.date :trained_until
      t.integer :window_size
      t.integer :horizons
      t.jsonb :metrics

      t.timestamps
    end
  end
end
