import json
import boto3
import os
import urllib3

def handler(event, context):
    secret = get_secret()
    findings = event['detail']['findings']
    
    for finding in findings:
        create_jira_issue(finding, secret)
    
    return {'statusCode': 200}

def get_secret():
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=os.environ['SECRET_NAME'])
    return json.loads(response['SecretString'])

def create_jira_issue(finding, secret):
    http = urllib3.PoolManager()
    
    issue_data = {
        "fields": {
            "project": {"key": os.environ['JIRA_PROJECT']},
            "summary": f"[{finding['Severity']['Label']}] {finding['Title']}",
            "description": f"""
AWS Security Hub Finding

**Account:** {finding['AwsAccountId']}
**Region:** {finding['Region']}
**Resource:** {finding['Resources'][0]['Id']}
**Severity:** {finding['Severity']['Label']}

**Description:**
{finding['Description']}

**Remediation:**
{finding.get('Remediation', {}).get('Recommendation', {}).get('Text', 'N/A')}
            """,
            "issuetype": {"name": "Bug"},
            "priority": {"name": map_severity(finding['Severity']['Label'])}
        }
    }
    
    response = http.request(
        'POST',
        f"{os.environ['JIRA_URL']}/rest/api/2/issue",
        body=json.dumps(issue_data),
        headers={
            'Content-Type': 'application/json',
            'Authorization': f"Basic {secret['api_token']}"
        }
    )
    
    return response.status

def map_severity(severity):
    mapping = {
        'CRITICAL': 'Highest',
        'HIGH': 'High',
        'MEDIUM': 'Medium',
        'LOW': 'Low'
    }
    return mapping.get(severity, 'Medium')
