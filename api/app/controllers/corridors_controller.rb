# app/controllers/corridors_controller.rb
class CorridorsController < ApplicationController
  def show
    @from   = (params[:from].presence || "USD").upcase
    @to     = (params[:to].presence   || "NPR").upcase
    @target = (params[:target].presence || "mid")

    @to_date   = ExchangeRate.maximum(:date)
    @from_date = @to_date&.-(30)

    cur = Currency.find_by(iso3: @from)
    @today_rate = (@to_date && cur) ? ExchangeRate.where(currency_id: cur.id, date: @to_date).pick(@target) : nil

    # Pull the latest prediction for h=1..3 (72h window)
    @predictions_72h = []
    if cur && @today_rate
      @predictions_72h = (1..3).map do |h|
        Prediction.joins(:currency)
                  .where(currencies: { iso3: @from }, target: @target, horizon: h)
                  .order(predicted_for: :desc)
                  .limit(1).first
      end.compact.sort_by(&:predicted_for)
    end

    @best_pred = @predictions_72h.max_by(&:yhat)

    # === Recommendation (NOW vs WAIT) ===
    @recommendation = nil
    @wait_hours     = nil
    @best_delta_pct = nil

    if @today_rate && @best_pred
      @best_delta_pct = ((@best_pred.yhat.to_f - @today_rate.to_f) / @today_rate.to_f) * 100.0
      @recommendation = (@best_delta_pct >= 0.5) ? "WAIT" : "SEND NOW"
      @wait_hours     = ((@best_pred.predicted_for - @to_date).to_i * 24) if @recommendation == "WAIT"
    end

    # For mini sparkline / recent context
    @recent_rates = if cur && @from_date && @to_date
      ExchangeRate.where(currency_id: cur.id)
                  .where("date BETWEEN ? AND ?", @from_date, @to_date)
                  .order(:date).pluck(:date, @target)
    else
      []
    end

    @currency_options = Currency.order(:iso3).pluck(:iso3)

    # === Server-side Impact Calculator ===
    @amount     = (params[:amount].presence || 500).to_f
    today_rate  = @today_rate.to_f if @today_rate
    best_rate   = @best_pred&.yhat.to_f

    @today_amt  = (today_rate ? (@amount * today_rate) : nil)
    @best_amt   = (best_rate && best_rate > 0 ? (@amount * best_rate) : nil)
    @diff_amt   = (@today_amt && @best_amt) ? (@best_amt - @today_amt) : nil
  end
end
