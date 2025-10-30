build:
	@mkdir -p dist
	@if [ ! -f "$$HOME/.cargo/registry/src/schemas/ygtc.flow.schema.json" ]; then \
		echo "Missing flow schema: $$HOME/.cargo/registry/src/schemas/ygtc.flow.schema.json"; \
		echo "Copy ../../schemas/ygtc.flow.schema.json there before building."; \
		exit 1; \
	fi
	@packc build --in . --out dist/weather_pack.wasm --manifest dist/manifest.cbor --sbom dist/sbom.cdx.json
