import boto3
import os

s3 = boto3.client('s3')
sns = boto3.client('sns')

def handler(event, context):
    detail = event['detail']
    bucket_name = detail['resourceId'].split(':')[-1]
    auto_remediate = os.environ.get('AUTO_REMEDIATE') == 'true'
    
    if auto_remediate:
        remediate_bucket(bucket_name)
    else:
        notify_only(bucket_name)

def remediate_bucket(bucket_name):
    try:
        # Enable public access block
        s3.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': True,
                'IgnorePublicAcls': True,
                'BlockPublicPolicy': True,
                'RestrictPublicBuckets': True
            }
        )
        notify(f"✅ Remediated public bucket: {bucket_name}")
    except Exception as e:
        notify(f"❌ Failed to remediate {bucket_name}: {str(e)}")

def notify_only(bucket_name):
    notify(f"⚠️ Public S3 bucket detected: {bucket_name}\nAuto-remediation disabled.")

def notify(message):
    sns.publish(
        TopicArn=os.environ['SNS_TOPIC'],
        Subject="S3 Public Bucket Alert",
        Message=message
    )
