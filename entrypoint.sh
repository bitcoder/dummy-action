#!/bin/sh -l

sh -c "echo $*"

sh -c "NAME: $INPUT_NAME"
sh -c "NAME: $INPUT_fILE"

sh -c "cat /README.md"
sh -c "cat /github/workspace/README.md"
sh -c "cat /github/workspace/target/surefire-reports/TEST-com.xpand.java.CalcTest.xml"
sh -c "find /github/workspace/ -type f"
