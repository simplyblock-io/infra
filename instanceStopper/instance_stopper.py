import boto3
from datetime import datetime, timezone

HOURS_12_IN_SECONDS = 43200

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')

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

    return {
        'statusCode': 200,
        'body': f'Stopped instances: {instances_to_stop}'
    }
