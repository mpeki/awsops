aws_s3
=========

Update bucket policy document allowing access to s3 resources. This policy is kept in a shared account. This Role can only update the policy for the admin account it Will not delete the policy.
Next we add the required ssh keys to a shared bucket in the shared account. This key is used by the config-server to read the configuation for the services. Currently we use the same key across multiple envs.

Lastly cloudformation stack creates an s3 bucket in the new account. 

Creating an Environment
-----------------------

This role Acts on both an Admin account with shared resources and a customer environment. We store some config and access information which is accessed by customer accounts. 
1. Edit vars/aws/accounts.yml adding account information
2. commit and push
3. run role in create mode

Deleting an Environment
-------------------

1. Edit vars/aws/accounts.yml remove references to the Environment we are removing.
2. commit and push
3. Run the role in delete mode

Result: The resource access policy in the account containing the shared S3 resources will be updated removing access for the Deleted Account.

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

script_dir: "../../cloudformation/storage"
admin_buckets_stack_name:  CuSSP-s3-buckets
admin_buckets_policy_stack_name: "{{ admin_buckets_stack_name }}-policies"
admin_bucket_name: cussp
```

Example Playbook
----------------

```yaml
---
# AWS s3, playbook can be used to both Create or delete the s3 stacks. Passing either Create or delete as an extra var.
- name: AWS S3 set up
  hosts: localhost
  vars_files:
    - "{{ '../vars/cust/cust_' + cust_name + '.yml'}}"
    - "../vars/aws/accounts.yml"
  vars:
    var_role_region: "{{ cust_config[cust_name][env_name]['aws_profile'].region }}"

  tasks:
    - name: "{{ mode }} s3 setup for aws"
      include_role:
        name: aws_s3
      vars:
        role_region: "{{ var_role_region }}"
```

License
-------

BSD

Author Information
------------------

devops@tiatechnology.com
