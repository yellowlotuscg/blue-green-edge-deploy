PYTHON ?= python3

.PHONY: seed build test deploy-local rollback-local drill tf-validate

seed:
	$(PYTHON) scripts/seed.py

build: seed
	$(PYTHON) scripts/build.py

test:
	$(PYTHON) -m pytest -q
	node --test edge/*.test.js

deploy-local:
	DRY_RUN=1 ./scripts/deploy.sh --local

rollback-local:
	DRY_RUN=1 ./scripts/rollback.sh --local "$${VERSION}"

drill:
	./scripts/rollback_drill.sh

tf-validate:
	terraform fmt -check -recursive infra
	terraform -chdir=infra init -backend=false
	terraform -chdir=infra validate
