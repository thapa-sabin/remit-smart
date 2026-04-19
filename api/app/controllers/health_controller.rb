class HealthController < ApplicationController
  # Shows last historical date per currency + last prediction per (currency,horizon)
  def index
    @last_rates = ExchangeRate.joins(:currency)
                   .group("currencies.iso3").maximum("exchange_rates.date")

    @last_preds = Prediction.joins(:currency)
                   .group("currencies.iso3","predictions.horizon")
                   .maximum("predictions.predicted_for")

    @max_rate_date = ExchangeRate.maximum(:date)
    @horizons      = Prediction.distinct.order(:horizon).pluck(:horizon)

    respond_to do |format|
      format.html
      format.json { render json: { last_rates: @last_rates, last_preds: @last_preds } }
    end
  end
end
