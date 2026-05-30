.DEFAULT_GOAL := help

.PHONY: help cover test lint testf lintf doc fuzz fuzz-time fuzz-replay fuzz-corpus fuzz-shrink

help: ## Show this help message
		@echo 'Usage: make [target]'
		@echo ''
		@echo 'Available targets:'
		@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

cover: ## Run tests with coverage and open report
		dart run coverage:test_with_coverage
		genhtml coverage/lcov.info -o coverage/html
		open coverage/html/index.html

test: ## Run all tests
		dart test -r failures-only

testf: ## Run test on specific file (usage: make testf FILE=test/rss_cases.dart)
		dart test -r failures-only $(FILE)

lint: ## Run static analysis
		dart analyze

lintf: ## Run static analysis on specific file (usage: make lintf FILE=lib/src/universal/universal_feed.dart)
		dart analyze $(FILE)

format: ## Format all Dart files
		dart format .

formatf: ## Format specific Dart file (usage: make formatf FILE=lib/src/universal/universal_feed.dart)
		dart format $(FILE)

doc: ## Generate documentation
		dart doc

fuzz: ## Run fuzz harnesses (iter-bounded, default ITER=10000)
		FUZZ_ITER=$(or $(ITER),10000) dart test -r failures-only test/fuzz/harnesses/

fuzz-time: ## Run fuzz harnesses (time-bounded, default SECS=60)
		FUZZ_SECS=$(or $(SECS),60) dart test -r failures-only test/fuzz/harnesses/

fuzz-replay: ## Replay persisted crashes/ only (regression guard)
		FUZZ_MODE=replay dart test -r failures-only test/fuzz/harnesses/

fuzz-corpus: ## Run seed corpus only (known-good & targeted cases)
		dart test -r failures-only test/fuzz/corpus_test.dart

fuzz-shrink: ## Shrink a failing input (usage: make fuzz-shrink FILE=crashes/<sha1>.bin)
		dart run test/fuzz/_support/shrink.dart --file=$(FILE)
