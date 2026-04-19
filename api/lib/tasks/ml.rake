# api/lib/tasks/ml.rake
namespace :ml do
  desc "Train LSTM for all currencies. ENV: TARGETS='mid', HORIZONS='1,7,14', WINDOW='60'"
  task :train_all => :environment do
    targets  = ENV.fetch("TARGETS", "mid").split(",").map(&:strip)
    horizons = ENV.fetch("HORIZONS", "1,7,14").split(",").map(&:to_i)
    window   = ENV.fetch("WINDOW", "60").to_i

    require Rails.root.join("app/jobs/train_all_currencies_job")
    TrainAllCurrenciesJob.perform_now(targets: targets, horizons: horizons, window: window)
    puts "TrainAll finished."
  end

  desc "Generate predictions for all currencies. ENV: TARGETS='mid', HORIZONS='1,7,14', WINDOW='60'"
  task :predict_all => :environment do
    targets  = ENV.fetch("TARGETS", "mid").split(",").map(&:strip)
    horizons = ENV.fetch("HORIZONS", "1,7,14").split(",").map(&:to_i)
    window   = ENV.fetch("WINDOW", "60").to_i

    require Rails.root.join("app/jobs/generate_predictions_for_all_job")
    GeneratePredictionsForAllJob.perform_now(targets: targets, horizons: horizons, window: window)
    puts "PredictAll finished."
  end
end
