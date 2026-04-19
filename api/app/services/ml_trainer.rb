class MlTrainer
  include HTTParty
  base_uri ENV.fetch("ML_BASE_URL", "http://ml:8000")

  def self.train(currency:, target:, horizon:, window:, values:, dates:)
    resp = post("/train",
      body: { currency:, target:, horizon:, window:, values:, dates: }.to_json,
      headers: { "Content-Type" => "application/json" }
    )
    raise "ML train error #{resp.code}: #{resp.body}" unless resp.success?
    resp.parsed_response # => {"currency","target","horizon","trained_until","tag"}
  end
end
