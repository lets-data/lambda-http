# Deploy AWS Lambda Function Code and Enable Http Access
This is an example repository that can be used to deploy python lambda function and enable it for public http web access. 

The lambda code has stub implementation already so you can test that this works with that stub implementation. 

## Test The Stub Implementation
Here is how to test it with stub implementation working:

### Pre-Requisites
* Assumes mac osx / linux dev env
* Assumes Docker is installed (https://www.docker.com/)
* Assumes AWS CLI is installed and configured with the AWS Account where the function needs to be deployed. Assumes us-east-1 region. Also, customer should know their aws accound id.  (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* Assumes json query is installed and is included in the path. (https://jqlang.github.io/jq/)
* Git is installed and setup. (https://git-scm.com/)

### Steps to get the stubs working
* Clone the github repo (https://github.com/lets-data/lamda-http)
* **Build:** Make sure docker is running on the machine. Run the ```build.sh``` to 1./ build the docker container 2./ run the docker container 3./ run some curl requests to make sure that the lambda function is working correctly. 
```
./build.sh <AWS_ACCOUNT_ID> <REPOSITORY_NAME> <IMAGE_TAG>"

AWS_ACCOUNT_ID: the aws account where the ecr image repo would be created and the docker image uploaded. This is your aws account id
REPOSITORY_NAME: Give the repo a friendly name. We suggest 'lambda_examples'
IMAGE_TAG: Tag the image with an identifier. This is the tag for the build on the docker system on the desktop. We suggest 'test'. The ecr image that will be uploaded will be taggged as the 'latest' image tag though. 

Example:
--------
./build.sh 243972917462 lambda_examples test"
```
* **Deploy:** Copy the ecr image uri from the build step output. Run the ```deploy.sh``` to 1./ create an IAM role and policy for the lambda function if it does not exist 2./ create or update the lambda function with the image uri 3./ Add the InvokeFunctionUrl permissions 4./ Create the Function Url Config 5./ Post a curl request to make sure response is expected.  
```
./deploy.sh <FUNCTION_NAME>  <IMAGE_URI>"
    
FUNCTION_NAME: Give the function a name. We suggest 'TestWebLambdaFunction'
IMAGE_URI: Image Uri from the previous step. For example 243972917462.dkr.ecr.us-east-1.amazonaws.com/lambda_examples:latest

Example:
--------
./deploy.sh TestWebLambdaFunction 243972917462.dkr.ecr.us-east-1.amazonaws.com/lambda_examples:latest
```
* Deploy.sh should output a curl command that you can use to call the function. 

## Customize the code 
* Look at the ```lambda_function.py``` - it defines the body format in the comments, this is essentially whatever you'd be posting to this url. Make sure to rework the parsing code accordingly. 
* ```customer_python_code``` is a dummy function where you could add your custom code. However, the event parsing code which is in the ```lambda_handler function``` would also need customization. 
* In case you want to install additional python libraries, specify them in ```requirements.txt```, one library on each line. 
* In case you add additional code files / folders, remember to add them as COPY commands in the ```dockerfile```. 
* Gotchas:
  * When you change the event format, be sure to define `success test and error test request and responses in build.sh` (or comment them if not needed). These would need to be specified as `base64` encoded strings. Just construct the string and run it via  base64 encoder online. You can also `run the lambda_function as python code in VSCode IDE` for quick debugging (I've left the function call in the code at the end)
  * You'll also need to `update the curl post data in deploy.sh` or comment it if not needed. 
* This setup exposes the lambda as a public url. In case you'd need authentication, change the auth type to IAM, update the lambda permissions in deploy.sh and update the curl calls accordingly. See (Create: https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html , Autheticate: https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html , Invoke: https://docs.aws.amazon.com/lambda/latest/dg/urls-invocation.html#urls-invocation-basics)
```
aws lambda create-function-url-config --function-name my-function --auth-type AWS_IAM

aws lambda add-permission --function-name my-function --statement-id example0-cross-account-statement --action lambda:InvokeFunctionUrl --principal 444455556666 --function-url-auth-type AWS_IAM
```
* For the curious, this is a scoped down version of LetsData Python Interface package which does a whole lot more using similar infrastructure (https://github.com/lets-data/letsdata-python-interface)
* Issues? https://www.letsdata.io/#support