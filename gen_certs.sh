#!/usr/bin/env bash
# Generates a self-signed TLS certificate with a Subject Alternative Name (SAN).
# Required for modern browsers and Python requests to accept the cert without errors.
# Compatible with OpenSSL < 1.1.1 (uses a temporary config file instead of -addext).
# Output: cert.pem and key.pem in the current directory (both are gitignored).

set -euo pipefail

# Prompt for the server IP or hostname (never hard-coded or logged)
read -rp "Enter server IP or hostname (e.g. 192.168.1.100): " SERVER_HOST

if [[ -z "$SERVER_HOST" ]]; then
    echo "ERROR: Server IP/hostname cannot be empty."
    exit 1
fi

# Determine SAN type: IP address or DNS name
if [[ "$SERVER_HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    SAN="IP:${SERVER_HOST}"
else
    SAN="DNS:${SERVER_HOST}"
fi

echo "Generating certificate for: $SERVER_HOST (SAN=$SAN)"

# Write a temporary OpenSSL config file — avoids -addext which requires OpenSSL >= 1.1.1
TMPCONF=$(mktemp /tmp/openssl_san_XXXXXX.cnf)
trap 'rm -f "$TMPCONF"' EXIT

cat > "$TMPCONF" <<EOF
[req]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
x509_extensions    = v3_req

[dn]
C  = GR
ST = Crete
L  = Chania
CN = ${SERVER_HOST}

[v3_req]
subjectAltName = ${SAN}
EOF

openssl req -x509 -newkey rsa:4096 \
    -keyout key.pem \
    -out cert.pem \
    -days 365 \
    -nodes \
    -config "$TMPCONF"

echo ""
echo "PASS: cert.pem and key.pem generated."
echo ""
echo "Next steps:"
echo "  1. Run deploy.ps1 to copy certs into Docker and restart the container."
echo "  2. Copy cert.pem to the Raspberry Pi for verified HTTPS uploads."
echo ""

# Print cert summary for verification
openssl x509 -in cert.pem -noout -subject -issuer -dates \
    -ext subjectAltName 2>/dev/null || \
openssl x509 -in cert.pem -noout -subject -issuer -dates
