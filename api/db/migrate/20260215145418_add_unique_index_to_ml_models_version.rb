class AddUniqueIndexToMlModelsVersion < ActiveRecord::Migration[8.1]
  def change
    add_index :ml_models, :version, unique: true, name: "ml_models_version_key"
  end
end
