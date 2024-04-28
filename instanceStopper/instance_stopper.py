import boto3
import os
from typing import List
from datetime import datetime, timezone
import requests


HOURS_12_IN_SECONDS = 43200


def stop_instances(aws_region: str) -> List[str]:
    ec2 = boto3.client('ec2', region_name=aws_region)
    instances = ec2.describe_instances()
    instances_to_stop = []
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            if instance['State']['Name'] == 'running':
                launch_time = instance['LaunchTime']
                current_time = datetime.now(timezone.utc)
                uptime = current_time - launch_time
                if uptime.total_seconds() > HOURS_12_IN_SECONDS:
                    long_term_test = False
                    if 'Tags' in instance:
                        for tag in instance['Tags']:
                            if tag['Key'] == 'long-term-test' and tag['Value'].lower() == 'true':
                                long_term_test = True
                                break
                    if not long_term_test:
                        instances_to_stop.append(instance['InstanceId'])

    if instances_to_stop:
        print(f"Stopping instances: {instances_to_stop}")
        ec2.stop_instances(InstanceIds=instances_to_stop)
    else:
        print("No instances meet the criteria for stopping.")

    return instances_to_stop

def send_slack(region, stopped):

    message = f"region: `{region}`\n Stopping instances: {stopped} as they are running for more than 12 hours"
    slack_webhook_url = os.environ.get("SLACK_WEBHOOK")
    data = {
        "text": message
    }
    response = requests.post(url=slack_webhook_url, json=data)
    if response.status_code == 200:
        print('Message sent successfully')
    else:
        print('Failed to send message:', response.text)


def lambda_handler(event, context):

    supported_region = ['us-east-1', 'us-east-2', 'us-west-1', 'us-west-2', 'eu-west-1', 'eu-west-2', 'eu-west-3', 'eu-north-1', 'eu-central-1']
    for region in supported_region:
        print('checking region: ', region)
        stopped = stop_instances(region)
        if len(stopped) > 0:
            send_slack(region, stopped, )

    return {
        'statusCode': 200,
        'body': 'Successfully ran'
    }
