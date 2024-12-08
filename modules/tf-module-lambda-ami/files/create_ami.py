import boto3
import collections
import datetime
import time
import os
import copy
import logging

logging.basicConfig(level=os.environ.get('LOG_LEVEL', 'INFO'))
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

if "region" in os.environ and os.environ["region"] != "":
    # we have a region, so skip auto detection of current region
    ec = boto3.client('ec2', region_name=os.environ["region"])
else:
    ec = boto3.client('ec2')


def get_tags_for_ami(instance, retention_hours):
    delete_date = datetime.datetime.now() + datetime.timedelta(
        hours=retention_hours)
    cur_tags = boto3_tag_list_to_ansible_dict(instance.get('Tags', []))
    new_tags = copy.deepcopy(cur_tags)
    new_tags[os.environ.get('tagname', 'ApplicationRole')] = 'Backup'
    new_tags['DeleteOn'] = delete_date.strftime('%Y-%m-%d-%H')
    return new_tags


def get_tag_value(instance, tag_name, default_value, type_to_return=int):
    try:
        value = [
            t.get('Value') for t in instance['Tags']
            if t['Key'] == tag_name][0]
    except IndexError:
        value = default_value
    try:
        value = type_to_return(value)
    except ValueError:
        logger.warning("Tag {} could not be converted to {}! Using {} as a save default!".format(tag_name, type_to_return, default_value))
        value = type_to_return(default_value)
    return value


def get_environment(name, default):
    if name not in os.environ or os.environ[name] == "":
        raise EnvironmentError("Missing {} environment variable.".format(name))

    try:
        val = int(os.environ[name])
    except ValueError:
        logger.warning("Environment Parameter {} could not be converted to int! Using {} as a save default!".format(name, default))
        val = default
    return val


def check_backup_time(backup_times, current_hour):
    for t in backup_times.split(','):
        try:
            if int(t) == current_hour:
                return True
        except ValueError:
            logger.warning("Invalid backup times, defaulting create a backup every hour...")
            return True
    return False


def convert_retention(string):
    try:
        if string[-1] == 'h':
            hours = string[:-1].strip()
            return int(hours)
        if string[-1] == 'd':
            days = string[:-1].strip()
        else:
            days = string.strip()
        return int(days)*24
    except ValueError:
        logger.warning("Invalid retention {}, defaulting to 14 days".format(string))
        return 14*24


def get_retention_for_run(retentions, backup_times, current_hour):
    retentions = retentions.split(',')
    backup_times = backup_times.split(',')

    if len(retentions) == len(backup_times):
        # Same length -> one retention per backup time
        for k, t in enumerate(backup_times):
            if int(t) == current_hour:
                return convert_retention(retentions[k])
    if len(retentions) == 2:
        # First backup and all following
        for k, t in enumerate(backup_times):
            if int(t) == current_hour:
                if k == 0:
                    return convert_retention(retentions[0])
        return convert_retention(retentions[1])
    if len(retentions) > 1:
        logger.warning("retentions and backup_times do not match in length, nor is retention length 1 or 2, defaulting to first retention time.")
    return convert_retention(retentions[0])


def lambda_handler(event, context):
    try:
        default_retention = get_environment("retention", 14)
        default_backup_time = get_environment("default_time", 8)
        current_hour = datetime.datetime.now().hour
        reservations = ec.describe_instances(
            Filters=[
                {'Name': 'tag:Backup', 'Values': ['True', 'true']},
            ]
        ).get(
            'Reservations', []
        )

        instances = sum(
            [
                [i for i in r['Instances']]
                for r in reservations
                ], [])

        logger.info("Found {} instances that have a backup tag".format(len(instances)))

        to_tag = collections.defaultdict(list)
        backedup = 0
        skipped = 0
        success = 0
        for instance in instances:
            retention = get_tag_value(instance, "Retention", default_retention, str)
            backup_times = get_tag_value(instance, "BackupTimes", default_backup_time, str)
            if not check_backup_time(backup_times, current_hour):
                logger.info("{} not scheduled for backup now".format(instance['InstanceId']))
                skipped += 1
                success = int(float(backedup + skipped) / len(instances) * 100)
                continue
            retention_hours = get_retention_for_run(retention, backup_times, current_hour)

            # Create format needs to end with the date because delete_ami is
            # looking for a backup with current date at the end.
            create_fmt = datetime.datetime.now().strftime('%H.%M.%S on %Y-%m-%d')

            AMIid = ec.create_image(InstanceId=instance['InstanceId'],
                                    Name="Lambda - " + instance['InstanceId'] +
                                    " from " + create_fmt,
                                    Description="Lambda created AMI of " +
                                    "instance " + instance['InstanceId'],
                                    NoReboot=True,
                                    DryRun=False)

            to_tag[AMIid['ImageId']] = get_tags_for_ami(instance,
                                                        retention_hours)
            backedup += 1
            success = int(float(backedup + skipped) / len(instances) * 100)

            logger.info("Retaining AMI {} of instance {} for {} hours".format(
                AMIid['ImageId'],
                instance['InstanceId'],
                retention_hours,
            ))
        for ami in to_tag.keys():
            ec.create_tags(
                Resources=[ami],
                Tags=ansible_dict_to_boto3_tag_list(to_tag[ami]),
            )

    except Exception as e:
        raise e
    finally:
        # always print DATADOG output
        print('MONITORING|{0}|{1}|gauge|ami-backup.success|#region:{2}'
              .format(int(time.time()), success, os.environ["region"]))


def boto3_tag_list_to_ansible_dict(tags_list):
    tags_dict = {}
    for tag in tags_list:
        if 'key' in tag and not tag['key'].startswith('aws:'):
            tags_dict[tag['key']] = tag['value']
        elif 'Key' in tag and not tag['Key'].startswith('aws:'):
            tags_dict[tag['Key']] = tag['Value']

    return tags_dict


def ansible_dict_to_boto3_tag_list(tags_dict):
    tags_list = []
    for k, v in tags_dict.items():
        tags_list.append({'Key': k, 'Value': v})

    return tags_list


if __name__ == "__main__":
    lambda_handler("", "")
