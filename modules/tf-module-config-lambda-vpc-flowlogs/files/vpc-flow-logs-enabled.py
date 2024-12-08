import os
import boto3
import json

aws_request_id = None
flow_logs_iam_role_arn = None
flow_logs_traffic_type = None
sns_topic_arn = None

APPLICABLE_RESOURCES = ["AWS::EC2::VPC"]

def write_log(message):
    prefix = ""
    if aws_request_id is not None:
        prefix = "RID={rid}: ".format(rid=aws_request_id)
    print("{p}{msg}".format(p=prefix, msg=message))


def get_region_from_arn(arn):
    return arn.split(":")[3]

    
def get_env_vars():
    global flow_logs_iam_role_arn
    try:
        flow_logs_iam_role_arn = os.environ["FlowLogsIAMRoleARN"].strip()
    except Exception as ex:
        write_log("[ERROR] The 'FlowLogsIAMRoleARN' environment variable " +
                  "could not be read: {msg}".format(msg=ex))
        return False
    if flow_logs_iam_role_arn is None or flow_logs_iam_role_arn == "":
        write_log("[ERROR] The 'FlowLogsIAMRoleARN' environment variable is " + 
                  "required, but not set.")
        return False
        
    global flow_logs_traffic_type
    try:
        flow_logs_traffic_type = os.environ["FlowLogsTrafficType"].strip()
    except Exception as ex:
        write_log("[WARNING] The 'FlowLogsTrafficType' environment variable " +
                  "could not be read: {msg}. ".format(msg=ex) +
                  "Using default value 'ALL'.")
        flow_logs_traffic_type = "ALL"
    if (flow_logs_traffic_type is None or 
        flow_logs_traffic_type not in ['ACCEPT', 'REJECT', 'ALL']):
        write_log("[WARNING] The 'FlowLogsTrafficType' environment variable " +
                  "is set to an invalid value: " +
                  "'{val}'. ".format(val=flow_logs_traffic_type) +
                  "Using default value 'ALL'.")
        flow_logs_traffic_type = "ALL"
        
    global sns_topic_arn
    try:
        sns_topic_arn = os.environ["SNSTopicARN"].strip()
    except Exception as ex:
        write_log("[WARNING] The 'SNSTopicARN' environment variable " + 
                  "could not be read: {msg}. ".format(msg=ex) +
                  "Notifications will not be active.")
        sns_topic_arn = None
    return True


def configure_vpc_flow_logs(vpc_id, ec2client):
    result = {
        "compliance_type": "NON_COMPLIANT",
        "annotation": "Flow logs are not enabled yet."
    }
    # Enable Flow logs
    log_group_name = vpc_id + "-flow-logs"
    try:
        response = ec2client.create_flow_logs(
                DeliverLogsPermissionArn=flow_logs_iam_role_arn,
                LogGroupName=log_group_name,
                ResourceIds=[vpc_id],
                ResourceType="VPC",
                TrafficType=flow_logs_traffic_type
            )
        if len(response["Unsuccessful"]) > 0:
            message = "Failed to configure flow logs for " + \
                      "{vid}: {msg}".format(
                          vid=vpc_id,
                          msg=response["Unsuccessful"][0]["Error"]["Message"]
                      )
            write_log("[ERROR] {msg}".format(msg=message))
            result = {
                "compliance_type": "NON_COMPLIANT",
                "annotation": message
            }
        else:
            write_log("[INFO] New flow logs configuration created " + 
                      "successfully.")
            message = "Flow logs have been enabled for " + \
                      "{vid}. ".format(vid=vpc_id) + \
                      "Streaming to ElasticSearch service must be enabled " + \
                      "manually from the AWS Web Console."
            result = {
                "compliance_type": "NON_COMPLIANT",
                "annotation": message
            }
    except Exception as ex:
        message = "Exception while configuring flow logs for " + \
                  "{vid}: {msg}".format(vid=vpc_id, msg=ex)
        write_log("[ERROR] {msg}".format(msg=message))
        result ={
            "compliance_type": "NON_COMPLIANT",
            "annotation": message
        }
    return result
    
    
def check_vpc_flow_logs(vpc_id):
    result = {
        "compliance_type": "NON_COMPLIANT",
        "annotation": "Flow logs configuration not checked yet."
    }
    ec2 = boto3.client('ec2')
    try:
        response = ec2.describe_flow_logs(
            Filters=[
                {
                    "Name": "resource-id",
                    "Values": [vpc_id]
                }
            ]
        )
        write_log("[INFO] VPC flow log result: {res}".format(res=response))
        if len(response["FlowLogs"]) == 0:
            # No flow logs configured. Try to create the configuration
            write_log("[INFO] No flow logs configured. Trying to create " +
                      "the configuration.")
            result = configure_vpc_flow_logs(vpc_id, ec2)
        else:
            write_log("[INFO] Flow logs are already configured for " +
                      "{vid}".format(vid=vpc_id))
            result = {
                "compliance_type": "COMPLIANT",
                "annotation": "The VPC has its flow logs already enabled. " + \
                    "Streaming to ElasticSearch cannot be verified."
            }
    except Exception as ex:
        message = "Exception while checking the existing flow logs " + \
                  "configuration: {msg}".format(msg=ex)
        write_log("[ERROR] {msg}".format(msg=message))
        result = {
            "compliance_type": "NON_COMPLIANT",
            "annotation": message
        }
        
    return result
    
    
def evaluate_compliance(configuration_item):
    if configuration_item["resourceType"] not in APPLICABLE_RESOURCES:
        return {
            "compliance_type": "NOT_APPLICABLE",
            "annotation": "The rule doesn't apply to resources of type " +
            configuration_item["resourceType"] + "."
        }

    if configuration_item['configurationItemStatus'] == "ResourceDeleted":
        return {
            "compliance_type": "NOT_APPLICABLE",
            "annotation": "The configurationItem was deleted " +
                          "and therefore cannot be validated"
        }
    
    vpc_id = configuration_item['resourceId']
    write_log("[INFO] Checking flow logs configuration for {vid}".format(
                  vid=vpc_id
             ))
    result = check_vpc_flow_logs(vpc_id)
    return result
    
    
def send_notification(configuration_item, evaluation):
    if sns_topic_arn is None or sns_topic_arn == "":
        write_log("[INFO] No SNS topic has been configured. Notifications " + 
                  "will not be sent.")
        return False
    try:
        sns_region = get_region_from_arn(sns_topic_arn)
        sns = boto3.client('sns', region_name=sns_region)
        vpc_id = configuration_item["resourceId"]
        notif_subject = "VPC Flow Logs Governance: " + \
                        "{vpc} ".format(vpc=vpc_id) + \
                        "is " + \
                        "{status}".format(status=evaluation["compliance_type"])
        notif_message = evaluation["annotation"]
        sns.publish(TopicArn=sns_topic_arn, Message=notif_message,
                    Subject=notif_subject)
    except Exception as ex:
        write_log("[ERROR] Sending of an SNS notification has failed: " + 
                  "{msg}".format(msg=ex))
        return False
    return True


def lambda_handler(event, context):
    global aws_request_id
    aws_request_id = context.aws_request_id
    
    write_log("[INFO] Received event: {evt}".format(evt=event))
    
    invoking_event = json.loads(event["invokingEvent"])
    configuration_item = invoking_event["configurationItem"]

    result_token = "No token found."
    if "resultToken" in event:
        result_token = event["resultToken"]
        
    if not get_env_vars():
        write_log("[ERROR] Incorrect Lambda configuration. Exiting ...")
        evaluation = {
            "compliance_type": "NOT_APPLICABLE",
            "annotation": "Incorrect Lambda configuration."
        }
    else:
        evaluation = evaluate_compliance(configuration_item)
    
    config_evaluations = [
            {
                "ComplianceResourceType":
                    configuration_item["resourceType"],
                "ComplianceResourceId":
                    configuration_item["resourceId"],
                "ComplianceType":
                    evaluation["compliance_type"],
                "Annotation":
                    evaluation["annotation"],
                "OrderingTimestamp":
                    configuration_item["configurationItemCaptureTime"]
            },
        ]
    write_log("[INFO] Evaluation result: {er}. Details: {detail}".format(
            er=evaluation["compliance_type"],
            detail=evaluation["annotation"]
        ))
    
    config = boto3.client("config")
    config.put_evaluations(
        Evaluations=config_evaluations,
        ResultToken=result_token
    )
    
    if evaluation["compliance_type"] == "NON_COMPLIANT":
        send_notification(configuration_item, evaluation)
    
    return True
