#!/bin/sh -l

sh -c "echo $*"

sh -c "cat /README.md"
sh -c "cat /github/workspace/README.md"
