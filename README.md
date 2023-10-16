#### AWS services and tools used to automate the creation and maintenance of AWS infrastructure, including VPC, EC2, RDS, and deploying containerized microservices with Docker..

The script are divided into several sections:
-   Initial setup - Should only be done once.
    -   creation of user and roles
-   For each account:
    -   creation of network infrastructure.
    -   creation of container services.

#### Creation of user and roles

Before creating the actual infrastructure the users and associated roles must be
created first.
Complete these [instructions](cloudformation/access/README.md) before
proceeding.

Create some S3 bucket for various purposes:
-   bucket for general operations, scripts and things like that
-   bucket for configs with AES256 server side encryption that should be
    accessible by the accounts.

By running the script:
[cloudformation/storage/s3-buckets.sh](cloudformation/storage/s3-buckets.sh)

#### New Account
Assign mfa for new account.
When creating a new account we need to create access roles for
- admin access
  -  on the new account:
     -  Allow elevated Admin rights via our admin account if mfa is assigned
     -  Create role called \<profile>Admin
     -  `{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "AWS": "arn:aws:iam::<admin_account_number>:root"
              },
              "Action": "sts:AssumeRole",
              "Condition": {
                "Bool": {
                  "aws:MultiFactorAuthPresent": "true"
                }
              }
            }
          ]
        }`
  -  On admin account
     -  create policy to access the admin role for new account called \<profile>AdminAccess
     - `{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "sts:AssumeRole"
                    ],
                    "Resource": [
                        "arn:aws:iam::<new account number>:role/<profile>Admin"
                    ]
                }
            ]
        }`
- devops access
  -  on the new account:
     -  Allow elevated Devops rights:(IAMReadOnlyAccess, PowerUserAccess) via our admin account
     -  Add inline role called PassRoleForEcsTaskRole:
     -  `{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": "iam:PassRole",
                    "Resource": "arn:aws:iam::<account number>:role/EcsTaskRoleForServices"
                },
                {
                    "Effect": "Allow",
                    "Action": "iam:PassRole",
                    "Resource": "arn:aws:iam::<account number>:role/ecsTaskExecutionRole"
                }
            ]
        }`
     -  Allow elevated Devops rights for iam creation - required for environments to be deployed with awx
     -  Add inline role called <profile>OpsServiceRole:
     -  `{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": [
                        "iam:CreateInstanceProfile",
                        "iam:DeleteInstanceProfile",
                        "iam:RemoveRoleFromInstanceProfile",
                        "iam:CreateRole",
                        "iam:DeleteRole",
                        "iam:AttachRolePolicy",
                        "iam:PutRolePolicy",
                        "iam:AddRoleToInstanceProfile",
                        "iam:CreatePolicy",
                        "iam:PassRole",
                        "iam:DetachRolePolicy",
                        "iam:DeleteRolePolicy",
                        "iam:PutGroupPolicy",
                        "iam:DeletePolicy"
                    ],
                    "Resource": [
                        "arn:aws:iam::<account number>:group/logs",
                        "arn:aws:iam::<account number>:role/*",
                        "arn:aws:iam::<account number>:policy/*",
                        "arn:aws:iam::<account number>:instance-profile/*"
                    ],
                    "Effect": "Allow",
                    "Sid": "IAMpermissionsOpsUser"
                }
            ]
        }`
     -  Create role called \<profile>Ops
     -  `{
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "AWS": "arn:aws:iam::<account number>:root"
              },
              "Action": "sts:AssumeRole"
            }
          ]
        }`




#### Creation of network infrastructure

When the users and roles are created the network infrastructure can be
implemented.
The network infrastructure is a 3 tier implementation consisting of 3 subnets
replicated over 3 availability zones.
-   a public subnet with 256 available IP addresses in each availability zone
    (CIDR mask /21)
-   a private VPN subnet with 256 available IP addresses in each availability
    zone (CIDR mask /21)
-   a private RDS subnet with 32 available IP addresses in each availability
    zone (CIDR mask /27)

A total of 9 subnets will be created in a virtual private cloud (CIDR mask /21)
with an Internet gateway and a VPN gateway (for on premise access).
Before running the scripts you need to consider some setting about the network:
-   VPC CIDR block prefix - e.g. `10.42`
-   Domain name for the local hosted DNS zone - e.g. `cussp.local`
-   For VPN:
    -   Customer IP4 address - The static internet-routable IP address for the
        customer gateway's outside interface.
    -   Destination CIDR block - e.g. `192.168.0.0/21`
    -   BGP Autonomous System Number - e.g `65000`

Complete these [instructions](cloudformation/network/README.md) before
proceeding.

**TODO: Describe how to setup Transit Gateway**
- Invite Account from Admin
- Accept invite from Account
- Create VPC attachment associated with tgw and local subnets in Account
- Accept VPC attachment from Account in Admin
- Create route to on-premise via tgw in Account
- Check route is create in route table in Admin

##### Buckets etc...

We also need access to the Admin buckets:
-   Update
    [cloudformation/storage/s3-policies.yml](cloudformation/storage/s3-policies.yml)
    with access rights for your new account:
    -   BucketPolicyForGeneralOperations - read rights
    -   BucketPolicyForConfigs - read rights
    -   BucketPolicyForBackups - write rights
-   Run the script
    [cloudformation/storage/s3-policies.sh](cloudformation/storage/s3-policies.sh) (NB! Update with access rights for any new account)
    -  Create folder for new account in bucket cussp-config and add config-server access key (id_rsa) in folder: <profile>/access/config-server

This will give the account read access to the general- and config buckets under
a subdir equals to the profile name for the account - e.g for the `dev` account
the subdir is `/dev/*`

For the Backup bucket upload access will be granted under a subdir equals to the
profile name.

Next create a bucket used for the portal static content by running the script
[cloudformation/storage/s3-cussp-bucket.sh](cloudformation/storage/s3-cussp-bucket.sh)


#### Creation of container services

Our services needs a cluster of instances to execute on. The instances are
controlled via a auto-scaling-group behind a load balancer.

We have two load balancers:
-   Internet facing with a known local DNS entry (api-lb.cussp.local). There is
    also a public DNS associated with this load balancer, in that way it is
    acting as our API Gateway.
-   Internal with a known local DNS entry (api-lb-internal.cussp.local)

Perform these actions:
-   If you plan to use FarGate then you must add specific roles for that by
    running
    [cloudformation/access/roles-for-fargate.sh](cloudformation/access/roles-for-fargate.sh)
-   Create EC2 roles so that our ECS nodes can work with other AWS services by
    running
    [cloudformation/access/roles-for-ec2.sh](cloudformation/access/roles-for-ec2.sh)
-   Create a role for the ECS service itself by running
    [cloudformation/access/roles-for-ecs.sh](cloudformation/access/roles-for-ecs.sh)
-   Create ECS Cluster and auto-scaling-group by running the script
    [cloudformation/compute/ec2-autoscaling-ecs.sh](cloudformation/compute/ec2-autoscaling-ecs.sh)
    -   You must supply a name for the cluster and a key-pair name. You can
        create a new key-pair or upload an existing one.
    -   The instances are automatically targeted the ECS cluster and are
        launched in the private VPN subnets.
-   Create Load Balancers by running the script
    [cloudformation/loadbalancing/internet-elb.sh](cloudformation/loadbalancing/internet-elb.sh)
    -   The load balancer registers itself with our local hosted zone as ane
        apex alias. That way the load balancer is easily accessed with a know
        DNS equals to the name of the load balancer.
    -   Create DNS alias'es for both the external loadbalancer and the internel loadbalancer

**TODO: Describe how to setup HTTPS and certificate**
- create certificate - create name/cname record in route53 on Dev
- create http/https listener for api-lb and http for api-lb-internal

**TODO Describe setup of rds subnet group***
- [cloudformation/database/rds-subnetgroup.sh](cloudformation/database/rds-subnetgroup.sh)
- create parametergroup and change values:
- -  log_bin_trust_function_creators: 1
  -  max_allowed_packet: 31457280
  -  max_connections: 2000

**TODO Describe setup of redis***
- [cloudformation/elasticache/redis-subnet-sec.sh](cloudformation/elasticache/redis-subnet-sec.sh)
- [cloudformation/elasticache/redis-setup.sh](cloudformation/elasticache/redis-setup.sh)

**TODO Describe setup of MQ***
- [cloudformation/integration/activemq-security.sh](cloudformation/integration/activemq-security.sh)
- [cloudformation/integration activemq-setup.sh](cloudformation/integration/activemq-setup.sh)
- [cloudformation/integration activemq-dns.sh](cloudformation/integration/activemq-dns.sh)

**TODO Describe setup of elasticsearch***
- [cloudformation/elasticsearch elasticsearch-setup.sh](cloudformation/elasticsearch/elasticsearch-setup.sh)
- Create service-linked role for elasticsearch if not already present:
  - aws iam create-service-linked-role --profile <profile> --aws-service-name es.amazonaws.com

**TODO Describe setup of CloudFront***
- distribution - S3 and Certificate

For each service (docker image) that should be deployed you need to perform
these steps:

-   Create database if needed by running [cloudformation/database rds-setup.sh](cloudformation/database/rds-setup.sh)
-   Create ECR repository:
    -   Add account ARN to policy-text argument for procedure ‘allowPull’
    -   Run script
        [cloudformation/servicesetup/service-repository.sh](cloudformation/servicesetup/service-repository.sh)
        two times:
        -   once for creating the respository
        -   once for adding pull rights for account

-   Tag the image and push to ECR (Jenkins?)
    -   Tag the docker with the script
        [cloudformation/servicesetup/service-setup-elb.sh](cloudformation/servicesetup/service-setup-elb.sh)
        -   `./service-setup-elb.sh -e <service name> -v <version> tag`
    -   Push the image to ECR with the script
        [cloudformation/servicesetup/service-setup-elb.sh](cloudformation/servicesetup/service-setup-elb.sh)
        -   `./service-setup-elb.sh -e <service name> -v <version> push`

-   Setup and launch service - You need some information for setting up service:
    -   Service name: The name of the service that you have previously pushed to
        ECR
    -   Service version: The version of the pushed version

-   Setup and launch:
    -   Service with load balancer: `./service-setup-elb.sh -e <service name> -v
        <version> create`
    -   Service **without** load balancer: `./service-setup-elb.sh -e <service
        name> -v <version> -l '' create`
    - Check status with `./service-setup-elb.sh show`


### More on tagging/pushing Docker Images:
When tagging and pushing images via `service-setup-elb.sh` script, the image-tag will be suffixed with the current GIT revision for the given service in action.

```
NB! environment variable UNICORN_HOME must point to root of Unicorn project.
```

The working procedure is as follow:

1. pull latest or push current source code from/to GIT
2. Build source and deploy docker image to TIA repositiory with
    ```
    mvn clean package
    ```
    The Docker image will be tagged with the current version and name from the .pom file, e.g. `repo.tiatechnology.com/docker-dev/users-api:0.0.1-SNAPSHOT`
3. Tag image before pushing to AWS:
    ```
    ./service-setup-elb.sh -p <profile> -v <version> -e <service> tag
    ```
    If version ends with `-SNAPSHOT` then the image-tag with be suffixed with current GIT revision for given service e.g. `581713009827.dkr.ecr.eu-central-1.amazonaws.com/users-api:0.0.1-SNAPSHOT-DEV-B3F0C9DE3E6C5E002306A91FC96E19BEAB238660`
4. Push image to AWS:
    ```
    ./service-setup-elb.sh -p <profile> -v <version> -e <service> push
    ```
5. create or update the service on AWS:
    ```
    ./service-setup-elb.sh -p <profile> -v <version> -e <service> <create|update>
    ```
The current image assigned to a service can be shown with the following command:
```
./service-setup-elb.sh -p <profile> report
```
Each service is shown in a table.
