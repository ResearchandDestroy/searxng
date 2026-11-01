#!/bin/sh

printf '\n'
sleep 5

while :
do
    curl -sI 'http://127.0.0.1:8080/search' | grep -E '^HTTP'
    sleep 30
done
