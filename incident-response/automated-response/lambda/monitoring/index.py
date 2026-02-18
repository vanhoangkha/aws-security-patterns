import boto3

cloudwatch = boto3.client('cloudwatch')
logs = boto3.client('logs')

def handler(event, context):
    # Enable detailed monitoring for suspicious activity
    source_ip = event.get('detail', {}).get('service', {}).get('action', {}).get('networkConnectionAction', {}).get('remoteIpDetails', {}).get('ipAddressV4')
    
    if source_ip:
        # Create metric filter for the suspicious IP
        create_ip_metric_filter(source_ip)
        
        # Create alarm for the metric
        create_alarm(source_ip)
    
    return {
        'status': 'monitoring_enhanced',
        'source_ip': source_ip
    }

def create_ip_metric_filter(ip):
    try:
        logs.put_metric_filter(
            logGroupName='/aws/vpc/flowlogs',
            filterName=f'suspicious-ip-{ip.replace(".", "-")}',
            filterPattern=f'[version, account, eni, source={ip}, ...]',
            metricTransformations=[{
                'metricName': f'SuspiciousIP-{ip.replace(".", "-")}',
                'metricNamespace': 'SecurityMonitoring',
                'metricValue': '1'
            }]
        )
    except Exception as e:
        print(f"Error creating metric filter: {e}")

def create_alarm(ip):
    cloudwatch.put_metric_alarm(
        AlarmName=f'suspicious-ip-activity-{ip.replace(".", "-")}',
        MetricName=f'SuspiciousIP-{ip.replace(".", "-")}',
        Namespace='SecurityMonitoring',
        Statistic='Sum',
        Period=300,
        EvaluationPeriods=1,
        Threshold=1,
        ComparisonOperator='GreaterThanOrEqualToThreshold',
        AlarmDescription=f'Activity detected from suspicious IP: {ip}'
    )
