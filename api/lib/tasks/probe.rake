# api/lib/tasks/probe.rake
namespace :ml do
  desc "Probe write-path. ENV: ISO3=USD TARGET=mid H=7 WINDOW=60"
  task :probe_predict => :environment do
    iso3   = ENV.fetch("ISO3", "USD")
    target = ENV.fetch("TARGET", "mid")
    h      = ENV.fetch("H", "7").to_i
    window = ENV.fetch("WINDOW", "60").to_i

    # No manual require here—zeitwerk should autoload app/services/ml_predictor.rb
    # require Rails.root.join("app/services/ml_predictor")  # <-- remove this line

    last_hist_date = ExchangeRate.joins(:currency)
                     .where(currencies: { iso3: iso3 }).maximum(:date)
    if last_hist_date.nil?
      puts "[Probe] No history for #{iso3}. Run backfill first."
      next
    end
    puts "[Probe] last_hist_date(#{iso3})=#{last_hist_date}"

    resp = MlPredictor.predict(currency: iso3, target: target, horizon: h, window: window)
    yhat = Array(resp["yhat"])
    puts "[Probe] yhat length=#{yhat.length}"

    meta           = MlPredictor.model_meta(currency: iso3, target: target, horizon: h) rescue {}
    trained_until  = meta["trained_until"] || last_hist_date.to_s
    tag            = "#{iso3.downcase}_#{target}_h#{h}"
    version        = "lstm-pytorch-#{tag}-#{trained_until}"

    count_before = Prediction.count
    yhat.each_with_index do |y, i|
      Prediction.upsert(
        {
          currency_id: Currency.find_by!(iso3: iso3).id,
          target: target, horizon: h,
          prediction_date: Date.today,
          predicted_for: last_hist_date + (i + 1),
          yhat: BigDecimal(y.to_s),
          model_version: version,
          created_at: Time.current, updated_at: Time.current
        },
        unique_by: "idx_pred_unique"
      )
    end

    inserted = Prediction.count - count_before
    puts "[Probe] Inserted #{inserted} rows for #{iso3}."
  end
end
