#!/bin/sh
printf 'cwd=%s\n' "$PWD"
printf 'arg=%s\n' "$1"
# Signal readiness only after all startup output has been written.
printf 'fixture ready\n'
while IFS= read -r line; do
  case "$line" in
    exit) exit 0 ;;
    fail) printf 'fixture failure\n'; exit 7 ;;
    *) printf 'received=%s\n' "$line" ;;
  esac
done
