aws_ec2
=========

Role Description
----------------
Creates autoscaling group for ec2-ecs, ecs-keypair if required

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
ec2_key_pair: "key pair name"
role_region: "AWS region name"

### Role internal vars
# Thie role depends on the role `aws_sts_login`, whose variables can be found here:
# https://git.tiatechnology.com/arc/aws-operations/-/blob/master/ansible/roles/aws_sts_login/README.md

### Role defaults
stack_state: "{{ 'absent' if mode|lower == 'delete' else 'present' }}"
# location of cloudformation scripts
script_dir: "../../cloudformation/compute"
# set our stack name as a variable
stack_name: CuSSP-ecs-auto-scaling-group
# Stack name of our network setup
network_stack_name: CuSSP-network
# Stack name of our intranet setup
intranet_stack_name: CuSSP-intranet
# Cluster name
ecs_cluster_name: cuspp-ecs-cluster
```

Example Playbook
----------------

```yaml
---
- name: EC2 auto-scaling group
  hosts: localhost
  vars_files:
    - "{{ '../vars/cust/cust_' + cust_name + '.yml'}}"
    - "../vars/aws/accounts.yml"
  vars:
    var_role_region: "{{ cust_config[cust_name][env_name]['aws_profile'].region }}"

  tasks:
    - name: "{{ mode }} ec2 autoscaling"
      include_role:
        name: aws_ec2
      vars:
        ec2_key_pair: "cussp-{{ cust_config[cust_name][env_name].account }}"
        role_region: "{{ var_role_region }}"
```

License
-------

BSD

Author Information
------------------

devops@tiatechnology.com