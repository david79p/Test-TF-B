import boto3
import datetime
import time
import os
import logging

logging.basicConfig(level=os.environ.get('LOG_LEVEL', 'INFO'))
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

if "region" in os.environ and os.environ["region"] != "":
    # we have a region, so skip auto detection of current region
    ec2_client = boto3.client('ec2', region_name=os.environ["region"])
    ec2_ressource = boto3.resource('ec2', region_name=os.environ["region"])
else:
    ec2_client = boto3.client('ec2')
    ec2_ressource = boto3.resource('ec2')


def image_is_broken(image, brokenImages):
    broken = False
    if image.state != 'available':
        # Do not count not available images for successful backups
        broken = True
        if image.state != 'pending':
            # Do not increment counter on pending
            logger.warning("Broken Image: {}".format(image.name))
            brokenImages += 1
    return broken, brokenImages


def images_to_delete():
    images = ec2_ressource.images.filter(
        Filters=[
            {'Name': 'tag-key', 'Values': ['DeleteOn']},
        ],
        Owners=['self']
    )
    imagesList = []
    # Set to true once we confirm we have a backup taken today
    backupSuccess = False
    brokenImages = 0
    todayImages = 0

    date_time_fmt = datetime.datetime.now().strftime('%Y-%m-%d-%H')
    date_fmt = datetime.datetime.now().strftime('%Y-%m-%d')
    today_date = time.strptime(date_time_fmt, '%Y-%m-%d-%H')
    logger.info("Deleting AMIs with DeleteOn <= {}".format(date_time_fmt))

    # Loop through each image of our current instance
    for image in images:
        # Our other Lambda Function names its AMIs Lambda - i-instancenumber.
        # We now know these images are auto created
        if image.name.startswith('Lambda - i-'):
            broken, brokenImages = image_is_broken(image, brokenImages)
            try:
                if image.tags is not None:
                    deletion_date = [
                        t.get('Value') for t in image.tags
                        if t['Key'] == 'DeleteOn'][0]
                    if len(deletion_date.split('-')) == 3:
                        # backups created before the support of hourly backups / can be removed sometime
                        delete_date = time.strptime(deletion_date, "%m-%d-%Y")
                    else:
                        # backups created by the updated function
                        delete_date = time.strptime(deletion_date, "%Y-%m-%d-%H")
            except IndexError:
                continue
            except ValueError as e:
                logger.warning("{}".format(e))
                continue

            # If image's DeleteOn date is less than or equal to today,
            # add this image to our list of images to process later
            if delete_date <= today_date:
                logger.info("Found image {}".format(image.id))
                imagesList.append(image.id)

            # Make sure we have an valid AMI from today and mark backupSuccess
            # as true
            if not broken and image.name.endswith(date_fmt):
                # Our latest backup from our other Lambda Function succeeded
                todayImages += 1
                if not backupSuccess:
                    backupSuccess = True
                    logger.debug("We have at least one backup created on {}".format(date_fmt))
    return (brokenImages, todayImages, backupSuccess, imagesList)


def lambda_handler(event, context):

    # get all our DeleteOn tagged images
    (brokenImages, todayImages, backupSuccess, imagesList) = images_to_delete()
    region = os.environ["region"]
    # DATADOG output
    print('MONITORING|{0}|{1}|count|ami-backup.brokenImages|#region:{2}'
          .format(int(time.time()), brokenImages, region)
          )
    print('MONITORING|{0}|{1}|count|ami-backup.createdImages|#region:{2}'
          .format(int(time.time()), todayImages, region)
          )
    # SNS Output
    if (
        brokenImages > 0 and
        "sns_topic" in os.environ and
        len(os.environ["sns_topic"]) > 0
    ):
        sns = boto3.client('sns', region_name=region)
        sns.publish(
            TopicArn=os.environ["sns_topic"],
            Subject='Broken backup AMIs detected in {0}'.format(region),
            Message='There are {} broken AMIs which are used for '
            'backup purposes'.format(brokenImages)
            )

    # backupSuccess = True  # for testing purpuses, remove once done.
    deletedImages = delete_images(imagesList, backupSuccess)
    print('MONITORING|{0}|{1}|count|ami-backup.deletedImages|#region:{2}'
          .format(int(time.time()), deletedImages, region))


def delete_images(imagesList, backupSuccess):
    deletedImages = 0
    if backupSuccess is True:

        logger.info("=============")
        logger.info("About to process the following AMIs:")
        logger.info(', '.join(imagesList))

        snapshots = []
        tmp = ec2_client.describe_snapshots(MaxResults=1000, OwnerIds=['self'])

        while True:
            snapshots.extend(tmp["Snapshots"])
            if "NextToken" not in tmp:
                break
            logger.info("Need to describe snapshots once again, we hit result limit")
            token = tmp["NextToken"]
            tmp = ec2_client.describe_snapshots(
                MaxResults=1000,
                OwnerIds=['self'],
                NextToken=token
            )

        # loop through list of image IDs
        for image in imagesList:
            logger.info("deregistering image {}".format(image))
            ec2_client.deregister_image(
                DryRun=False,
                ImageId=image,
            )

            for snapshot in snapshots:
                # Image is surrounded with spaces.
                # Otherwise snapshot of ami-abc and ami-abcd might be both
                # deleted if we delete ami-abc
                if snapshot['Description'].find(' ' + image + ' ') > 0:
                    ec2_client.delete_snapshot(
                        SnapshotId=snapshot['SnapshotId']
                    )
                    logger.info("Deleting snapshot {}".format(snapshot['SnapshotId']))

            logger.info("-------------")
            deletedImages += 1

    else:
        logger.info("No current backup found. Termination suspended.")

    return deletedImages


# Enable local debugging
if __name__ == "__main__":
    lambda_handler("", "")
