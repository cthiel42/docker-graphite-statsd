#!/usr/bin/env bash
VERSION=1.1.8-2
docker build . --build-arg python_binary=python3 --no-cache --tag graphite-web:$VERSION