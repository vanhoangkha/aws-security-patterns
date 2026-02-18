import boto3
from datetime import datetime

ec2 = boto3.client('ec2')

def handler(event, context):
    instance_id = event.get('instance_id') or extract_instance_id(event)
    if not instance_id:
        return {'status': 'no_instance_found'}
    
    # Get all volumes attached to instance
    response = ec2.describe_instances(InstanceIds=[instance_id])
    volumes = []
    
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            for mapping in instance.get('BlockDeviceMappings', []):
                volumes.append(mapping['Ebs']['VolumeId'])
    
    # Create forensic snapshots
    snapshots = []
    timestamp = datetime.utcnow().strftime('%Y%m%d-%H%M%S')
    
    for volume_id in volumes:
        snapshot = ec2.create_snapshot(
            VolumeId=volume_id,
            Description=f'Forensic snapshot - {instance_id} - {timestamp}',
            TagSpecifications=[{
                'ResourceType': 'snapshot',
                'Tags': [
                    {'Key': 'Purpose', 'Value': 'Forensics'},
                    {'Key': 'SourceInstance', 'Value': instance_id},
                    {'Key': 'CreatedAt', 'Value': timestamp}
                ]
            }]
        )
        snapshots.append(snapshot['SnapshotId'])
    
    return {
        'status': 'snapshots_created',
        'instance_id': instance_id,
        'snapshots': snapshots
    }

def extract_instance_id(event):
    resources = event.get('detail', {}).get('resource', {}).get('instanceDetails', {})
    return resources.get('instanceId')
