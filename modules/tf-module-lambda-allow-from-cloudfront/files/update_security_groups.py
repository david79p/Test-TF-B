'''
Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License"). You may not use
this file except in compliance with the License. A copy of the License is
located at

    http://aws.amazon.com/apache2.0/

or in the "license" file accompanying this file. This file is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and
limitations under the License.
'''

import boto3
import hashlib
import json
import urllib2
import os

if "region" not in os.environ or os.environ["region"] == "":
    raise EnvironmentError("Missing region environment variable.")

# Tags which identify the security groups you want to update
if "sg_name" not in os.environ or os.environ["sg_name"] == "":
    sg_name = 'Cloudfront'
else:
    sg_name = os.environ["sg_name"]

SECURITY_GROUP_TAG_FOR_GENERIC = {'Name': sg_name, 'AutoUpdate': 'true'}


def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    message = json.loads(event['Records'][0]['Sns']['Message'])

    # Load the ip ranges from the url
    ip_ranges = json.loads(get_ip_groups_json(message['url'], message['md5']))

    # update the security groups
    result = update_security_groups(ip_ranges)

    return result


def get_ip_groups_json(url, expected_hash):
    print("Updating from " + url)

    response = urllib2.urlopen(url)
    ip_json = response.read()

    m = hashlib.md5()
    m.update(ip_json)
    hash = m.hexdigest()

    if hash != expected_hash:
        raise Exception('MD5 Mismatch: got ' + hash + ' expected ' +
                        expected_hash)

    return ip_json


def get_ranges_for_service(ranges, service):
    service_ranges = list()
    for prefix in ranges['prefixes']:
        if prefix['service'] == service:
            print('Found ' + service + ' range: ' + prefix['ip_prefix'])
            service_ranges.append(prefix['ip_prefix'])

    return service_ranges


def update_security_groups(ip_ranges):
    client = boto3.client('ec2', region_name=os.environ["region"])
    result = list()

    groups = get_security_groups_for_update(client,
                                            SECURITY_GROUP_TAG_FOR_GENERIC)

    print ('Found ' + str(len(groups)) + ' to update')
    for group in groups:
        tags = {}
        for t in group['Tags']:
            tmp = {t.get('Key'): t.get('Value')}
            tags.update(tmp)

        # Legacy was cloudfront, so if nothing is set, assume we have a Legacy
        # group
        service = "CLOUDFRONT"
        if "Service" in tags:
            service = tags['Service'].upper()
        new_ranges = get_ranges_for_service(ip_ranges, service)

        params = get_params_for_tags(tags)

        if update_security_group(client, group, new_ranges, params['Port'],
                                 params['Proto']):
            result.append('Updated ' + group['GroupId'])
    return result


def get_params_for_tags(tags):
    # Discard Protocol
    params = {'Port': 9, 'Proto': 'UDP'}
    if 'Proto' in tags and 'Port' in tags:
        try:
            params['Proto'] = tags['Proto']
            params['Port'] = int(tags['Port'])
        except ValueError:
            print "Value Error"
            pass
    else:
        print "Legacy group detected"
        if 'Protocol' in tags:
            if tags['Protocol'].lower() == 'http':
                params = {'Port': 80, 'Proto': 'TCP'}
            else:
                if tags['Protocol'].lower() == 'https':
                    params = {'Port': 443, 'Proto': 'TCP'}
                else:
                    print "setup failure!! using safe default of discard proto"
        else:
            print "setup failure!! using safe default of discard proto"
    return params


def update_security_group(client, group, new_ranges, port, proto):
    added = 0
    removed = 0
    if len(group['IpPermissions']) > 0:
        for permission in group['IpPermissions']:
            if permission['FromPort'] <= port and permission['ToPort'] >= port:
                old_prefixes = list()
                to_revoke = list()
                to_add = list()
                for range in permission['IpRanges']:
                    cidr = range['CidrIp']
                    old_prefixes.append(cidr)
                    if new_ranges.count(cidr) == 0:
                        to_revoke.append(range)
                        print(group['GroupId'] + ": Revoking " + cidr + ":" +
                              str(permission['ToPort']))

                for range in new_ranges:
                    if old_prefixes.count(range) == 0:
                        to_add.append({'CidrIp': range})
                        print(group['GroupId'] + ": Adding " + range + ":" +
                              str(permission['ToPort']))

                removed += revoke_permissions(client, group, permission,
                                              to_revoke)
                added += add_permissions(client, group, permission, to_add)
    else:
        to_add = list()
        for range in new_ranges:
            to_add.append({'CidrIp': range})
            print(group['GroupId'] + ": Adding " + range + ":" + str(port))
        permission = {'ToPort': port, 'FromPort': port, 'IpProtocol': proto}
        added += add_permissions(client, group, permission, to_add)

    print (group['GroupId'] + ": Added " + str(added) + ", Revoked " +
           str(removed))
    return (added > 0 or removed > 0)


def revoke_permissions(client, group, permission, to_revoke):
    if len(to_revoke) > 0:
        revoke_params = {
            'ToPort': permission['ToPort'],
            'FromPort': permission['FromPort'],
            'IpRanges': to_revoke,
            'IpProtocol': permission['IpProtocol']
        }

        client.revoke_security_group_ingress(GroupId=group['GroupId'],
                                             IpPermissions=[revoke_params])

    return len(to_revoke)


def add_permissions(client, group, permission, to_add):
    if len(to_add) > 0:
        add_params = {
            'ToPort': permission['ToPort'],
            'FromPort': permission['FromPort'],
            'IpRanges': to_add,
            'IpProtocol': permission['IpProtocol']
        }

        client.authorize_security_group_ingress(GroupId=group['GroupId'],
                                                IpPermissions=[add_params])

    return len(to_add)


def get_security_groups_for_update(client, security_group_tag):
    filters = list()
    for key, value in security_group_tag.iteritems():
        filters.extend(
            [
                {'Name': "tag-key", 'Values': [key]},
                {'Name': "tag-value", 'Values': [value]}
            ]
        )

    response = client.describe_security_groups(Filters=filters)

    return response['SecurityGroups']


'''
Sample Event From SNS:

{
  "Records": [
    {
      "EventVersion": "1.0",
      "EventSubscriptionArn": "arn:aws:sns:EXAMPLE",
      "EventSource": "aws:sns",
      "Sns": {
        "SignatureVersion": "1",
        "Timestamp": "1970-01-01T00:00:00.000Z",
        "Signature": "EXAMPLE",
        "SigningCertUrl": "EXAMPLE",
        "MessageId": "95df01b4-ee98-5cb9-9903-4c221d41eb5e",
        "Message": "{\"create-time\": \"yyyy-mm-ddThh:mm:ss+00:00\",
        \"synctoken\": \"0123456789\",
        \"md5\": \"03a8199d0c03ddfec0e542f8bf650ee7\",
        \"url\": \"https://ip-ranges.amazonaws.com/ip-ranges.json\"}",
        "Type": "Notification",
        "UnsubscribeUrl": "EXAMPLE",
        "TopicArn": "arn:aws:sns:EXAMPLE",
        "Subject": "TestInvoke"
      }
    }
  ]
}

'''
