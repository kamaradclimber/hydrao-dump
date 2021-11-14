#!/usr/bin/env bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
pip install --user -r $SCRIPT_DIR/requirements.txt
python $SCRIPT_DIR/receiver.py
