.DEFAULT_GOAL := help

.PHONY: help cover test lint testf lintf doc

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
		dart test

testf: ## Run test on specific file (usage: make testf FILE=test/rss_cases.dart)
		dart test $(FILE)

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
