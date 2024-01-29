#!/usr/bin/env bash

dart run coverage:test_with_coverage

genhtml coverage/lcov.info -o coverage/html
# format_coverage --lcov --in=./coverage/coverage.json --out=./coverage/coverage.lcov --report-on=lib/