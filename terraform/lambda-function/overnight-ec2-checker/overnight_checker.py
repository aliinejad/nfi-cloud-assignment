import boto3
import datetime
import os

def lambda_handler(event, context):
    sns_topic_arn = os.environ.get('OVERNIGHT_SNS_TOPIC_ARN')
    if not sns_topic_arn:
        raise Exception("OVERNIGHT_SNS_TOPIC_ARN environment variable not set")
    ec2 = boto3.client('ec2')
    response = ec2.describe_instances(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}])
    overnight_instances = []
    for reservation in response.get("Reservations", []):
        for instance in reservation.get("Instances", []):
            launch_time = instance.get("LaunchTime")
            launch_time_local = launch_time.astimezone(datetime.timezone.utc)
            if 0 <= launch_time_local.hour < 6:
                overnight_instances.append(instance["InstanceId"])
    if overnight_instances:
        message = ("Overnight EC2 Instance Alert:\n\n" +
                   "The following EC2 instances were running between midnight and 6:00 AM UTC:\n" +
                   "\n".join(overnight_instances))
        sns = boto3.client('sns')
        sns.publish(TopicArn=sns_topic_arn, Subject="Overnight EC2 Instance Alert", Message=message)
        return {"status": "Alert sent", "instances": overnight_instances}
    return {"status": "No overnight instances found"}
