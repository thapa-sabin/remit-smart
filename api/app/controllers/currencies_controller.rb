class CurrenciesController < ApplicationController
  # GET /currencies(.json)
  # Params:
  #   q: optional search (matches ISO3 or name, case-insensitive)
  #   page: 1-based page number (default: 1)
  #   per: items per page (default: 50, max: 200)
  def index
    # Base scope
    scope = Currency.order(:iso3)

    # Optional search
    if params[:q].present?
      q = params[:q].to_s.strip
      # Use SQL ILIKE for Postgres (case-insensitive)
      scope = scope.where("iso3 ILIKE ? OR name ILIKE ?", "%#{q}%", "%#{q}%")
    end

    # Manual pagination
    @page  = params[:page].to_i <= 0 ? 1 : params[:page].to_i
    @per   = [[params[:per].to_i, 1].max, 200].min
    @per   = 50 if params[:per].blank?
    @total = scope.count
    @rows  = scope
               .offset((@page - 1) * @per)
               .limit(@per)
               .map do |c|
                 last_rate = ExchangeRate.where(currency_id: c.id).maximum(:date)
                 last_pred = Prediction.where(currency_id: c.id).maximum(:predicted_for)
                 {
                   iso3: c.iso3,
                   name: c.name,
                   unit: c.unit,
                   last_rate_date: last_rate,
                   last_pred_date: last_pred
                 }
               end

    respond_to do |format|
      format.html # renders app/views/currencies/index.html.erb
      format.json do
        render json: {
          page: @page, per: @per, total: @total,
          data: @rows
        }
      end
    end
  end
end
