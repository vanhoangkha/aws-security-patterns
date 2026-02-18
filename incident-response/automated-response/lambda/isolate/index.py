import boto3

ec2 = boto3.client('ec2')

def handler(event, context):
    instance_id = extract_instance_id(event)
    if not instance_id:
        return {'status': 'no_instance_found'}
    
    # Create isolation security group
    vpc_id = get_instance_vpc(instance_id)
    isolation_sg = create_isolation_sg(vpc_id)
    
    # Replace all security groups with isolation SG
    ec2.modify_instance_attribute(
        InstanceId=instance_id,
        Groups=[isolation_sg]
    )
    
    return {
        'status': 'isolated',
        'instance_id': instance_id,
        'isolation_sg': isolation_sg
    }

def extract_instance_id(event):
    resources = event.get('detail', {}).get('resource', {}).get('instanceDetails', {})
    return resources.get('instanceId')

def get_instance_vpc(instance_id):
    response = ec2.describe_instances(InstanceIds=[instance_id])
    return response['Reservations'][0]['Instances'][0]['VpcId']

def create_isolation_sg(vpc_id):
    response = ec2.create_security_group(
        GroupName=f'isolation-sg-{vpc_id[:8]}',
        Description='Isolation security group - no inbound/outbound',
        VpcId=vpc_id
    )
    sg_id = response['GroupId']
    
    # Remove default outbound rule
    ec2.revoke_security_group_egress(
        GroupId=sg_id,
        IpPermissions=[{'IpProtocol': '-1', 'IpRanges': [{'CidrIp': '0.0.0.0/0'}]}]
    )
    
    return sg_id
