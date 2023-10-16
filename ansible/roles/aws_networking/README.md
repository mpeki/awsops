aws_networking
=========

Create or destroy the networking and security policy, and VPNs for AWS accounts which Tia services are deployed into.

The role uses cloudformation templates to create or destroy stacks.

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

script_dir: "../../cloudformation/network"
vpc_network_stack_name: CuSSP-network
internet_stack_name: CuSSP-internet
intranet_stack_name: CuSSP-intranet
internet_security_stack_name: CuSSP-internet-security
intranet_security_stack_name: CuSSP-intranet-security
local_dns_name: cussp.local
```

Example Playbook
----------------

```yaml
---
- name: AWS networking
  hosts: localhost
  vars_files:
    - "{{ '../vars/cust/cust_' + cust_name + '.yml' }}"
  vars:
    var_role_region: "{{ cust_config[cust_name][env_name]['aws_profile'].region }}"

  tasks:
    - name: "{{ mode }} aws networking"
      include_role:
        name: aws_networking
      vars:
        customer_ipv4_address: "{{ cust_config[cust_name][env_name]['aws_network'].customer_ipv4_address }}"
        vpc_cidr_prefix: "{{ cust_config[cust_name][env_name]['aws_network'].vpc_cidr_prefix }}"
        dest_cidr_block: "{{ cust_config[cust_name][env_name]['aws_network'].dest_cidr_block }}"
        role_region: "{{ var_role_region }}"
```

License
-------

BSD

Author Information
------------------

devops@tiatechnology.com
