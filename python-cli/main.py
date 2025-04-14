 
import boto3
import click
from botocore.exceptions import ClientError

@click.group()
def cli():
    pass

@cli.command()
def check():
    try:
        s3_client = boto3.client('s3')
        iam_client = boto3.client('iam')
    except Exception as e:
        click.echo(f"Failed to initialize AWS clients: {e}", err=True)
        return
    check_s3_buckets(s3_client)
    check_iam_users_mfa(iam_client)

def check_s3_buckets(s3_client):
    """Check S3 buckets for public access and encryption"""
    try:
        response = s3_client.list_buckets()
        buckets = response.get('Buckets', [])
    except ClientError as e:
        click.echo(f"Failed to list S3 buckets: {e}", err=True)
        return

    for bucket in buckets:
        bucket_name = bucket['Name']
        
        # Check public access via ACL
        try:
            acl = s3_client.get_bucket_acl(Bucket=bucket_name)
            for grant in acl['Grants']:
                grantee = grant.get('Grantee', {})
                if grantee.get('Type') == 'Group' and grantee.get('URI') in [
                    'http://acs.amazonaws.com/groups/global/AllUsers',
                    'http://acs.amazonaws.com/groups/global/AuthenticatedUsers'
                ]:
                    click.echo(click.style(f"WARNING: Bucket {bucket_name} has public access via ACL", fg='red'))
        except ClientError as e:
            click.echo(f"Failed to check ACL for bucket {bucket_name}: {e}", err=True)

        # Check public access via bucket policy
        try:
            policy = s3_client.get_bucket_policy(Bucket=bucket_name)
            import json
            policy_json = json.loads(policy['Policy'])
            for statement in policy_json.get('Statement', []):
                if statement.get('Effect') == 'Allow' and (
                    statement.get('Principal') == '*' or
                    (isinstance(statement.get('Principal'), dict) and statement.get('Principal', {}).get('AWS') == '*')
                ):
                    click.echo(click.style(f"WARNING: Bucket {bucket_name} has public access via bucket policy", fg='red'))
        except ClientError as e:
            if "NoSuchBucketPolicy" in str(e):
                pass  # No policy, so not public via policy
            else:
                click.echo(f"Failed to check bucket policy for {bucket_name}: {e}", err=True)

        # Check encryption
        try:
            s3_client.get_bucket_encryption(Bucket=bucket_name)
            click.echo(f"Bucket {bucket_name} has encryption enabled")
        except ClientError as e:
            if "ServerSideEncryptionConfigurationNotFoundError" in str(e):
                click.echo(click.style(f"WARNING: Bucket {bucket_name} has no encryption configured", fg='red'))
            else:
                click.echo(f"Failed to check encryption for bucket {bucket_name}: {e}", err=True)

def check_iam_users_mfa(iam_client):
    try:
        response = iam_client.list_users()
        users = response.get('Users', [])
    except ClientError as e:
        click.echo(f"Failed to list IAM users: {e}", err=True)
        return
    for user in users:
        user_name = user['UserName']
        try:
            mfa_devices = iam_client.list_mfa_devices(UserName=user_name)
            if not mfa_devices['MFADevices']:
                click.echo(f"WARNING: User {user_name} does not have MFA enabled")
            else:
                click.echo(f"User {user_name} has MFA enabled")
        except ClientError as e:
            click.echo(f"Failed to check MFA for {user_name}: {e}", err=True)

if __name__ == '__main__':
    cli()