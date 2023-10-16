aws_rds
=========

Manage AWS RDS services

This role creates/deletes AWS RDS resources using a common cloudformation template.
https://docs.ansible.com/ansible/latest/collections/amazon/aws/cloudformation_module.html#ansible-collections-amazon-aws-cloudformation-module

Requirements
------------

Required by ansible Cloudformation module:

- boto
- boto3
- botocore>=1.5.45
- python >= 2.6

Dependencies
--------------

Calls the role `aws_sts_login` to obtain valid AWS credentials, which are then consumed by the cloudformation module. This role in turn needs the `aws_vault` secret, in order to decrypt the passwords.

Role Variables
--------------

The following input vars are required:

```yaml
  mode: 'create' or 'delete'
  cust_name: 'customer short name' eg 'rnd'
  env_name: 'environment short name' eg 'sandbox', 'prod'
  role_region: 'aws region name' eg 'eu-central-1'
  db_name: 'name of RDS database to be created' eg 'claims-api' or 'trd-api'
```

Within the role, `defaults/main.yml` contains all of the variables which are either processed or passed through to the Cloudformation template.

The role works correctly with these defaults for most uses cases, howevever if you do wish to use different values, take care that the Cloudformation template will accept your non-default values.
Cloud formation has its own variable validation built into the template, which Ansible has no control over.

One variable is extra special and warrants extra attention: `rds_db_user`.

In addition to controlling the database username, it has other functions too, inside of the cloud formation template.
It is also used as the `DBName`. The DB name may only contain alphanumeric values, so additional regex filtering to performed on `rds_db_user` to remove hyphens and underscores before being passed into the Cloudformation template.

`rds_service_name` is also set to `rds_db_name`.

`rds_db_password` is derived from `rds_db_name`.

To deploy a read replica we add a top level cust var `rds_create_read_replica` if the variable is not present it defaults to false.  

Example:
```yaml
cust:
  env:
    rds_create_read_replica: true

```


Example Playbook
----------------

```yaml
- name: AWS RDS set up
  hosts: localhost
  gather_facts: false
  vars_files:
    - "{{ '../vars/cust/cust_' + cust_name + '.yml' }}"
  tasks:
    - name: "{{ mode }} AWS RDS service"
      include_role:
        name: aws_rds
      vars:
        role_region: "{{ cust_config[cust_name][env_name]['aws_profile'].region }}"
        db_name: "{{ db_name }}"
```
Call with :

    ansible-playbook -v playbooks/rds.yml -e mode=create -e cust_name=rnd -e env_name=sandbox -e db_name=claims-api


License
-------

BSD

Author Information
------------------

devops@tiatechnology.com
