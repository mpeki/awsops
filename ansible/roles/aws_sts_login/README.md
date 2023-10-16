aws_sts_login
=========

Small reuable role to get a login token in order to assume the required AWS role, to deploy cloudformation tasks.


Role Variables
--------------
Internally the tasks within this role require access to the credentials vault, which is stored in `vars/main/aws_credentials_vault.yml`. Therefore ansible must have the vault secret `aws_vault` loaded into context, before calling the role.

The role requires the access key, secret key, region of the "admin" account: an account which has the permissions to assume the required role.

```yaml
### Role inputs
aws_access_key: "{{ admin_access_key }}"
aws_secret_key: "{{ admin_secret_access_key }}"
role_region: "AWS region name"

### Role defaults
admin: "{{ false | bool }}"

### Role outputs:
The sts_creds are registered in a var "assumed_role"

assumed_role.sts_creds.access_key
assumed_role.sts_creds.secret_key
assumed_role.sts_creds.session_token
```



Example Playbook
----------------

This role is not typically called directly by a playbook. Instead, top-level roles call *this* role as a "sub-role", like this:

```yaml
---
- name: Authenticate to sts
  import_role:
    name: aws_sts_login
  vars:
    admin_access_key: "{{ aws_credentials_vault[cust_config[cust_name][env_name]['aws_profile'].admin_role_name].access_key }}"
    admin_secret_access_key: "{{ aws_credentials_vault[cust_config[cust_name][env_name]['aws_profile'].admin_role_name].secret_access_key }}"
    assume_role_arn: "{{ aws_credentials_vault[cust_config[cust_name][env_name]['aws_profile'].role_name].role_arn }}"
    assume_role_session_name: "ansible-{{ mode }}-{{ role_name }}"
    role_region: "{{ role_region }}"
```

Role Invocation example
----------------
```yaml

- name: authenticate to sts
  import_role:
    name: aws_sts_login
  vars:
    admin_access_key: "{{ aws_credentials_vault[cust_config[cust_name][env_name]['aws_profile'].admin_role_name].access_key }}"
    admin_secret_access_key: "{{ aws_credentials_vault[cust_config[cust_name][env_name]['aws_profile'].admin_role_name].secret_access_key }}"
    role_region: "{{ role_region }}"
    assume_role_arn: "{{ aws_credentials_vault[cust_config[cust_name][env_name]['aws_profile'].role_name].role_arn }}"
    assume_role_session_name: "ansible-{{ mode }}-{{ role_name }}"
```
License
-------

BSD

Author Information
------------------

devops@tiatechnology.com
