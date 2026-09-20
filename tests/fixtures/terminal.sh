#!/bin/sh
printf 'fixture ready\n'
printf 'cwd=%s\n' "$PWD"
printf 'arg=%s\n' "$1"
while IFS= read -r line; do
  case "$line" in
    exit) exit 0 ;;
    fail) printf 'fixture failure\n'; exit 7 ;;
    *) printf 'received=%s\n' "$line" ;;
  esac
done
