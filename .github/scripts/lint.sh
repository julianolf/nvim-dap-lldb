#!/usr/bin/env bash

set -euo pipefail

stylua --check .
selene .
