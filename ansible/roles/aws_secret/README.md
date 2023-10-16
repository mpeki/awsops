AWS Secret
=========

Role to create the roles and policies required for the ecsTaskExecutionRole to pull images from Artifactory.

Each account will contain a secret managed by AWS SecretsManager, due to the techinical limitations of fargate, which prevent ecs from accessing a secret in a different AWS account.

Requirements
------------

This role has a requirement for IAM_CAPABILTITES, which is required by AWS to create policies and attach them to roles.

The permissions grant full access to secrets for the ops user this is required to create read and update, and delete a secret.

The second set of permissions allow the Fargate ecsTaskExecutionRole to read the secret and pull an image from Artifactory

Role Variables
--------------

```yaml
### Role inputs
cust_name: "cust_shortname"
env_name: "env_shortname"
mode: "create" or "delete"
artifactory_username: "passed in or stored in vault"
artifactory_password: "passed in or stored in vault"
role_region: "AWS region name"
task_execution_role: "ecsTaskExecutionRole"

# Artifactory_username AND  artifactory_password are combined into a json string and placed in the Secrets Manager.

### Role internal vars
# Thie role depends on the role `aws_sts_login`, whose variables can be found here:
# https://git.tiatechnology.com/arc/aws-operations/-/blob/master/ansible/roles/aws_sts_login/README.md

### Role defaults
script_dir: "../../cloudformation/access"
stack_name: "artifactory-secrets-setup"
secret_id: "artifactory-ro"
stack_state: "{{ 'absent' if mode|lower == 'delete' else 'present' }}"
```

Example Playbook
----------------

```yaml
---
- name: Manage Secret
  hosts: localhost
  vars_files:
    - "{{ '../vars/cust/cust_' + cust_name + '.yml' }}"
    - "../vars/aws/credentials_vault.yml"

  tasks:
    - name: "{{ mode }} aws secret"
      include_role:
        name: aws_secret
      vars:
        role_region: "{{ cust_config[cust_name][env_name]['aws_profile'].region }}"
        artifactory_username: "{{ credentials_vault['repo.tiatechnology.com'].username }}"
        artifactory_password: "{{ credentials_vault['repo.tiatechnology.com'].password }}"
        stack_state: "{{ 'present' if mode|lower == 'create' else 'absent' }}"
```

License
-------

BSD

Author Information
------------------

devops@tiatechnology.com
