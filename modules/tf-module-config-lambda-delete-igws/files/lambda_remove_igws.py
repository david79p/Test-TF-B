import os
import boto3
import json

aws_request_id = None
sns_topic_arn = None

APPLICABLE_RESOURCES = ["AWS::EC2::InternetGateway"]


def write_log(message):
    prefix = ""
    if aws_request_id is not None:
        prefix = "RID={rid}: ".format(rid=aws_request_id)
    print("{p}{msg}".format(p=prefix, msg=message))


def detach_igw(igw, vpc):
    client = boto3.client('ec2')
    try:
        write_log("[INFO] Attempting to detach {igw} from {vpc}".format(igw=igw, vpc=vpc))
        client.detach_internet_gateway(
            DryRun=False,
            InternetGatewayId=igw,
            VpcId=vpc
        )
    except Exception as ex:
        message = "Exception while detaching {igw}: {msg}".format(igw=igw, msg=ex)
        write_log("[ERROR] {msg}".format(msg=message))


def delete_igw(igw):
    client = boto3.client('ec2')

    result = {
        "compliance_type": "NON_COMPLIANT",
        "annotation": "Internet Gateway is present"
    }

    try:
        client.delete_internet_gateway(
            DryRun=False,
            InternetGatewayId=igw
        )
    except Exception as ex:
        message = "Exception while detaching {igw}: {msg}".format(igw=igw, msg=ex)
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

    igw_id = configuration_item['resourceId']

    for item in configuration_item['relationships']:
        if 'vpc-' in item['resourceId']:
            write_log("[INFO] Found igw: {iid}".format(iid=igw_id))
            detach_igw(igw_id, item['resourceId'])

    result = delete_igw(igw_id)

    return result


def get_env_vars():
    global sns_topic_arn
    try:
        sns_topic_arn = os.environ["SNSTopicARN"].strip()
    except Exception as ex:
        write_log("[WARNING] The 'SNSTopicARN' environment variable " +
                  "could not be read: {msg}. ".format(msg=ex) +
                  "Notifications will not be active.")
        sns_topic_arn = None
    return True


def send_notification(configuration_item, evaluation):
    if sns_topic_arn is None:
        write_log("[INFO] No SNS topic has been configured. Notifications " +
                  "will not be sent.")
        return False
    try:
        sns = boto3.client('sns')
        igw_id = configuration_item["resourceId"]
        notif_subject = "Remove IGWs: " + \
                        "{igw} ".format(igw=igw_id) + \
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
