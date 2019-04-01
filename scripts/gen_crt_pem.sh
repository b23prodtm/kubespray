#!/usr/bin/env bash
[ "$#" -gt 0 ] && [ -f $1.crt ] && openssl x509 -in $1.crt -out $1.pem -outform PEM && cat $1.pem || echo "Usage: $0 <crtfile-without-ext>"
