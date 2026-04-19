# app/jobs/train_all_currencies_job.rb
class TrainAllCurrenciesJob < ApplicationJob
  queue_as :default

  DEFAULT_TARGETS  = %w[mid]      # add "buy","sell" later if needed
  DEFAULT_HORIZONS = [1, 7, 14]
  DEFAULT_WINDOW   = 60

  def perform(targets: DEFAULT_TARGETS, horizons: DEFAULT_HORIZONS, window: DEFAULT_WINDOW)
    Currency.order(:iso3).pluck(:iso3).each do |iso3|
      targets.each do |target|
        series = ExchangeRate
                   .joins(:currency)
                   .where(currencies: { iso3: iso3 })
                   .order(:date)
                   .pluck(:date, target)

        dates  = series.map { |d, _| d.to_s }
        values = series.map { |_, v| v.to_f }.compact

        horizons.each do |h|
          next if values.size < (window + h)

          res = MlTrainer.train(
            currency: iso3,
            target:   target,
            horizon:  h,
            window:   window,
            values:   values,
            dates:    dates
          )

          trained_until = res['trained_until']   # e.g., "2026-02-14"
          tag           = res['tag']             # e.g., "usd_mid_h7"
          version       = "lstm-pytorch-#{tag}-#{trained_until}"

          MlModel.upsert(
            {
              version:       version,
              framework:     "pytorch",
              artifact_path: "/models/#{tag}.pt",
              scaler_path:   "/models/#{tag}_scaler.pkl",
              trained_until: trained_until.present? ? Date.parse(trained_until) : nil,
              window_size:   window,
              horizons:      [h],
              metrics:       {},
              created_at:    Time.current,
              updated_at:    Time.current
            },
            unique_by: :ml_models_version_key   # ← uses the index you just added
          )
        end
      end
    end
  end
end
