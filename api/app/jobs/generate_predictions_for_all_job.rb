class GeneratePredictionsForAllJob < ApplicationJob
  queue_as :default

  DEFAULT_TARGETS  = %w[mid]
  DEFAULT_HORIZONS = [1,7,14]
  DEFAULT_WINDOW   = 60

  def perform(targets: DEFAULT_TARGETS, horizons: DEFAULT_HORIZONS, window: DEFAULT_WINDOW)
    Currency.order(:iso3).pluck(:iso3).each do |iso3|
      last_hist_date = ExchangeRate.joins(:currency).where(currencies: { iso3: iso3 }).maximum(:date)
      next unless last_hist_date

      targets.each do |target|
        horizons.each do |h|
          begin
            res  = MlPredictor.predict(currency: iso3, target:, horizon: h, window:)
            meta = MlPredictor.model_meta(currency: iso3, target:, horizon: h) rescue {}
            trained_until = meta['trained_until'] || last_hist_date.to_s
            tag           = "#{iso3.downcase}_#{target}_h#{h}"
            version = "lstm-pytorch-#{tag}-#{trained_until}"
            res["yhat"].each_with_index do |y, i|
              Prediction.upsert(
                {
                  currency_id: Currency.find_by!(iso3: iso3).id,
                  target: target, horizon: h,
                  prediction_date: Date.current,
                  predicted_for: last_hist_date + (i + 1),
                  yhat: BigDecimal(y.to_s),
                  model_version: version,
                  created_at: Time.current, updated_at: Time.current
                },
                unique_by: "idx_pred_unique"
              )
            end
          rescue => e
            Rails.logger.error "[PredictAll] #{iso3} #{target} h#{h}: #{e.message}"
          end
        end
      end
    end
  end
end
