#!/usr/bin/env bash

namespace="${1:-default}"
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
	"CN": "custom-metrics-api-server",
	"hosts": [
		"custom-metrics-api-server.$namespace",
		"custom-metrics-api-server.$namespace.svc"
	],
	"key": {"algo": "rsa", "size": 2048}
}
EOF

usergroup="$(id -u):$(id -g)"
docker run -i \
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
| docker run -i \
	--entrypoint=cfssljson \
	-v "$tmpdir:/workdir" \
	-w /workdir \
	--user "$usergroup" \
	"$cfssl_image" \
		-bare ./output/apiserver

echo "--- 8< --- Add the following to values-custom-secret.yaml --- 8< ---"
cat <<EOF
---
customMetrics:
  caBundle: '$(cat "$tmpdir/metrics-ca.crt" "$tmpdir/output/apiserver.pem" | base64 -w 0)'
  servingCert: '$(base64 -w 0 "$tmpdir/output/apiserver.pem")'
  servingKey: '$(base64 -w 0 "$tmpdir/output/apiserver-key.pem")'
EOF

rm -rf "$tmpdir"
