FUNCTION_NAME=$1
IMAGE_URI=$2

echo 'deploy functionName: '$FUNCTION_NAME', imageUri: '$IMAGE_URI
if [[ -z "${FUNCTION_NAME}" || -z "${IMAGE_URI}" ]]; then
    echo "invalid args"
    echo "usage: ./deploy.sh <FUNCTION_NAME>  <IMAGE_URI>"
    echo "example: ./deploy.sh TestWebFunction 243972917462.dkr.ecr.us-east-1.amazonaws.com/lambda_examples:latest"
    exit -1
fi

IAM_ROLE_NAME=$FUNCTION_NAME"IAMRole"

echo "########## starting deploy  ##############"

# Create Lambda Function ExecutionRole - https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html#permissions-executionrole-api
CREATE_IAM_ROLE_RESPONSE=`aws iam create-role --role-name $IAM_ROLE_NAME --assume-role-policy-document '{"Version": "2012-10-17","Statement": [{ "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}' 2>&1`
if [[ $CREATE_IAM_ROLE_RESPONSE == *"An error occurred (EntityAlreadyExists) when calling the CreateRole operation: Role with name $IAM_ROLE_NAME already exists"* ]]; then
    IAM_ROLE_ARN=`aws iam get-role --role-name $IAM_ROLE_NAME  | jq -r .Role.Arn`
else
    IAM_ROLE_ARN=`echo $CREATE_IAM_ROLE_RESPONSE | jq -r .Role.Arn`
fi
echo "created IAM Role $IAM_ROLE_ARN"

aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Sleep for this error "An error occurred (InvalidParameterValueException) when calling the CreateFunction operation: The role defined for the function cannot be assumed by Lambda."
sleep 5

# create function
CREATE_FUNCTION_RESPONSE=`aws lambda create-function --function-name $FUNCTION_NAME --role $IAM_ROLE_ARN --package-type Image --code ImageUri=$IMAGE_URI --environment Variables="{EnvVar1=Test}" --timeout 15 --memory-size 3008 --publish  2>&1`
if [[ $CREATE_FUNCTION_RESPONSE == *"An error occurred (ResourceConflictException) when calling the CreateFunction operation: Function already exist"* ]]; then
    echo "Updating existing function with new image"
    aws lambda update-function-code --function-name $FUNCTION_NAME --image-uri $IMAGE_URI
    echo "Updated existing function with new image successfully"
    FUNCTION_ARN=`aws lambda get-function --function-name $FUNCTION_NAME | jq  -r .Configuration.FunctionArn`
else
    echo "Created a new function $FUNCTION_NAME"
    echo $CREATE_FUNCTION_RESPONSE
    FUNCTION_ARN=`echo $CREATE_FUNCTION_RESPONSE | jq  -r .FunctionArn`
fi

echo "Function Arn "$FUNCTION_ARN   
aws lambda add-permission --function-name $FUNCTION_ARN --principal "*" --statement-id "addInvokeFunctionUrlPermission" --action lambda:InvokeFunctionUrl --function-url-auth-type NONE

# create function url - https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html
FUNCTION_URL_RESPONSE=`aws lambda create-function-url-config --function-name $FUNCTION_NAME --auth-type NONE  2>&1`
if [[ $FUNCTION_URL_RESPONSE == *"FunctionUrlConfig exists for this Lambda function"* ]]; then
    FUNCTION_URL=`aws lambda get-function-url-config --function-name $FUNCTION_NAME | jq  -r .FunctionUrl`
else 
    FUNCTION_URL=`echo $FUNCTION_URL_RESPONSE| jq  -r .FunctionUrl`
fi

echo "function url $FUNCTION_URL"

echo "curl $FUNCTION_URL -d '{\"requestId\": \"id1\", \"data\": {\"var1\": \"value1\", \"var2\": \"value2\", \"var3\": \"value3\", \"var4\": \"value4\"}}'"
CURL_RESPONSE=`curl -s $FUNCTION_URL -d '{"requestId": "id1", "data": {"var1": "value1", "var2": "value2", "var3": "value3", "var4": "value4"}}'`
if [[ $CURL_RESPONSE == *'The server timed out before completing your request'* ]]; then
    echo "response not expected - sleeping 15 secs and try again"
    sleep 15
    CURL_RESPONSE=`curl -s $FUNCTION_URL -d '{"requestId": "id1", "data": {"var1": "value1", "var2": "value2", "var3": "value3", "var4": "value4"}}'`
fi 

if [[ $CURL_RESPONSE == *'{"headers":{"Content-Type":"application\/json"},"body":{"data":{"var2Returned":"value2returned","var3Returned":"value3returned","var1Returned":"value1returned","var4Returned":"value4returned"},"requestId":"id1","statusCode":"SUCCESS"},"StatusCode":200}'* ]]; then
    echo "curl response validated"
else 
    echo "curl response incorrect - response: "$CURL_RESPONSE
fi


