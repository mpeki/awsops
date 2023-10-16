# Jenkins AWS Ops
This folder contains Jenkins pipelines for triggering AWS-operations, each sub-folder is named
after the [cloudformation](../cloudformation) based folder in which the main script, the pipeline is concerned with, lives. 

TOC:

* [aws-ecs-cloudformation](servicesetup/README.md): Handle AWS ECS stacks via CloudFormation
* [aws-s3-upload](storage/README.md): Upload runtime (deploy time) configured UIs (Designers) to S3
