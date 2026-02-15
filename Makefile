# ===========================
# remit-smart — Dev Makefile
# ===========================

SHELL := /bin/bash

# ---------- Tunables ----------
DAYS     ?= 365          # backfill lookback
TARGETS  ?= mid          # comma-separated: mid,buy,sell
HORIZONS ?= 1,7,14       # comma-separated: 1,7,14
WINDOW   ?= 60           # LSTM window size (days)

COMPOSE  ?= docker compose

# ---------- Helpers ----------
define RUN_RAILS
$(COMPOSE) run --rm api bash -lc "$(1)"
endef

define RUN_DB
$(COMPOSE) exec db psql -U app -d forex -c "$(1)"
endef

# ---------- Meta ----------
.PHONY: help up down restart logs logs-api logs-worker ps build clean

help:
	@echo ""
	@echo "Remit Smart — common tasks"
	@echo "---------------------------"
	@echo "make up                 # start all services (detached)"
	@echo "make down               # stop all services"
	@echo "make restart            # restart api + worker"
	@echo "make ps                 # list running containers"
	@echo "make logs               # tail all logs"
	@echo "make logs-api           # tail Rails logs"
	@echo "make logs-worker        # tail Sidekiq logs"
	@echo ""
	@echo "Database & Rails"
	@echo "----------------"
	@echo "make dbshell            # open psql shell"
	@echo "make rails-console      # rails console inside api container"
	@echo "make zeitwerk-check     # verify autoloading"
	@echo "make migrate            # run migrations"
	@echo ""
	@echo "Data pipeline"
	@echo "-------------"
	@echo "make backfill DAYS=365  # ingest NRB rates for last DAYS (default: $(DAYS))"
	@echo "make train_all          # train all currencies (TARGETS=$(TARGETS), HORIZONS=$(HORIZONS), WINDOW=$(WINDOW))"
	@echo "make predict_all        # generate predictions for all currencies"
	@echo "make status             # quick DB sanity checks"
	@echo ""
	@echo "One-shot"
	@echo "--------"
	@echo "make first_run          # backfill -> train_all -> predict_all"
	@echo ""

# ---------- Docker orchestration ----------
up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart api worker

ps:
	$(COMPOSE) ps

build:
	$(COMPOSE) build

logs:
	$(COMPOSE) logs -f

logs-api:
	$(COMPOSE) logs -f api

logs-worker:
	$(COMPOSE) logs -f worker

# ---------- Rails / DB ----------
rails-console:
	$(call RUN_RAILS,bundle exec rails console)

zeitwerk-check:
	$(call RUN_RAILS,bundle exec rails zeitwerk:check)

migrate:
	$(call RUN_RAILS,bundle exec rails db:migrate)

dbshell:
	$(COMPOSE) exec db psql -U app -d forex

# ---------- Pipeline: Ingestion ----------
# Uses explicit require to avoid any autoload hiccups in one-off runs
backfill:
	$(call RUN_RAILS,DAYS=$(DAYS) bundle exec rails ingest:backfill)

# ---------- Pipeline: Training (all currencies) ----------
# Pass parameters via ENV to avoid quoting headaches
train_all:
	$(call RUN_RAILS, \
		TARGETS=$(TARGETS) HORIZONS=$(HORIZONS) WINDOW=$(WINDOW) \
		bundle exec rails runner ' \
		  targets   = ENV.fetch("TARGETS","mid").split(","); \
		  horizons  = ENV.fetch("HORIZONS","1,7,14").split(",").map(&:to_i); \
		  window    = ENV.fetch("WINDOW","60").to_i; \
		  TrainAllCurrenciesJob.perform_now(targets: targets, horizons: horizons, window: window) \
		' \
	)

# ---------- Pipeline: Predictions (all currencies) ----------
predict_all:
	$(call RUN_RAILS, \
		TARGETS=$(TARGETS) HORIZONS=$(HORIZONS) WINDOW=$(WINDOW) \
		bundle exec rails runner ' \
		  targets   = ENV.fetch("TARGETS","mid").split(","); \
		  horizons  = ENV.fetch("HORIZONS","1,7,14").split(",").map(&:to_i); \
		  window    = ENV.fetch("WINDOW","60").to_i; \
		  GeneratePredictionsForAllJob.perform_now(targets: targets, horizons: horizons, window: window) \
		' \
	)

# ---------- Status / Diagnostics ----------
status:
	@echo "== currencies count =="
	$(call RUN_DB,SELECT COUNT(*) FROM currencies;)
	@echo "== latest 5 exchange_rates =="
	$(call RUN_DB,SELECT c.iso3,e.date,e.mid FROM exchange_rates e JOIN currencies c ON e.currency_id=c.id ORDER BY e.date DESC LIMIT 5;)
	@echo "== sample predictions per currency =="
	$(call RUN_DB,SELECT c.iso3,COUNT(*) FROM predictions p JOIN currencies c ON p.currency_id=c.id GROUP BY c.iso3 ORDER BY 1;)

# ---------- One-shot: backfill -> train -> predict ----------
first_run: backfill train_all predict_all
	@echo "First run completed."
