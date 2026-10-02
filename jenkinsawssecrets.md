# Jenkins Secret Manager with AWS Secrets Manager

This repository includes the AWS Secrets Manager commands used to store Jenkins credentials securely for GitHub and Docker access.

## Prerequisites

- AWS CLI installed and configured
- AWS IAM user or role with permissions to create secrets in AWS Secrets Manager
- Jenkins configured with access to AWS Secrets Manager (using AWS credentials or IAM role)

Example AWS CLI verification:

```bash
aws sts get-caller-identity
```

## Create username/password secret for Jenkins

```bash
aws secretsmanager create-secret \
  --name 'github-username' \
  --secret-string 'ghp_xxxxxxxxxxxxxxxxxxxxx' \
  --tags 'Key=jenkins:credentials:type,Value=usernamePassword' 'Key=jenkins:credentials:username,Value=your-github-username' \
  --description 'GitHub username and PAT'
```

This is the Jenkins credential pattern for a GitHub or Docker username/password secret, where the secret value is the token or password and the username is supplied through tags for Jenkins credential mapping.

## Example usage

Replace the placeholders with your real values:

```bash
aws secretsmanager create-secret \
  --name 'github-username' \
  --secret-string 'ghp_xxxxxxxxxxxxxxxxxxxxx' \
  --tags 'Key=jenkins:credentials:type,Value=usernamePassword' 'Key=jenkins:credentials:username,Value=your-github-username' \
  --description 'GitHub username and PAT'

aws secretsmanager create-secret \
  --name 'docker-username' \
  --secret-string 'dckr_pat_xxxxxxxxxxxxxxxxxxxxx' \
  --tags 'Key=jenkins:credentials:type,Value=usernamePassword' 'Key=jenkins:credentials:username,Value=your-docker-username' \
  --description 'Docker username and PAT'
```

## Jenkins integration

To use these secrets in Jenkins:

1. Install and configure the AWS Secrets Manager integration plugin in Jenkins.
2. Add AWS credentials to Jenkins if required.
3. Use the secret names in Jenkins pipeline jobs or credential bindings.
4. Reference the secrets at runtime instead of hardcoding tokens in the pipeline.

Example pipeline pattern:

```groovy
withCredentials([
  string(credentialsId: 'github-pat', variable: 'GITHUB_PAT'),
  string(credentialsId: 'docker-pat', variable: 'DOCKER_PAT')
]) {
  sh 'echo $GITHUB_PAT'
  sh 'echo $DOCKER_PAT'
}
```

If you are accessing AWS Secrets Manager directly from Jenkins, ensure the Jenkins EC2 instance or ECS task has the correct IAM permissions, such as:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "*"
    }
  ]
}
```

## Security best practices

- Do not commit PAT values into Git repositories.
- Use AWS IAM roles and least-privilege access.
- Rotate tokens regularly.
- Keep secret names descriptive and environment-specific.
- Use Jenkins credentials securely and avoid exposing tokens in logs.

## Useful commands

List stored secrets:

```bash
aws secretsmanager list-secrets
```

Retrieve a secret value:

```bash
aws secretsmanager get-secret-value --secret-id '<secret-name>' --query 'SecretString' --output text
```

Delete a secret if needed:

```bash
aws secretsmanager delete-secret --secret-id '<secret-name>' --force-delete-without-recovery
```

## Reference

Official Jenkins plugin documentation:

- AWS Secrets Manager Credentials Provider: https://plugins.jenkins.io/aws-secrets-manager-credentials-provider/

This plugin provides the Jenkins-side integration for loading AWS Secrets Manager values as Jenkins credentials. It is a useful reference when configuring secret naming, authentication, and Jenkins credential handling for GitHub and Docker PATs.

## Notes

The `--tags 'Key=jenkins:credentials:type,Value=string'` tag is useful for identifying credentials that are intended for Jenkins credential management and automation workflows.
