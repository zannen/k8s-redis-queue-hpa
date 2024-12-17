#!/usr/bin/env bash

namespace="${1:-}"
if [[ -z "$namespace" ]] ; then
	echo "Syntax: $0 <namespace>"
	exit 1
fi
echo "Using namespace: $namespace"

tmpdir="$(mktemp -d)"

cfssl_image=cfssl/cfssl:latest
# docker pull "$cfssl_image"

echo "Generating TLS certs"
mkdir "$tmpdir/output"
openssl req -x509 -sha256 -new -nodes -days 365 -newkey rsa:2048 -keyout "$tmpdir/metrics-ca.key" -out "$tmpdir/metrics-ca.crt" -subj "/CN=ca"
cat >"$tmpdir/metrics-ca-config.json" <<EOF
{
	"signing": {
		"default": {
			"expiry": "43800h",
			"usages": ["signing", "key encipherment", "metrics"]
		}
	}
}
EOF

cat >"$tmpdir/crt-config.json" <<EOF
{
	"CN": "custom-metrics-apiserver",
	"hosts": [
		"custom-metrics-apiserver",
		"custom-metrics-apiserver.$namespace",
		"custom-metrics-apiserver.$namespace.svc"
	],
	"key": {"algo": "rsa", "size": 2048}
}
EOF

usergroup="$(id -u):$(id -g)"
docker run --rm -i \
	-v "$tmpdir:/workdir" \
	-w /workdir \
	--user "$usergroup" \
	"$cfssl_image" \
		gencert \
		-ca=metrics-ca.crt \
		-ca-key=metrics-ca.key \
		-config=metrics-ca-config.json \
		- \
		<"$tmpdir/crt-config.json" \
| docker run --rm -i \
	--entrypoint=cfssljson \
	-v "$tmpdir:/workdir" \
	-w /workdir \
	--user "$usergroup" \
	"$cfssl_image" \
		-bare ./output/apiserver

echo "--- 8< --- Add the following to values-custom-secret.yaml --- 8< ---"
cat <<EOF
---
# namespace: $namespace
customMetrics:
  apiService:
    caBundle: '$(base64 -w 0 "$tmpdir/metrics-ca.crt")'
  servingCert: '$(base64 -w 0 "$tmpdir/output/apiserver.pem")'
  servingKey: '$(base64 -w 0 "$tmpdir/output/apiserver-key.pem")'
EOF

rm -rf "$tmpdir"
