#!/bin/bash
# Ersetzt durch build/make_release.sh (ZIP + scripts-only). Dieser Aufruf leitet weiter.
exec "$(dirname "$0")/build/make_release.sh" "$@"
