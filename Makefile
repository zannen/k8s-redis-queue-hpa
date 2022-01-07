# See /licensing.md for licence details.

# Makefile for generating TLS certs for the Prometheus custom metrics API adapter

SHELL=bash
UNAME:=$(shell uname)
PURPOSE:=metrics
SECRET_FILE:=cm-adapter-serving-certs.yaml
NAMESPACE:=suihei

certs: gensecret rmcerts

.PHONY: gencerts
gencerts:
	@echo Generating TLS certs
	@docker pull cfssl/cfssl:latest
	@mkdir -p output
	@touch output/apiserver.pem
	@touch output/apiserver-key.pem
	@openssl req -x509 -sha256 -new -nodes -days 365 -newkey rsa:2048 -keyout $(PURPOSE)-ca.key -out $(PURPOSE)-ca.crt -subj "/CN=ca"
	@echo '{"signing":{"default":{"expiry":"43800h","usages":["signing","key encipherment","'$(PURPOSE)'"]}}}' > "$(PURPOSE)-ca-config.json"
	@echo '{"CN":"custom-metrics-apiserver","hosts":["custom-metrics-apiserver.$(NAMESPACE)","custom-metrics-apiserver.$(NAMESPACE).svc"],"key":{"algo":"rsa","size":2048}}' \
		| docker run -i \
			-v ${HOME}:${HOME} \
			-v ${PWD}/$(PURPOSE)-ca.key:/workdir/$(PURPOSE)-ca.key \
			-v ${PWD}/$(PURPOSE)-ca.crt:/workdir/$(PURPOSE)-ca.crt \
			-v ${PWD}/$(PURPOSE)-ca-config.json:/workdir/$(PURPOSE)-ca-config.json \
			cfssl/cfssl \
				gencert \
					-ca=$(PURPOSE)-ca.crt \
					-ca-key=$(PURPOSE)-ca.key \
					-config=$(PURPOSE)-ca-config.json - \
		| docker run -i \
			--entrypoint=cfssljson \
			-v ${HOME}:${HOME} \
			-v ${PWD}/output:/workdir/output \
			cfssl/cfssl:latest \
				-bare output/apiserver

.PHONY: gensecret
gensecret: gencerts
	@echo Generating $(SECRET_FILE)
	@echo "Unknown OS. See Makefile." >.cert.tmp
	@echo "Unknown OS. See Makefile." >.privkey.tmp
ifeq ($(UNAME), Darwin)
	@base64 output/apiserver.pem >.cert.tmp
	@base64 output/apiserver-key.pem >.privkey.tmp
endif
ifeq ($(UNAME), Linux)
	@base64 -w 0 output/apiserver.pem >.cert.tmp
	@base64 -w 0 output/apiserver-key.pem >.privkey.tmp
endif
	@cp -a $(SECRET_FILE).template templates/$(SECRET_FILE)
	@cert="$$(cat .cert.tmp)" && sed --in-place -e "s#__CERTIFICATE_PLACEHOLDER__#$$cert#" templates/$(SECRET_FILE)
	@privkey="$$(cat .privkey.tmp)" && sed --in-place -e "s#__PRIVKEY_PLACEHOLDER__#$$privkey#" templates/$(SECRET_FILE)
	@rm -f .cert.tmp .privkey.tmp

.PHONY: rmcerts
rmcerts:
	@rm -f apiserver-key.pem apiserver.csr apiserver.pem
	@rm -f $(PURPOSE)-ca-config.json $(PURPOSE)-ca.crt $(PURPOSE)-ca.key
