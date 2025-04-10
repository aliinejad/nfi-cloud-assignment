import os
import boto3

def is_instance_idle(instance_id):
    return True

def handler(event, context):
    asg_name = os.environ.get('AUTO_SCALING_GROUP')
    autoscaling = boto3.client('autoscaling')
    groups = autoscaling.describe_auto_scalingGroups(AutoScalingGroupNames=[asg_name])['AutoScalingGroups']
    if not groups:
        return
    group = groups[0]
    instances = group.get('Instances', [])
    idle_instances = []
    for instance in instances:
        instance_id = instance['InstanceId']
        if is_instance_idle(instance_id):
            idle_instances.append(instance_id)
    for instance_id in idle_instances:
        autoscaling.terminate_instance_in_auto_scaling_group(
            InstanceId=instance_id, 
            ShouldDecrementDesiredCapacity=True
        )
