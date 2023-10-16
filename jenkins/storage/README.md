# Pipeline: aws-s3-upload
As a pre-requisite, the designer project must configured for runtime configuration as opposed to build time
configuration.

Also, the build relies on a per-project ```deploy.sh``` script, this is called on two occasions which must be supported:

```bash
  ./deploy.sh -p <aws_profile> deploy
  ./deploy.sh -p <aws_profile> invalidate
```
The first should upload/deploy to the given aws_profile, the second should invalidate the AWS CloudFront cache. 
At the time of this writing, all designer projects take this approach.

## Where
The job location:
[Dashboard -> aws-operations -> storage -> s3-designer-upload](http://jenkins.tia.local:8080/job/aws-operations/job/storage/job/s3-designer-upload/)

Pipeline definition: [Jenkinsfile.aws-s3-upload](jenkins/storage/Jenkinsfile.aws-s3-upload)

Main aws-operations script: **N/A** - this pipeline uses ```deploy.sh``` scripts provided by each project.

## How
To run the job press: [Build Now](http://jenkins.tia.local:8080/job/aws-operations/job/storage/job/s3-designer-upload/build?delay=0sec).

When doing so, this is what happens:
* **Prompt for input**: This job is different from the _aws-ecs-cloudformation_ described above, in the sense that it prompts for
  input right away - it will ask for: a target
  * _AWS_ACCOUNT_ - a dropdown list of the aws account to upload to
  * _UPLOAD_ITEMS_ - a multi select checkbox list of the items (designers) to upload
  * _DRY_RUN_ - a checkbox toggling dryrun on/off
  * _DEPLOY_SPEC_ - a text field in which a deployment specification can be specified, see more [below](#Deployment-Specifications)

### Configuration

The AWS_ACCOUNT list is populated from this file [aws_accounts](access/config/aws_accounts)

UPLOAD_ITEMS must be specified in this configuration file: [s3-deploy.properties](jenkins/storage/s3-deploy.properties)
after updating this file, the job should be run in dryrun-mode.

**NB!** If either of these parameters are empty it is because to file is not available in the workspace - 
to fix this run the job in dryrun-mode without selecting any upload items. Then run the job again.

#### Defaults
This is a description af default properties and how to overwrite them.
```properties
default.project.branch=master
``` 
During deployment the project is checked out, this is done because of the need to use the 
projects ```deploy.sh``` script, this property can be overwritten by providing a solution specific property like so:
```properties
<solution-name>.project.branch=development
```
```properties
default.app.dist.dir=dist
```
Per default archives downloaded from repo.

```default.app.config.dir=config```

### Adding New Upload Items
This is done by updating: [s3-deploy.properties](jenkins/storage/s3-deploy.properties) i.e.:
1. Add an item to the ```solutions``` property, the item name must match the base name used in the configuration repository.
1. Add the following properties for the item:
    1. ```<item-name>.project.url```: The https url of the projects git repository.
    1. ```<item-name>.config.url```: The https url of the projects configuration repository.
    1. ```<item-name>.repo.path```: The path to binaries in repo.tiatechology.com, to get versions from.
    1. ```<item-name>.versions.pattern```: arguments for linux sed to use when extracting versions.
  
**NB!** If no ```<item-name>.config.url``` is provided the project binary will be extracted and uploaded without configuration.

**NB!** **NB!** if the project is a path within a mono-repository set ```<item-name>.project.root``` to this path.q

## Deployment Specifications
Adding a deployment specification makes it possible to execute the job from another build.

After each successful deployment, a deployment specification for that deployment is generated. This can be edited and used in subsequent deployments.
