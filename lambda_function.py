import sys, traceback, base64, json
import logging

def setup_logging():
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    logging.getLogger('boto3').setLevel(logging.INFO)
    logging.getLogger('botocore').setLevel(logging.INFO)
    logging.getLogger('botocore.session').setLevel(logging.INFO)
    return logger

def customer_python_code(var1 : str, var2 : str, var3 : str, var4 : str): 
    return {
            "var1Returned": var1+"returned",
            "var2Returned": var2+"returned",
            "var3Returned": var3+"returned",
            "var4Returned": var4+"returned"
        }

'''
    event format:
    {
        body:  
        {
            "requestId": "requestId",
            "data": {
                "var1": "value1",
                "var2": "value2",
                "var3": "value3",
                "var4": "value4"
            }
        }
    }
'''
def lambda_handler(event, context):
    logger = setup_logging()
    logger.debug("lambda_handler start - event: "+str(event))
    try:
        if event is None:
            logger.error("lambda_handler - lambda event is null")
            raise(Exception("lambda event is null"))
        
        if 'body' not in event or event['body'] is None or not isinstance(event['body'], str):
            logger.error("lambda_handler - lambda event.body is null or not a str")
            raise(Exception("lambda event.body is null"))
        
        body = json.loads(base64.b64decode(event['body']))

        if 'requestId' not in body or body['requestId'] is None or not isinstance(body['requestId'], str):
            logger.error("lambda_handler - requestId is invalid - requestId should be a non empty str - requestId: "+str(requestId))
            raise(Exception("requestId is invalid - requestId should be a non empty str"))
        requestId : str = body['requestId']
        
        if 'data' not in body or body['data'] is None or not isinstance(body['data'], dict) or len(body['data']) != 4:
            logger.error("lambda_handler - body.data is invalid - body.data should be a dictionary and requires data keys [var1, var2, var3, var4] - data: "+str(data))
            raise(Exception("body.data is invalid - body.data should be a dictionary and requires data keys [var1, var2, var3, var4] "))
        data = body['data']
        
        if 'var1' not in data  or data['var1'] is None or not isinstance(data['var1'], str):
            logger.error("lambda_handler - var1 is invalid - body.data.var1 should be a non empty str")
            raise(Exception("var1 is invalid - body.data.var1 should be a non empty str"))
        var1 = data['var1'] 

        if 'var2' not in data  or data['var2'] is None or not isinstance(data['var2'], str):
            logger.error("lambda_handler - var2 is invalid - body.data.var2 should be a non empty str")
            raise(Exception("var2 is invalid - body.data.var2 should be a non empty str"))
        var2 = data['var2'] 

        if 'var3' not in data  or data['var3'] is None or not isinstance(data['var3'], str):
            logger.error("lambda_handler - var3 is invalid - body.data.var3 should be a non empty str")
            raise(Exception("var3 is invalid - body.data.var3 should be a non empty str"))
        var3 = data['var3'] 

        if 'var4' not in data  or data['var4'] is None or not isinstance(data['var4'], str):
            logger.error("lambda_handler - var4 is invalid - body.data.var4 should be a non empty str")
            raise(Exception("var4 is invalid - body.data.var4 should be a non empty str"))
        var4 = data['var4'] 

        responseObj : dict = customer_python_code(var1, var2, var3, var4)
        
        logger.debug("lambda_handler end - requestId: "+requestId+", response: "+str(responseObj))
        return {
            "StatusCode": 200,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": {
                "statusCode": "SUCCESS",
                "requestId": requestId,
                "data": responseObj
            }
        }
    except Exception as err:
        return {
            "StatusCode": 500,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": {
                "statusCode": "EXCEPTION",
                "errorMessage": str(err),
                "exception": {
                    "errorMessage": str(err),
                    "errorType": err.__class__.__name__,
                    "stackTrace": ''.join(traceback.format_exception(*(sys.exc_info())))
                }
            }
        }
    

event = {
    "body": "eyJyZXF1ZXN0SWQiOiAiaWQxIiwgImRhdGEiOiB7InZhcjEiOiAidmFsdWUxIiwgInZhcjIiOiAyLCAidmFyMyI6ICJ2YWx1ZTMiLCAidmFyNCI6ICJ2YWx1ZTQifQ=="
}
print(event)
result = lambda_handler(event=event, context=None)
print(result)