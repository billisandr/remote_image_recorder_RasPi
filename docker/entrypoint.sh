#!/bin/sh
# Fix ownership of mounted volumes, then drop to appuser and run the app.
# Runs as root briefly so it can chown the Docker-mounted volume directories.
chown -R appuser:appuser /app/uploads /app/data
exec gosu appuser "$@"
