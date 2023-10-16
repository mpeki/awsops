aws_loadbalancer
=========

Role Description
----------------
This role sets up the internal and external load balancers. It creates the listeners and default rules/actions

On deletion, it deletes both ELBs, and all of their logs from the -logs bucket.

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
log_bucket_name: "Name of the S3 Bucket for log: eg 'cussp-sandbox-logs'"

### Role internal vars
# Thie role depends on the role `aws_sts_login`, whose variables can be found here:
# https://git.tiatechnology.com/arc/aws-operations/-/blob/master/ansible/roles/aws_sts_login/README.md

### Role defaults
stack_state: "{{ 'absent' if mode|lower == 'delete' else 'present' }}"

script_dir: "../../cloudformation/loadbalancing"
# Stack name for load balancer
elb_stack_name: CuSSP-internet-service-elb
# Stack name of our network setup
network_stack_name: CuSSP-network
# Name of our Application Load Balancer
elb_name: api-lb
```


Example Playbook
----------------

```yaml
---
- name: Elastic load balancer set up
  hosts: localhost
  vars_files:
    - "{{ '../vars/cust/cust_' + cust_name + '.yml' }}"
  vars:
    var_role_region: "{{ cust_config[cust_name][env_name]['aws_profile'].region }}"

  tasks:
    - name: "{{ mode }} loadbalancer for aws"
      include_role:
        name: aws_loadbalancer
      vars:
        role_region: "{{ var_role_region }}"
        log_bucket_name: "cussp-{{ cust_config[cust_name][env_name].account }}-logs"
```

License
-------

BSD

Author Information
------------------

devops@tiatechnology.com
