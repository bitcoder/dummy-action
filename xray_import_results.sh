#!/bin/bash

# Import automation results to Xray (server/DC or cloud)
# 
# Examples:
#  xray_import_results.sh -r junit.xml -f junit -p CALC -v 3.0 -u admin -w admin -j http://192.168.56.102 
#  xray_import_results.sh -r junit.xml -f junit -p CALC -c -i 1234567890 -s 0987654321 
#
# Limitations / TO DOs:
# - does not check if parameters are consistent
# - review parameters syntax
# Done:
# - does URL encode parameters
# - does  add GET parameters only if they are not empty

#LELO=$LELO || "script" # "" evaluates to true, so does not work
#LELO=$(test -z "$LELO" && echo "script" || echo "$LELO")

INPUT_DEBUG=0
INPUT_MULTIPART=0
INPUT_CLOUD=0
#INPUT_CLOUD_AUTH_FILE
#INPUT_JIRA_JIRA_URL=""
#INPUT_JIRA_USERNAME=""
#INPUT_JIRA_PASSWORD=""
#INPUT_FILE=""
#INPUT_REPORT=""
#INPUT_PROJECT_KEY=""
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

# check if array contains given value
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

# check if given array, by name, contains given value
check_valid_values_for_param () {
 # https://askubuntu.com/questions/674333/how-to-pass-an-array-as-function-argument

 local param=$1
 local value=$2

 local array_name=$3[@]
 local valid_values=("${!array_name}")

 if [ $(contains "${valid_values[@]}" "$value") == "n" ]; then
    error "$value is not a valid $param"
 fi
}

show_syntax () {
 error "please review the syntax"
}

check_if_mandatory_params_are_all_present () {
 local array_name=$1[@]
 local array=("${!array_name}")

    for param_name in "${array[@]}"
    do
      param_value="${!param_name}"
      if [ ${#param_value} -eq 0 ]
      then
        error "please review the syntax; $param_name must be defined (as environment variable or through the respective argument)"
      fi
    done
} 

# URL encodes given string
rawurlencode() {
  #https://stackoverflow.com/questions/296536/how-to-urlencode-data-for-curl-command
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

# return a string with key and value, URL encoded
# TO DO: URL encode key also?
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

# add additional GET parameters even on POST requests (both server and cloud)
build_get_params() {
 local s=""
 s="$s$(append_str "projectKey" "$INPUT_PROJECT_KEY")"
 s="$s$(append_str "testExecKey" "$INPUT_TESTEXECUTION")"
 s="$s$(append_str "testPlanKey" "$INPUT_TESTPLAN")"
 s="$s$(append_str "revision" "$INPUT_REVISION")"
 s="$s$(append_str "fixVersion" "$INPUT_VERSION")"    
 s="$s$(append_str "testEnvironments" "$(echo $INPUT_TEST_ENVIRONMENTS|tr " " ";")")"
 echo $s
}




OPTIND=1
    while getopts dcma:o:t:j:u:w:f:r:k:v:b:p:x:i:s:e: opt ; do
        case "$opt" in
            d)  INPUT_DEBUG=1;;
            c)  INPUT_CLOUD=1;;
            m)  INPUT_MULTIPART=1;;
            a)  INPUT_CLOUD_AUTH_FILE="$OPTARG";;
            o)  INPUT_INFO_OBJECT="$OPTARG";;
            t)  INPUT_TESTINFO_OBJECT="$OPTARG";;
            j)  INPUT_JIRA_URL="$OPTARG";;
            u)  INPUT_JIRA_USERNAME="$OPTARG";;
            w)  INPUT_JIRA_PASSWORD="$OPTARG";;
            f)  INPUT_FILE="$OPTARG";;
            r)  INPUT_REPORT="$OPTARG";;
            k)  INPUT_PROJECT_KEY="$OPTARG";;
            v)  INPUT_VERSION="$OPTARG";;
            b)  INPUT_REVISION="$OPTARG";;
            p)  INPUT_TESTPLAN="$OPTARG";;
            x)  INPUT_TESTEXECUTION="$OPTARG";;
            i)  INPUT_CLIENT_ID="$OPTARG";;
            s)  INPUT_CLIENT_SECRET="$OPTARG";;
            e)  INPUT_TEST_ENVIRONMENTS="$OPTARG";;
        esac
    done

if [[ "$DEBUG" -eq 1 ]]
then
    echo "cloud: $INPUT_CLOUD"
    echo "file: $INPUT_FILE"
    echo "report format: $INPUT_REPORT"
    echo "multipart: $INPUT_MULTIPART"
    echo "project: $INPUT_PROJECT_KEY"
    echo "jira_url: $INPUT_JIRA_URL"
fi


valid_formats=("junit" "testng" "nunit" "xunit" "cucumber" "behave" "robot")
# TO DO: add and validate xray, behave, xunit and other 
# TO DO: some formats are dependent on Xray deployment type
check_valid_values_for_param "report format" $INPUT_REPORT valid_formats
# TO DO: complete validations


MANDATORY_FIELDS=("INPUT_FILE" "INPUT_REPORT")
# INPUT_FILE and INPUT_REPORT are always mandatory

if [[ "$INPUT_CLOUD" -eq "1" ]]
then
  # if cloud, then either require CLIENT_ID, CLIENT_SECRET or INPUT_CLOUD_AUTH_FILE
  if [ ${#INPUT_CLOUD_AUTH_FILE} -eq 0 ]
  then
    MANDATORY_FIELDS+=("INPUT_JIRA_CLIENT_ID" "INPUT_JIRA_CLIENT_SECRET")
  else
   MANDATORY_FIELDS+=("INPUT_CLOUD_AUTH_FILE")
  fi
else
    # if server/DC, then JIRA_URL, USERNAME and PASSWORD are mandatory
    MANDATORY_FIELDS=("INPUT_JIRA_URL" "INPUT_JIRA_USERNAME" "INPUT_JIRA_PASSWORD")
fi

#check_valid_values "report format" $ MANDATORY_FIELDS
check_if_mandatory_params_are_all_present MANDATORY_FIELDS


CURL_OPTS=""
if [[ "$DEBUG" -eq 1 ]]
then
 CURL_OPTS="$CURL_OPTS -fail -s -S"
else
 CURL_OPTS="$CURL_OPTS -s -S"
fi


if [ ! -e "$INPUT_FILE" ]
then
 error "file with results not found ($INPUT_FILE)"
fi

if [[ "$INPUT_CLOUD" -ne "1" ]]
then
  # Xray server/DC

  if [ "$INPUT_MULTIPART" -ne 1 ]
  then
    # standard endpoints

    if [ "$INPUT_REPORT" == "cucumber" ] || [ "$INPUT_REPORT" == "cucumber" ] 
    then
        curl $CURL_OPTS -H "Content-Type: application/json" -X POST -u $INPUT_JIRA_USERNAME:$INPUT_JIRA_PASSWORD --data @"$INPUT_FILE" "$INPUT_JIRA_URL/rest/raven/1.0/import/execution/cucumber"
    else
        GET_PARAMS=$(build_get_params)
        curl $CURL_OPTS -H "Content-Type: multipart/form-data" -u $INPUT_JIRA_USERNAME:$INPUT_JIRA_PASSWORD -F "file=@$INPUT_FILE" "$INPUT_JIRA_URL/rest/raven/1.0/import/execution/$INPUT_REPORT?$GET_PARAMS"
    fi
  else
    # multipart endpoints

    if [ ! -e "$INPUT_INFO_OBJECT" ]
    then
     error "file with \"test\" JSON object not found ($INPUT_INFO_OBJECT)"
    fi

    if [ ${#INPUT_TESTINFO_OBJECT} -gt 0 ]
    then
        if [ ! -e "$INPUT_TESTINFO_OBJECT" ]
        then
         error "file with \"test\" JSON object not found ($INPUT_TESTINFO_OBJECT)"
        fi
        curl $CURL_OPTS -H "Content-Type: multipart/form-data" -u $INPUT_JIRA_USERNAME:$INPUT_JIRA_PASSWORD -F "file=@$INPUT_FILE" -F "info=@$INPUT_INFO_OBJECT" -F "testInfo=@$INPUT_TESTINFO_OBJECT" "$INPUT_JIRA_URL/rest/raven/1.0/import/execution/$INPUT_REPORT/multipart"
    else
        curl $CURL_OPTS -H "Content-Type: multipart/form-data" -u $INPUT_JIRA_USERNAME:$INPUT_JIRA_PASSWORD -F "file=@$INPUT_FILE" -F "info=@$INPUT_INFO_OBJECT" "$INPUT_JIRA_URL/rest/raven/1.0/import/execution/$INPUT_REPORT/multipart"
    fi

  fi
else
 #  Xray CLOUD
 token=""

 if [ ${#INPUT_CLOUD_AUTH_FILE} -gt 0 ] #&& [ ! -e "$INPUT_CLOUD_AUTH_FILE" ]
 then
    if [ ! -e "$INPUT_CLOUD_AUTH_FILE" ]
    then
        error "file with Xray's Cloud client_id and client_secret was not found ($INPUT_CLOUD_AUTH_FILE)"
    else
        token=$(curl $CURL_OPTS -H "Content-Type: application/json" -X POST --data @"$INPUT_CLOUD_AUTH_FILE" "$XRAY_CLOUD_ENDPOINT/api/v1/authenticate"| tr -d '"')
    fi
 else
    if [ -n "$INPUT_CLIENT_ID" ] && [ -n "$INPUT_CLIENT_SECRET" ]
    then
        CLOUD_AUTH_STR="{ \"client_id\": \"$INPUT_CLIENT_ID\",\"client_secret\": \"$INPUT_CLIENT_SECRET\" }"
        #echo "CLOUD_AUTH_STR: $CLOUD_AUTH_STR"
        token=$(curl $CURL_OPTS -H "Content-Type: application/json" -X POST --data "$CLOUD_AUTH_STR" "$XRAY_CLOUD_ENDPOINT/api/v1/authenticate"| tr -d '"')
    else
        error "Client ID and Client Secret must be both specified"
    fi
 fi

 test $? == 0 || error "failed to obtain token. Please check credentials."

 if [ "$INPUT_MULTIPART" -ne 1 ]
  then
    # standard endpoints

    if [ "$INPUT_REPORT" == "cucumber" ] || [ "$INPUT_REPORT" == "behave" ]
    then
        curl $CURL_OPTS -H "Content-Type: application/json" -X POST -H "Authorization: Bearer $token" --data @"$INPUT_FILE" "$XRAY_CLOUD_ENDPOINT/api/v1/import/execution/$INPUT_REPORT"
    else
        GET_PARAMS=$(build_get_params)
        # TO DO: fix hardcoded xml content type; is it needed at all?
        curl $CURL_OPTS -H "Content-Type: text/xml" -X POST -H "Authorization: Bearer $token" --data @"$INPUT_FILE" "$XRAY_CLOUD_ENDPOINT/api/v1/import/execution/$INPUT_REPORT?$GET_PARAMS"
    fi

  else
    # multipart endpoints    

    if [ ! -e "$INPUT_INFO_OBJECT" ]
    then
     error "file with \"test\" JSON object not found ($INPUT_INFO_OBJECT)"
    fi

    if [ ${#INPUT_TESTINFO_OBJECT} -gt 0 ]
    then
        if [ ! -e "$INPUT_TESTINFO_OBJECT" ]
        then
         error "file with \"test\" JSON object not found ($INPUT_TESTINFO_OBJECT)"
        fi
        curl $CURL_OPTS -H "Content-Type: multipart/form-data" -X POST -H "Authorization: Bearer $token"  -F "results=@$INPUT_FILE" -F "info=@$INPUT_INFO_OBJECT" -F "testInfo=@$INPUT_TESTINFO_OBJECT" "$XRAY_CLOUD_ENDPOINT/api/v1/import/execution/$INPUT_REPORT/multipart"
    else
        curl $CURL_OPTS -H "Content-Type: multipart/form-data" -X POST -H "Authorization: Bearer $token"  -F "results=@$INPUT_FILE" -F "info=@$INPUT_INFO_OBJECT" "$XRAY_CLOUD_ENDPOINT/api/v1/import/execution/$INPUT_REPORT/multipart"
    fi

  fi
fi
 
