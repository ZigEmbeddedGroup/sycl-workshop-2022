#!/bin/bash

llvm-objdump -S "$1" > "$1.dump"