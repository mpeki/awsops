aws_roles
=========

create fargate, ec2 and ecs roles for managing services in aws

Requirements
------------

Required by ansible Cloudformation module:

- boto
- boto3
- botocore>=1.5.45
- python >= 2.6

Role Variables
--------------

```yaml
### Role inputs
cust_name: "cust_shortname"
env_name: "env_shortname"
mode: "create" or "delete"
role_region: "AWS region name"

### Role internal vars
# Thie role depends on the role `aws_sts_login`, whose variables can be found here:
# https://git.tiatechnology.com/arc/aws-operations/-/blob/master/ansible/roles/aws_sts_login/README.md

### Role defaults
stack_state: "{{ 'absent' if mode|lower == 'delete' else 'present' }}"

script_dir: "../../cloudformation/access"
fargate_stack_name: CuSSP-roles-for-fargate
ecs_stack_name: CuSSP-roles-for-ecs
config_bucket_name: cussp-configs
ec2_stack_name: CuSSP-roles-for-ec2
```

Example Playbook
----------------

```yaml
---
- name: AWS roles
  hosts: localhost
  vars_files:
    - "{{ '../vars/cust/cust_' + cust_name + '.yml'}}"
  vars:
    var_role_region: "{{ cust_config[cust_name][env_name]['aws_profile'].region }}"

  tasks:
    - name: "{{ mode }} aws roles"
      include_role:
        name: aws_roles
      vars:
        role_region: "{{ var_role_region }}"
```

License
-------
BSD

Author Information
------------------

devops@tiatechnology.com
