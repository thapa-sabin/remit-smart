# app/services/ml_predictor.rb
class MlPredictor
  include HTTParty
  base_uri ENV.fetch("ML_BASE_URL", "http://ml:8000")

  def self.predict(currency:, target: "mid", horizon: 7, window: 60)
    cur = Currency.find_by!(iso3: currency)
    series = ExchangeRate.where(currency_id: cur.id).order(:date).pluck(target)
    recent = series.last(window)
    raise "not enough data (need #{window})" if recent.nil? || recent.size < window

    res = post("/predict",
      body: { currency:, target:, horizon:, window:, recent_values: recent }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
    raise "ML error #{res.code}: #{res.body}" unless res.success?
    res.parsed_response
  end

  def self.model_meta(currency:, target:, horizon:)
    get("/metadata", query: { currency:, target:, horizon: }).parsed_response
  end
end
