#!/bin/sh

AWS_ACCOUNT_ID=$1
REPOSITORY_NAME=$2
IMAGE_TAG=$3
echo 'build awsAccountId: '$AWS_ACCOUNT_ID', repoName: '$REPOSITORY_NAME', imageTag: '$IMAGE_TAG
if [[ -z "${AWS_ACCOUNT_ID}" || -z "${REPOSITORY_NAME}" || -z "${IMAGE_TAG}" ]]; then
    echo "invalid args"
    echo "usage: ./build.sh <AWS_ACCOUNT_ID> <REPOSITORY_NAME> <IMAGE_TAG>"
    echo "example: ./build.sh 243972917462 lambda_examples test"
    exit -1
fi

echo "########## starting docker build  ##############"

aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
CREATE_REPO_RESPONSE=`aws ecr create-repository --repository-name $REPOSITORY_NAME --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE`
if [[ $CREATE_REPO_RESPONSE == *"already exists in the registry"* ]]; then
    $REPOSITORY_URI=`echo $CREATE_REPO_RESPONSE | jq .repository.repositoryUri`
else
    REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/$REPOSITORY_NAME
fi

echo "retrieved repository uri: "$REPOSITORY_URI

echo "building image using dockerfile"
docker build --platform linux/amd64 -t $REPOSITORY_NAME:$IMAGE_TAG -f dockerfile .

echo "running docker "$REPOSITORY_NAME
docker run -e IMAGE_TAG=$IMAGE_TAG -p 9000:8080 $REPOSITORY_NAME:$IMAGE_TAG &

# sleep for 5 seconds, allows the docker container to be initialized. If we dont do this, in race condition, the container could not be initialized and docker ps returns null
sleep 5

# list docker processes and get the running container's container id
CONTAINER_ID=`docker ps|grep $REPOSITORY_NAME:$IMAGE_TAG|cut -d ' ' -f 1`

# list docker processes and get the running container's image id
IMAGE_ID=`docker ps|grep $REPOSITORY_NAME:$IMAGE_TAG|cut -d ' ' -f 4`

# we need the container / image id to terminate the containers at the end of the script
echo 'containerId: '$CONTAINER_ID', imageId: '$IMAGE_ID

echo "test $REPOSITORY_NAME"

# run a quick success test
# body is base64 encoding for the string '{"requestId": "id1", "data": {"var1": "value1", "var2": "value2", "var3": "value3", "var4": "value4"}}'
SUCCESS_TEST_RESPONSE=`curl "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"body": "eyJyZXF1ZXN0SWQiOiAiaWQxIiwgImRhdGEiOiB7InZhcjEiOiAidmFsdWUxIiwgInZhcjIiOiAidmFsdWUyIiwgInZhcjMiOiAidmFsdWUzIiwgInZhcjQiOiAidmFsdWU0In19"}'`

# run a quick error test
# body is base64 encoding for the string '{"requestId": "id1", "data": {"var1": "value1", "var2": 2, "var3": "value3", "var4": "value4"}}'
ERROR_TEST_RESPONSE=`curl "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"body": "eyJyZXF1ZXN0SWQiOiAiaWQxIiwgImRhdGEiOiB7InZhcjEiOiAidmFsdWUxIiwgInZhcjIiOiAyLCAidmFyMyI6ICJ2YWx1ZTMiLCAidmFyNCI6ICJ2YWx1ZTQifX0="}'`

echo "killing $REPOSITORY_NAME container"
docker kill $CONTAINER_ID
docker rm $CONTAINER_ID

if [[ $SUCCESS_TEST_RESPONSE == '{"StatusCode": 200, "headers": {"Content-Type": "application/json"}, "body": {"statusCode": "SUCCESS", "requestId": "id1", "data": {"var1Returned": "value1returned", "var2Returned": "value2returned", "var3Returned": "value3returned", "var4Returned": "value4returned"}}}' ]]; then
    echo "$REPOSITORY_NAME success test passed"
else
    echo "$REPOSITORY_NAME success test response is not expected"
    echo "response: "$SUCCESS_TEST_RESPONSE
    ERROR=TRUE
fi

if [[ $ERROR_TEST_RESPONSE == *'{"StatusCode": 500, "headers": {"Content-Type": "application/json"}, "body": {"statusCode": "EXCEPTION", "errorMessage": "var2 is invalid - body.data.var2 should be a non empty str", "exception": {"errorMessage": "var2 is invalid - body.data.var2 should be a non empty str"'* ]]; then
    echo "$REPOSITORY_NAME error test passed"
else
    echo "$REPOSITORY_NAME error test response is not expected"
    echo "response: "$ERROR_TEST_RESPONSE
    ERROR=TRUE
fi

if [[ $ERROR == *"TRUE"* ]]; then
    exit 1
else
    echo "all tests passed"
fi

echo "uploading to ecr repo $REPOSITORY_URI:latest"
docker tag $REPOSITORY_NAME:$IMAGE_TAG $REPOSITORY_URI:latest
docker push $REPOSITORY_URI:latest

#aws lambda update-function-code --function-name TestLetsDataPythonInterfaceLambdaFunction --image-uri 223413462631.dkr.ecr.us-east-1.amazonaws.com/letsdata_python_functions:latest
#aws lambda invoke --function-name TestLetsDataPythonInterfaceLambdaFunction --invocation-type RequestResponse --payload eyJyZXF1ZXN0SWQiOiI2NWZmZjAwYi00NjBjLTQwNTUtYTE3MS1mMGE4YzJlNGFlMjIiLCJpbnRlcmZhY2UiOiJTaW5nbGVGaWxlUGFyc2VyIiwiZnVuY3Rpb24iOiJnZXRTM0ZpbGVUeXBlIiwibGV0c2RhdGFBdXRoIjp7InRlbmFudElkIjoiM2MyNWJkYmQtYzJiMS00Yjc0LTlmNmEtYjE4ZDIzZTZhZGUxIiwidXNlcklkIjoiZGU5ZWI1YTYtYTA2Zi00MjlmLThmNzUtOWE0MzhmZTA3M2UxIiwiZGF0YXNldE5hbWUiOiJDb21tb25DcmF3bERhdGFzZXQiLCJkYXRhc2V0SWQiOiI3OGNlMGFhMi05YjhjLTQ1MzQtOTE3MC00NDVkMmNmZDcwYWYifSwiZGF0YSI6e319 ./out

docker rmi $IMAGE_ID
echo "use image-uri $REPOSITORY_URI:latest to create / update the lambda function"
echo "########## $REPOSITORY_NAME built ##############"
echo "########################"
echo "########################"
echo "########################"