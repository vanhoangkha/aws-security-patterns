import boto3
import os
import json

rds = boto3.client('rds')
sns = boto3.client('sns')

def handler(event, context):
    detail = event['detail']
    resource_id = detail['resourceId']
    
    # Get DB instance details
    db_identifier = resource_id.split(':')[-1]
    
    try:
        response = rds.describe_db_instances(DBInstanceIdentifier=db_identifier)
        db_instance = response['DBInstances'][0]
        
        if not db_instance['StorageEncrypted']:
            # Create snapshot
            snapshot_id = f"{db_identifier}-encryption-snapshot"
            rds.create_db_snapshot(
                DBSnapshotIdentifier=snapshot_id,
                DBInstanceIdentifier=db_identifier
            )
            
            # Wait for snapshot
            waiter = rds.get_waiter('db_snapshot_completed')
            waiter.wait(DBSnapshotIdentifier=snapshot_id)
            
            # Copy snapshot with encryption
            encrypted_snapshot = f"{snapshot_id}-encrypted"
            kms_key = os.environ.get('KMS_KEY_ID') or 'alias/aws/rds'
            
            rds.copy_db_snapshot(
                SourceDBSnapshotIdentifier=snapshot_id,
                TargetDBSnapshotIdentifier=encrypted_snapshot,
                KmsKeyId=kms_key
            )
            
            notify(f"Created encrypted snapshot for {db_identifier}. Manual restore required.")
            
    except Exception as e:
        notify(f"Error remediating {db_identifier}: {str(e)}")
        raise

def notify(message):
    sns.publish(
        TopicArn=os.environ['SNS_TOPIC'],
        Subject="RDS Encryption Remediation",
        Message=message
    )
