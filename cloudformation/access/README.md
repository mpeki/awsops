#### Scripts and templates for creating and maintaining IAM users in the admin account.


1. `users-developers.yml` - Creates several groups and policies:
   - Developer group
   - DevOps group
   - Testers group
   - DevOpsAccessPolicy policy that gives limited access to ECS registry and S3 Buckets
   - EC2LimitedAccess policy that gives limited access to EC2
   - Several user are also created with a default password that must be changed first time they logon

#### IAM user setup
- Log into the [AWS console](https://581713009827.signin.aws.amazon.com/console) with you credentials and update the password when prompted.
- Create access key: Go to your own user: aws->iam->users->[own-user]->Security credentials->Create access key:
  - Remember to download the keyfile. This is the only time where you will be able to see the private key ID.
- Assign and activate a MFA device - this is used when accessing our development account via AWS CLI
  - Make note of the ARN for the MFA device, you gonna need it later on.
- **Request administrator rights for admin account** - contact tlo@tiatechnology.com

#### Install AWS CLI
- Before starting using AWS, the AWS CLI must be installed. Follow the installation described on [Amazon](https://aws.amazon.com/cli)
- Check the installtion with `aws --version`

#### Profiles
When AWS CLI has been installed you must configure some profiles:

1. An admin profile to access our Administration account (581713009827)
2. An dev profile to access our Development account (281283362525)
3. A demo profile to access our Demo account (311542012115)

##### Configure admin account
`aws --profile admin configure`
- Provide your Access key - from the keyfile previously downloaded
- Provide your Secret Access key - from the keyfile previously downloaded
- For default region name use `eu-central-1`
- For default output format leave that as None

Check the configuration with `aws --profile admin configure list`

##### Configure dev account
- Associate admin role from dev account - this lets you assume the DevAdmin role in the dev account:
  - `aws --profile dev configure set role_arn arn:aws:iam::281283362525:role/DevAdmin`
- Set the source profile to admin
  - `aws --profile dev configure set source_profile admin`
- Attach the virtual MFA device to the dev profile. Copy the ARN from your MFA device from the AWS console and substitute that value in the next command.
  - `aws --profile dev configure set mfa_serial <mfa device serial>`
- Set the region to `eu-central-1`
  - `aws --profile dev configure set region eu-central-1`

Check the configuration with `aws --profile dev configure list`

##### Configure demo account
- Associate admin role from dev account - this lets you assume the DemoAdmin role in the dev account:
  - `aws --profile demo configure set role_arn arn:aws:iam::311542012115:role/DemoAdmin`
- Set the source profile to admin
  - `aws --profile demo configure set source_profile admin`
- Attach the virtual MFA device to the demo profile. Copy the ARN from your MFA device from the AWS console and substitute that value in the next command.
  - `aws --profile demo configure set mfa_serial <mfa device serial>`
- Set the region to `eu-central-1`
  - `aws --profile demo configure set region eu-central-1`

Check the configuration with `aws --profile demo configure list`