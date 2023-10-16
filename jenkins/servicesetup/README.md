# Pipeline: aws-ecs-cloudformation
This job can be used for creating, updating and deleting ECS stacks. It should be run in classic view (not Blue Ocean), since it
uses input parameters which cannot be show in the Blue Ocean view.

One stack usually represent one service, which may in turn be an adapter, a public API or some other service that can run on ECS.

## Where
The job location:
[Dashboard -> aws-operations -> servicesetup -> aws-service-setup-elb](http://jenkins.tia.local:8080/job/aws-operations/job/servicesetup/job/aws-service-setup-elb/)

Pipeline definition: [Jenkinsfile.aws-service-setup-elb](https://git.tiatechnology.com/arc/aws-operations/-/blob/jenkins-migration/jenkins/servicesetup/Jenkinsfile.aws-service-setup-elb)

Main aws-operations script: [service-setup-elb.sh](../../cloudformation/servicesetup/service-setup-elb.sh)

## How
To run the job press: [Build Now](http://jenkins.tia.local:8080/job/aws-operations/job/servicesetup/job/aws-service-setup-elb/build?delay=0sec).

When doing so, this is what happens:
* **Git checkout**


* **Get input**: The job is parameterized, but since the parameters are dynamic, these cannot be presented right away.
  When the job is ready to receive input, this will be shown in jenkins classic view (recommended for this job)
  as a dotted line around the current "Get input" stage. Also, the build description will change to **Input requested!**
  which is a link to a page where input can be given. Once the first input has been provided, the user is redirected to
  the console output page, to find out if more input is required, either follow the output or go back to the current build page.


* **Select target and action**: _Target_ is the aws account to update, _action_ is what to do. The list of targets is populated
  from this file: [aws_accounts](https://git.tiatechnology.com/arc/aws-operations/-/blob/jenkins-migration/access/config/aws_accounts),
  please update it if environments are missing.


* **Select stacks to ${action}**: Depending on the action chosen above, this will either show stacks currently deployed to the target environment
  or ECR repositories available for creation. Select the stacks/repository to perform the specified action on. Furthermore, a number of instances
  to run may be specified. **NB!** Currently we run just one instance on all environments other than _dev_ which runs 3 instances.


* **Set create/update options**: If updating or creating stacks, this input page will be presented to capture the version to update to. Also, if
  the service stack script should be called with non-default arguments, a pre-filled text input field will be presented.

**NB!** _Update_ and _delete_ actions will be run in parallel, _create_ actions will run in sequence for each loadbalancer i.e. only one stack will
be created for each loadbalancer, but stacks will be created on both loadbalancers in parallel.

## General Troubleshooting 
The job is only concerned with creating AWS Stacks, it is very possible to create a stack successfully without the service - it's supposed to run -
becoming healthy.

To troubleshoot this, use the AWS services like: CloudFormation, CloudWatch, EC2 and ECS. Also, to check health status of the
services on a given loadbalancer, you can run [alb-healthcheck.sh](https://git.tiatechnology.com/arc/aws-operations/-/blob/master/cloudformation/management/alb-healthcheck.sh)
either locally or via this Jenkins [job](http://jenkins.tia.local:8080/job/aws-operations/job/management/job/alb-healthcheck/) (still in beta).

## Configuration
The main job configuration is located [here](service-setup-elb.properties), most configuration items are described by comments in 
file itself. The following two sections describe properties which need a bit more explaining.

### Overriding Configuration
It is possible to add to and/or override the configuration in [service-setup-elb.properties](service-setup-elb.properties). The
property:
```properties
service.setup.elb.override.id=service-setup-elb.properties
```
Defines a Jenkins configuration file id, in this case: 
[service-setup-elb.properties](http://jenkins.tia.local:8080/job/aws-operations/job/servicesetup/configfiles/editConfig?id=service-setup-elb-override.properties).
Add properties here to override or add to properties defined in [service-setup-elb.properties](service-setup-elb.properties).

The idea is that property changes can be tested without the need to update the file stored in GitLab. Properties
defined in Jenkins should be temporary.

### Config Labels
Currently, there is two different ways of handling configuration labels. 
In R&D environments each solution store configuration in its own Git repository, this is as opposed to customer environments where all config
is stored in one customer specific repository. This reason the configuration needed for the two types of configuration storage is slightly different.

## Deploying from Artifactory
To start deploying from artifactory, add the environment to the following property:
```properties
accounts.using.artifactory=<env name>
```
Since Artifactory contains a lot of artifacts that cannot be deployed to AWS, the following property is used to limit deployable artifacts:
```properties
artifactory.paths=docker-releases/*
```
This is a comma separated list of artifactory paths (accepting wildcards) 

## What
This section describes and tries to answer a few howto/FAQ-like questions.

**To do if the wanted target account is not available:**
1. Check [aws_accounts](https://git.tiatechnology.com/arc/aws-operations/-/blob/jenkins-migration/access/config/aws_accounts)
   and add any missing environments. NB! The job uses these
   [Jenkins credentials](http://jenkins.tia.local:8080/credentials/store/system/domain/_/credential/aws-ops-credentials/) which currently work
   with **admin** and **sbh_admin** if more is needed contact OPS for an update.

**To do if my service is not available for creation:**
In general, if the service is in ECR it should be available for creation, so:
1. Check that it has not already been created, e.g. via the AWS console (CloudFormation) - find the relevant account
   [here](https://docs.tiatechnology.com/display/TC/AWS+Environments)
1. Check that your docker image has been successfully pushed to [ECR](https://eu-central-1.console.aws.amazon.com/ecr/repositories?region=eu-central-1)
1. Check that the image name is not on the ```excluded.stacks``` list, see below.

**If my new service or environment is unique and therefore needs special create/update script parameters**
1. Check what is default in the [services-setup-elb.sh](https://git.tiatechnology.com/arc/aws-operations/-/blob/master/cloudformation/servicesetup/service-setup-elb.sh)
   script, ultimately this is what gets called.
1. The input sections of the job gets info like: name, version and number of instances to run. If you need more, update this:
   [file](service-setup-elb.properties), like so:
  1. Add a property under the relevant section using this format:

     ```<service-name>-args=<extra-args>``` or for environment specific flags set ```<env-name>-args=<extra-args>```

_NB!_: Running on the external loadbalancer (api-lb) is the default. This means that if your service should not be publicly
available, you need to at least provide this information, e.g.: ```my-service-args=-l api-lb-internal```

An example of environment specific argument configuration could look like this: ```sbhdv-args=-G sbh-dv -f default,prod,sbh``` this will
add the specified configuration to all ```sbhdv``` deployments - _Notice!_ the ```<env-name>```-part of the property should match the environment name
displayed in the awsAccount selection dropdown.

**If I have an ECR/Artifactory repository that should not be available for creation**
1. Update [aws-deploy.properties](http://jenkins.tia.local:8080/job/aws-operations/configfiles/editConfig?id=aws-deploy.properties),
   by adding the ECR repository name e.g. _my-api_ to the ```excluded.stacks``` property. This can either be the full name or a
   regular expression.

