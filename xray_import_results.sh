#!/bin/bash

# Import automation results to Xray (server/DC or cloud)
# 
# Examples:
#  xray_import_results.sh -r junit.xml -f junit -p CALC -v 3.0 -u admin -w admin -j http://192.168.56.102 
#  xray_import_results.sh -r junit.xml -f junit -p CALC -c -i 1234567890 -s 0987654321 
#
# Limitations:
# - does not check if parameters are consistent
#
# Done:
# - does URL encode parameters
# - does  add GET parameters only if they are not empty

#LELO=$LELO || "script" # "" evaluates to true, so does not work
#LELO=$(test -z "$LELO" && echo "script" || echo "$LELO")

INPUT_DEBUG=0
INPUT_MULTIPART=0
INPUT_CLOUD=0
#INPUT_JIRA_JIRA_URL=""
#INPUT_JIRA_USERNAME=""
#INPUT_JIRA_PASSWORD=""
#INPUT_REPORT=""
#INPUT_FORMAT=""
#INPUT_PROJECT=""
#INPUT_VERSION=""
#INPUT_REVISION=""
#INPUT_TESTPLAN=""
#INPUT_TESTEXECUTION=""
#INPUT_TEST_ENVIRONMENTS=""


CFG_FILE="./xray_import_results.default"

if [ -f "$CFG_FILE" ]
then
 . $CFG_FILE
fi


XRAY_CLOUD_ENDPOINT="https://xray-staging.cloud.xpand-it.com"


CURL_OPTS=""

error () { 
 echo "ERROR: $1"
 exit 1
}


function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

check_valid_values () {
  # https://askubuntu.com/questions/674333/how-to-pass-an-array-as-function-argument

 local name=$1
 local value=$2

 local array_name=$3[@]
 local valid_values=("${!array_name}")
 #valid_values=("junit" "testng" "nunit" "cucumber" "robot")

#echo "name: $name"
#echo "value: $value"
#echo "valid_values: $valid_values"


 #check_supported_formats "format" $FORMAT "junit testng nunit cucumber"
 if [ $(contains "${valid_values[@]}" "$value") == "n" ]; then
    error "$value is not a valid $name"
 fi
}



#https://stackoverflow.com/questions/296536/how-to-urlencode-data-for-curl-command
rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER) 
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}

append_str() {
    local skey=$1
    local svalue=$2
    local s=""

    if [ ${#svalue} -gt 0 ]
    then
     s="$skey=$(rawurlencode "$svalue")&"
    fi
    echo $s
} 

build_get_params() {
#projectKey
#testExecKey
#testPlanKey
#testEnvironments
#revision  
#fixVersion
 local s=""
 s="$s$(append_str "projectKey" "$INPUT_PROJECT")"
 s="$s$(append_str "testExecKey" "$INPUT_TESTEXECUTION")"
 s="$s$(append_str "testPlanKey" "$INPUT_TESTPLAN")"
 s="$s$(append_str "revision" "$INPUT_REVISION")"
 s="$s$(append_str "fixVersion" "$INPUT_VERSION")"    
 s="$s$(append_str "testEnvironments" "$(echo $INPUT_TEST_ENVIRONMENTS|tr " " ";")")"
 echo $s
}




OPTIND=1
    while getopts dcj:u:w:r:f:p:v:b:t:e:i:s:x: opt ; do
        case "$opt" in
            d)  INPUT_DEBUG=1;;
            c)  INPUT_CLOUD=1;;
            j)  INPUT_JIRA_URL="$OPTARG";;
            u)  INPUT_USERNAME="$OPTARG";;
            w)  INPUT_PASSWORD="$OPTARG";;
            r)  INPUT_REPORT="$OPTARG";;
            f)  INPUT_FORMAT="$OPTARG";;
            p)  INPUT_PROJECT="$OPTARG";;
            v)  INPUT_VERSION="$OPTARG";;
            b)  INPUT_REVISION="$OPTARG";;
            t)  INPUT_TESTPLAN="$OPTARG";;
            e)  INPUT_TESTEXECUTION="$OPTARG";;
            i)  INPUT_CLIENT_ID="$OPTARG";;
            s)  INPUT_CLIENT_SECRET="$OPTARG";;
            x)  INPUT_TEST_ENVIRONMENTS="$OPTARG";;
        esac
    done

echo "cloud: $INPUT_CLOUD"
echo "report: $INPUT_REPORT"
echo "format: $INPUT_FORMAT"
echo "project: $INPUT_PROJECT"
echo "jira_url: $INPUT_JIRA_URL"



valid_formats=("junit" "testng" "nunit" "cucumber" "robot") 
check_valid_values "format" $INPUT_FORMAT valid_formats
# TO DO: complete validations


MANDATORY_FIELDS="REPORT FORMAT"
# REPORT and format are always mandatory

if [[ "$CLOUD" -eq "1" ]]
then
    # if cloud, then CLIENT_ID, CLIENT_SECRET are mandatory
   MANDATORY_FIELDS="$MANDATORY_FIELDS CLIENT_ID CLIENT_SECRET"
else
    # if server/DC, then JIRA_URL, USERNAME and PASSWORD are mandatory
    MANDATORY_FIELDS="$MANDATORY_FIELDS JIRA_URL USERNAME PASSWORD" 
fi


CURL_OPTS=""
if [[ "$DEBUG" -eq 1 ]]
then
 CURL_OPTS="$CURL_OPTS -fail -s -S"
else
 CURL_OPTS="$CURL_OPTS"
fi


if [ ! -e "$INPUT_REPORT" ]
then
 error "file with results not found at $INPUT_REPORT"
fi

if [[ "$CLOUD" -ne "1" ]]
then
  # Xray server/DC

  if [ "$MULTIPART" -ne 1 ]
  then
    # standard endpoints

    if [ "$REPORT" == "cucumber" ]
    then
        curl $CURL_OPTS -H "Content-Type: application/json" -X POST -u $INPUT_JIRA_USERNAME:$INPUT_JIRA_PASSWORD --data @"$INPUT_REPORT" "$INPUT_JIRA_URL/rest/raven/1.0/import/execution/cucumber"
    else
        #curl $CURL_OPTS -H "Content-Type: multipart/form-data" -u $USERNAME:$PASSWORD -F "file=@$REPORT" "$JIRA_URL/rest/raven/1.0/import/execution/$FORMAT?projectKey=$PROJECT"
        GET_PARAMS=$(build_get_params)
        curl $CURL_OPTS -H "Content-Type: multipart/form-data" -u $INPUT_JIRA_USERNAME:$INPUT_JIRA_PASSWORD -F "file=@$INPUT_REPORT" "$INPUT_JIRA_URL/rest/raven/1.0/import/execution/$INPUT_FORMAT?$GET_PARAMS"
    fi
  else
    # multipart endpoints
    #TO DO
   curl $CURL_OPTS -H "Content-Type: multipart/form-data" -u $INPUT_JIRA_USERNAME:$INPUT_JIRA_PASSWORD -F "file=@$INPUT_REPORT" -F "info=@info.json" "$JIRA_URL/rest/raven/1.0/import/execution/$INPUT_FORMAT/multipart"
fi
else
 #  Xray CLOUD

 if [ ! -e "$CLOUD_AUTH_FILE" ]
 then
  error "file with Xray's Cloud client_id and client_secret was not found"
 fi

 token=""
 if [ -n "$INPUT_CLIENT_ID" ] || [ -n "$INPUT_CLIENT_SECRET" ]
 then
    CLOUD_AUTH_STR="{ \"client_id\": \"$INPUT_CLIENT_ID\",\"client_secret\": \"$INPUT_CLIENT_SECRET\" }"
    #echo "CLOUD_AUTH_STR: $CLOUD_AUTH_STR"
    token=$(curl $CURL_OPTS -H "Content-Type: application/json" -X POST --data "$CLOUD_AUTH_STR" "$XRAY_CLOUD_ENDPOINT/api/v1/authenticate"| tr -d '"')

 else
    token=$(curl $CURL_OPTS -H "Content-Type: application/json" -X POST --data @"$CLOUD_AUTH_FILE" "$XRAY_CLOUD_ENDPOINT/api/v1/authenticate"| tr -d '"')
 fi
 test $? == 0 || error "failed to obtain token. Please check credentials."

 curl -s -S -H "Content-Type: text/xml" -X POST -H "Authorization: Bearer $token"  --data @"$INPUT_REPORT" "$XRAY_CLOUD_ENDPOINT/api/v1/import/execution/$FORMAT?projectKey=$INPUT_PROJECT&fixVersion=$INPUT_VERSION&revision=$INPUT_REVISION&testEnvironments=$INPUT_TEST_ENVIRONMENTS&testPlanKey=$INPUT_TESTPLAN&testExecKey=$INPUT_TESTEXECUTION"

fi
 


