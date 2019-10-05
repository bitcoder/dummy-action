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

DEBUG=0
MULTIPART=0
CLOUD=0
#JIRA_URL=""
#USERNAME=""
#PASSWORD=""
#REPORT=""
#FORMAT=""
#PROJECT=""
#VERSION=""
#REVISION=""
#TESTPLAN=""
#TESTEXECUTION=""
#TEST_ENVIRONMENTS=""


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
 s="$s$(append_str "projectKey" "$PROJECT")"
 s="$s$(append_str "testExecKey" "$TESTEXECUTION")"
 s="$s$(append_str "testPlanKey" "$TESTPLAN")"
 s="$s$(append_str "revision" "$REVISION")"
 s="$s$(append_str "fixVersion" "$VERSION")"    
 s="$s$(append_str "testEnvironments" "$(echo $TEST_ENVIRONMENTS|tr " " ";")")"
 echo $s
}




OPTIND=1
    while getopts dcj:u:w:r:f:p:v:b:t:e:i:s:x: opt ; do
        case "$opt" in
            d)  DEBUG=1;;
            c)  CLOUD=1;;
            j)  JIRA_URL="$OPTARG";;
            u)  USERNAME="$OPTARG";;
            w)  PASSWORD="$OPTARG";;
            r)  REPORT="$OPTARG";;
            f)  FORMAT="$OPTARG";;
            p)  PROJECT="$OPTARG";;
            v)  VERSION="$OPTARG";;
            b)  REVISION="$OPTARG";;
            t)  TESTPLAN="$OPTARG";;
            e)  TESTEXECUTION="$OPTARG";;
            i)  CLIENT_ID="$OPTARG";;
            s)  CLIENT_SECRET="$OPTARG";;
            x)  TEST_ENVIRONMENTS="$OPTARG";;
        esac
    done

echo "cloud: $CLOUD"
echo "report: $REPORT"
echo "format: $FORMAT"
echo "project: $PROJECT"
echo "jira_url: $JIRA_URL"



valid_formats=("junit" "testng" "nunit" "cucumber" "robot") 
check_valid_values "format" $FORMAT valid_formats

# etc


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


if [ ! -e "$REPORT" ]
then
 error "file with results not found at $REPORT"
fi

if [[ "$CLOUD" -ne "1" ]]
then
  # Xray server/DC

  if [ "$MULTIPART" -ne 1 ]
  then
    # standard endpoints

    if [ "$REPORT" == "cucumber" ]
    then
        curl $CURL_OPTS -H "Content-Type: application/json" -X POST -u $USERNAME:$PASSWORD --data @"$REPORT" "$JIRA_URL/rest/raven/1.0/import/execution/cucumber"
    else
        #curl $CURL_OPTS -H "Content-Type: multipart/form-data" -u $USERNAME:$PASSWORD -F "file=@$REPORT" "$JIRA_URL/rest/raven/1.0/import/execution/$FORMAT?projectKey=$PROJECT"
        GET_PARAMS=$(build_get_params)
        curl $CURL_OPTS -H "Content-Type: multipart/form-data" -u $USERNAME:$PASSWORD -F "file=@$REPORT" "$JIRA_URL/rest/raven/1.0/import/execution/$FORMAT?$GET_PARAMS"
    fi
  else
    # multipart endpoints
    #TO DO
   curl $CURL_OPTS -H "Content-Type: multipart/form-data" -u $USERNAME:$PASSWORD -F "file=@$REPORT" -F "info=@info.json" "$JIRA_URL/rest/raven/1.0/import/execution/$FORMAT/multipart"
fi
else
 #  Xray CLOUD

 if [ ! -e "$CLOUD_AUTH_FILE" ]
 then
  error "file with Xray's Cloud client_id and client_secret was not found"
 fi

 token=""
 if [ -n "$CLIENT_ID" ] || [ -n "$CLIENT_SECRET" ]
 then
    CLOUD_AUTH_STR="{ \"client_id\": \"$CLIENT_ID\",\"client_secret\": \"$CLIENT_SECRET\" }"
    #echo "CLOUD_AUTH_STR: $CLOUD_AUTH_STR"
    token=$(curl $CURL_OPTS -H "Content-Type: application/json" -X POST --data "$CLOUD_AUTH_STR" "$XRAY_CLOUD_ENDPOINT/api/v1/authenticate"| tr -d '"')

 else
    token=$(curl $CURL_OPTS -H "Content-Type: application/json" -X POST --data @"$CLOUD_AUTH_FILE" "$XRAY_CLOUD_ENDPOINT/api/v1/authenticate"| tr -d '"')
 fi
 test $? == 0 || error "failed to obtain token. Please check credentials."

 curl -s -S -H "Content-Type: text/xml" -X POST -H "Authorization: Bearer $token"  --data @"$REPORT" "$XRAY_CLOUD_ENDPOINT/api/v1/import/execution/$FORMAT?projectKey=$PROJECT&fixVersion=$VERSION&revision=$REVISION&testEnvironments=$ENVIRONMENTS&testPlanKey=$TESTPLAN&testExecKey=$TESTEXECUTION"

fi
 


