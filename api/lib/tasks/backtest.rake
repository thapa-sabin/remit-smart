# api/lib/tasks/backtest.rake
namespace :ml do
  # Predict PREDICT_DATE using history up to PREDICT_DATE-1 without retraining
  # ENV:
  #   PREDICT_DATE=YYYY-MM-DD  (default: latest ExchangeRate date)
  #   ISO3=USD,EUR             (default: all currencies)
  #   TARGETS=mid,buy,sell     (default: mid)
  #   H=1                      (default: 1)
  #   WINDOW=60                (default: 60)
  #   WRITE=1                  (optional) write a backtest row into predictions
  desc "Backtest today's prediction using history up to yesterday (no retrain)."
  task :predict_today => :environment do
    require "httparty"

    targets = (ENV["TARGETS"] || "mid").split(",").map(&:strip)
    h       = (ENV["H"] || "1").to_i
    window  = (ENV["WINDOW"] || "60").to_i
    ml_url  = ENV.fetch("ML_BASE_URL", "http://ml:8000")
    write   = ENV["WRITE"] == "1"

    default_predict_date = ExchangeRate.maximum(:date)
    unless default_predict_date
      puts "[Backtest] No exchange_rates found. Ingest first."
      next
    end

    predict_date = (ENV["PREDICT_DATE"] || default_predict_date.to_s)
    begin
      predict_date = Date.parse(predict_date)
    rescue
      puts "[Backtest] Invalid PREDICT_DATE format. Use YYYY-MM-DD."
      next
    end
    as_of = predict_date - 1

    iso3_list =
      if ENV["ISO3"]
        ENV["ISO3"].split(",").map(&:strip)
      else
        Currency.order(:iso3).pluck(:iso3)
      end

    puts "[Backtest] predict_date=#{predict_date}, as_of=#{as_of}, targets=#{targets.join(",")}, h=#{h}, window=#{window}"
    puts "[Backtest] ISO3 set: #{iso3_list.join(", ")}"

    iso3_list.each do |iso3|
      targets.each do |target|
        # history up to as_of
        series = ExchangeRate.joins(:currency)
                             .where(currencies: { iso3: iso3 })
                             .where("exchange_rates.date <= ?", as_of)
                             .order(:date)
                             .pluck(target)

        recent = series.last(window)
        if recent.nil? || recent.size < window
          puts "[Backtest] SKIP #{iso3} #{target}: need at least window=#{window} values up to #{as_of}."
          next
        end

        actual = ExchangeRate.joins(:currency)
                             .where(currencies: { iso3: iso3 }, date: predict_date)
                             .pick(target)
        if actual.nil?
          puts "[Backtest] SKIP #{iso3} #{target}: no actual #{target} on #{predict_date}."
          next
        end

        resp = HTTParty.post(
          "#{ml_url}/predict",
          body: {
            currency: iso3, target: target, horizon: h, window: window,
            recent_values: recent
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

        unless resp.success?
          puts "[Backtest] ERROR #{iso3} #{target}: ML #{resp.code} #{resp.body}"
          next
        end

        yhat = Array(resp.parsed_response["yhat"]).first
        if yhat.nil?
          puts "[Backtest] ERROR #{iso3} #{target}: empty yhat."
          next
        end

        err_abs = (yhat.to_f - actual.to_f).abs
        err_pct = actual.to_f.zero? ? nil : (err_abs / actual.to_f * 100.0)

        puts "[Backtest] #{iso3} #{target} | as_of=#{as_of} -> #{predict_date} | "\
             "actual=#{format('%.6f', actual)} pred=#{format('%.6f', yhat)} | "\
             "abs=#{format('%.6f', err_abs)}#{err_pct ? " mape=#{format('%.2f', err_pct)}%" : ""}"

        # optional write
        if write
          tag     = "#{iso3.downcase}_#{target}_h#{h}"
          version = "backtest-#{tag}-#{as_of}"

          Prediction.upsert(
            {
              currency_id: Currency.find_by!(iso3: iso3).id,
              target: target, horizon: h,
              prediction_date: Date.today,
              predicted_for: predict_date,
              yhat: BigDecimal(yhat.to_s),
              model_version: version,
              created_at: Time.current, updated_at: Time.current
            },
            unique_by: "idx_pred_unique"
          )
        end
      end
    end
  end
end
