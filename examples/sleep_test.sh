#!/bin/bash

# Test various sleep command formats
echo "Testing sleep commands..."

# Basic sleep with integer seconds
sleep 5

# Sleep with seconds suffix
sleep 10s

# Sleep with minutes
sleep 1m

# Sleep with hours
sleep 1h

# Sleep with fractional seconds
sleep 0.5

# Sleep with fractional seconds and suffix
sleep 0.5s

# Sleep with no arguments (default 1 second)
sleep

# Sleep with invalid arguments
sleep invalid

echo "All sleep commands completed!"