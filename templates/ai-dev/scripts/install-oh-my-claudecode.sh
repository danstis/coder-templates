#!/bin/bash
echo "Starting oh-my-claudecode installation..."
echo "NOTE: You must be logged in to Claude CLI first."
echo "If you haven't logged in, press Ctrl+C, run 'claude login', and try again."
echo "Starting in 5 seconds..."
sleep 5

expect <<'EXP'
  set timeout 120
  spawn claude
  
  # Wait for prompt (assuming it ends with > or similar)
  expect -re ".* >"
  send "/plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode\r"
  
  expect -re ".* >"
  send "/plugin install oh-my-claudecode\r"
  
  expect -re ".* >"
EXP
