# config/routes.rb
Rails.application.routes.draw do
  get "currencies/index"
  # Built-in liveness endpoint (keep exactly once)
  get "up" => "rails/health#show", as: :rails_health_check

  # UI
  root "corridors#show"                    # home page
  get  "/corridor", to: "corridors#show", as: :corridor

  # JSON endpoints
  get  "/currencies",           to: "currencies#index"
  get  "/rates",                to: "rates#index"
  get  "/predictions",          to: "predictions#index"
  post "/predictions/generate", to: "predictions#generate"

  # Data freshness page
  get "/health", to: "health#index"

  # (Optional) Sidekiq Web — only mount when you add authentication
  # require "sidekiq/web"
  # mount Sidekiq::Web => "/sidekiq"
end
