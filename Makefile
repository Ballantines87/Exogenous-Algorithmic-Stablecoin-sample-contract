-include .env

.PHONY: install test build run clean remove all

build:
	forge build