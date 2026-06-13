#!/bin/bash
# Add current directory to pythonpath
export PYTHONPATH=$PYTHONPATH:$(pwd)
echo "Starting FastAPI Backend..."
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
