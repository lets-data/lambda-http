# import the aws lambda python image
FROM public.ecr.aws/lambda/python:3.9

# Copy requirements.txt
COPY requirements.txt ${LAMBDA_TASK_ROOT}

# Install the specified packages
RUN pip --no-cache-dir install -r requirements.txt

# Copy function code
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# uncomment to copy code files in folders in the repo
# RUN mkdir -p ${LAMBDA_TASK_ROOT}/<folder_name>
# COPY <folder_name>/ ${LAMBDA_TASK_ROOT}/<folder_name>/

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda_function.lambda_handler" ]