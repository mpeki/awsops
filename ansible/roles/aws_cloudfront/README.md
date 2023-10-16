aws_cloudfront
=========

Role Description
----------------
Creates a cloudfront distribution in the customer account. This role makes some assumptions.

1. A Certificate has been imported
2. The certificate is in a PENDING_VALIDATION or ACTIVE status.

Secondly The role creates a route53 record in a hosted zone of our choosing.
route53 record creation is controlled by the customer variable flag: *route_53_enabled*: true|false


The route53 record can be created in the same customer account or in a shared account.


Requirements
------------
This Role requires that a certificate has been imported into the aws account before the role is run

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
project_name: "cjd, brd, com, spd"
role_region: "AWS region name"
route_53_enabled: true|false

### Role internal vars
# Thie role depends on the role `aws_sts_login`, whose variables can be found here:
# https://git.tiatechnology.com/arc/aws-operations/-/blob/master/ansible/roles/aws_sts_login/README.md

### Role defaults
---
stack_state: "{{ 'absent' if mode|lower == 'delete' else 'present' }}"

script_dir: "../../cloudformation/web"
# cloudfront stack name
cf_prefix_stack_name: cloudfront-distribution


# Default aws region which contains the acm imported certificate - don't change
aws_certificate_region: us-east-1
# Default domain also hosted zone name
certificate_domain_name: "*.example.com"
# route53 defaults
route53_account_role_name: profile_to_access_route53_resources
r53_prefix_stack_name: route53
```

Example Playbook
----------------

```yaml
---
- name: "{{ mode }} cloudfront Distribution"
  hosts: localhost
  gather_facts: false
  vars_files:
    - "{{ '../vars/cust/cust_' + cust_name + '.yml'}}"
    - "../vars/aws/accounts.yml"
  vars:
    var_role_region: "{{ cust_config[cust_name][env_name]['aws_profile'].region }}"

  tasks:
    - name: Validate cust_name/env_name
      assert:
        that:
          - cust_name is defined
          - env_name is defined
        fail_msg: "vars 'cust_name' and 'env_name' are required"

    - name: Validate project_name
      assert:
        that:
          - project_name | regex_search('^cjd|brd|com|spd$')
        fail_msg: "'project_name' var must be one of the following: cjd|brd|com|spd"

    - name: "{{ mode }} cloudfront"
      include_role:
        name: aws_cloudfront
      vars:
        role_region: "{{ var_role_region }}"
        project_name: "{{ project_name }}"
```

License
-------

BSD

Author Information
------------------

devops@tiatechnology.com
