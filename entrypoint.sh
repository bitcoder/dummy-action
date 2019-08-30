#!/bin/sh -l

sh -c "echo $*"

sh -c "echo NAME: $INPUT_NAME"
sh -c "echo FILE: $INPUT_FILE"

sh -c "cat /README.md"
sh -c "cat /github/workspace/README.md"
#sh -c "cat /github/workspace/target/surefire-reports/TEST-com.xpand.java.CalcTest.xml"
sh -c "cat /github/workspace/$INPUT_FILE"
sh -c "find /github/workspace/ -type f"


curl -H "Content-Type: multipart/form-data" -u $INPUT_JIRA_USERNAME:$INPUT_JIRA_PASSWORD -F "file=@/github/workspace/$INPUT_FILE" "$INPUT_JIRA_URL/rest/raven/1.0/import/execution/junit?projectKey=$INPUT_PROJECT_KEY"
