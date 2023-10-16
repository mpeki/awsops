aws_shared_servies
=========

deploy shared services and required policies

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
service: "One of the following supported services: activemq, elasticsearch, policy, rds, redis"
mq_user: "Active mq admin username"
mq_password: "Active mq admin password"

cust_vars:
  cust:
    env:
      elasticsearch:
        enforce_ssl: true|false (enforce ssl communication with cluster) -defaults to false
        use_encryption: true|false (use encryption at rest) - defaults to false
        node_to_node_encryption: true|false (node to node encryption) - defaults to false

### Role internal vars
# Thie role depends on the role `aws_sts_login`, whose variables can be found here:
# https://git.tiatechnology.com/arc/aws-operations/-/blob/master/ansible/roles/aws_sts_login/README.md

### Role defaults
# defaults file for aws_shared_services
stack_state: "{{ 'absent' if mode|lower == 'delete' else 'present' }}"

# Common network vars
script_dir: "../../cloudformation/network"
network_stack_name: CuSSP-network
intranet_stack_name: CuSSP-intranet

# RDS vars
rdb_script_dir: "../../cloudformation/database"
rds_subnet_stack_name: CuSSP-RDS-subnet
rds_parametergroup_stack_name: CuSSP-RDS-parametergroup

# Redis vars
redis_script_dir: "../../cloudformation/elasticache"
redis_subnet_stack_name: CuSSP-redis-subnet-sec
redis_stack_name: CuSSP-redis
redis_instance_type: cache.t2.micro

# Active MQ vars
mq_script_dir: "../../cloudformation/integration"
mq_security_stack_name: CuSSP-MQ-security
mq_setup_stack_name: CuSSP-MQ-setup
mq_broker_name: CuSSP-MQ
mq_instance_type: mq.t2.micro
mq_dns_name: amq

# Elasticsearch vars
es_script_dir:  "../../cloudformation/elasticsearch"
es_stack_name: CuSSP-elasticsearch
es_role_stack_name: Cussp-elasticsearch-service-role
es_instance_type: t3.small.elasticsearch

```

Example Playbook
----------------

```yaml
---
- name: "{{ mode }} shared services"
  hosts: localhost
  vars_files:
    - "{{ '../vars/cust/cust_' + cust_name + '.yml'}}"
  vars:
    var_role_region: "{{ cust_config[cust_name][env_name]['aws_profile'].region }}"

  tasks:
    - name: Validate service
      assert:
        that:
          - service | regex_search('^activemq|elasticsearch|policy|rds|redis$')
        fail_msg: "'service' var must be one of the following: activemq|elasticsearch|policy|rds|redis"

    - name: "{{ mode }} shared services"
      include_role:
        name: aws_shared_services
      vars:
        role_region: "{{ var_role_region }}"
        mq_user: "{{ cust_config[cust_name][env_name]['aws_profile'].amq_username }}"
        mq_password: "{{ cust_config[cust_name][env_name]['aws_profile'].amq_password }}"
```

License
-------

BSD

Author Information
------------------

devops@tiatechnology.com
