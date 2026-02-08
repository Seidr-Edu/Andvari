.PHONY: format lint test build run

format:
	./scripts/format.sh

lint:
	./scripts/lint.sh

test:
	./scripts/test.sh

build:
	./scripts/build.sh

run:
	./scripts/run.sh
