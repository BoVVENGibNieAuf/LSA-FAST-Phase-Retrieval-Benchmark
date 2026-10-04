#!/bin/sh
set -eu
cd "$(dirname "$0")"
if command -v xelatex >/dev/null 2>&1; then
  xelatex -interaction=nonstopmode -halt-on-error main.tex
  xelatex -interaction=nonstopmode -halt-on-error main.tex
elif command -v tectonic >/dev/null 2>&1; then
  tectonic --keep-logs main.tex
else
  echo 'Install XeLaTeX (TeX Live/MiKTeX with Chinese support) or Tectonic.' >&2
  exit 1
fi
