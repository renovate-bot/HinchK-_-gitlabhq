---
stage: Create
group: Code Review
info: "To determine the technical writer assigned to the Stage/Group associated with this page, see https://handbook.gitlab.com/handbook/product/ux/technical-writing/#assignments"
---

# Merge request approvals API

DETAILS:
**Tier:** Premium, Ultimate
**Offering:** GitLab.com, Self-managed, GitLab Dedicated

> - Changing approval configuration with the `/approvals` endpoint was [deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/11132) in GitLab 12.3.
> - Endpoint `/approvals` [removed](https://gitlab.com/gitlab-org/gitlab/-/issues/353097) in GitLab 16.0.

Configuration for
[approvals on all merge requests](../user/project/merge_requests/approvals/index.md)
in the project. Must be authenticated for all endpoints.

## Group-level MR approvals

DETAILS:
**Status:** Experiment

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/428051) in GitLab 16.7 [with a flag](../administration/feature_flags.md) named `approval_group_rules`. Disabled by default. This feature is an [Experiment](../policy/experiment-beta-support.md).

FLAG:
On self-managed GitLab, by default this feature is not available. To make it available, an administrator can [enable the feature flag](../administration/feature_flags.md) named `approval_group_rules`.
On GitLab.com and GitLab Dedicated, this feature is not available.
This feature is not ready for production use.

Group approval rules apply to all protected branches of projects belonging to the group. This feature is an [Experiment](../policy/experiment-beta-support.md).

### Get group-level approval rules

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/440638) in GitLab 16.10.

Group admins can request information about a group's approval rules using the following endpoint:

```plaintext
GET /groups/:id/approval_rules
```

Use the `page` and `per_page` [pagination](rest/index.md#offset-based-pagination) parameters to restrict the list of approval rules.

Supported attributes:

| Attribute | Type              | Required               | Description                                                                   |
|-----------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`      | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |

Example request:

```shell
curl --request GET --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/29/approval_rules"
```

Example response:

```json
[
  {
    "id": 2,
    "name": "rule1",
    "rule_type": "any_approver",
    "eligible_approvers": [],
    "approvals_required": 3,
    "users": [],
    "groups": [],
    "contains_hidden_groups": false,
    "protected_branches": [],
    "applies_to_all_protected_branches": true
  },
  {
    "id": 3,
    "name": "rule2",
    "rule_type": "code_owner",
    "eligible_approvers": [],
    "approvals_required": 2,
    "users": [],
    "groups": [],
    "contains_hidden_groups": false,
    "protected_branches": [],
    "applies_to_all_protected_branches": true
  }
]

```

### Create group-level approval rules

Group admins can create group level approval rules using the following endpoint:

```plaintext
POST /groups/:id/approval_rules
```

Supported attributes:

| Attribute                           | Type              | Required               | Description                                                                                                                                                                                                                                                         |
|-------------------------------------|-------------------|------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `id`                                | integer or string | Yes | The ID or [URL-encoded path of a group](rest/index.md#namespaced-path-encoding).                                                                                                                                                                                    |
| `approvals_required`                | integer           | Yes | The number of required approvals for this rule.                                                                                                                                                                                                                     |
| `name`                              | string            | Yes | The name of the approval rule.                                                                                                                                                                                                                                      |
| `group_ids`                         | array             | No | The IDs of groups as approvers.                                                                                                                                                                                                                                     |
| `report_type`                       | string            | No | The report type required when the rule type is `report_approver`. The supported report types are `license_scanning` [(Deprecated in GitLab 15.9)](../update/deprecations.md#license-check-and-the-policies-tab-on-the-license-compliance-page) and `code_coverage`. |
| `rule_type`                         | string            | No | The type of rule. `any_approver` is a pre-configured default rule with `approvals_required` at `0`. Other rules are `regular` (used for regular [merge request approval rules](../../ee/user/project/merge_requests/approvals/rules.md)) and `report_approver`. `report_approver` is used automatically when an approval rule is created from configured and enabled [merge request approval policies](../../ee/user/application_security/policies/scan-result-policies.md) and should not be used to create approval rule with this API. |
| `user_ids`                          | array             | No | The IDs of users as approvers.                                                                                                                                                       |

Example request:

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/29/approval_rules?name=security&approvals_required=2"
```

Example response:

```json
{
  "id": 5,
  "name": "security",
  "rule_type": "any_approver",
  "eligible_approvers": [],
  "approvals_required": 2,
  "users": [],
  "groups": [],
  "contains_hidden_groups": false,
  "protected_branches": [
    {
      "id": 5,
      "name": "master",
      "push_access_levels": [
        {
          "id": 5,
          "access_level": 40,
          "access_level_description": "Maintainers",
          "deploy_key_id": null,
          "user_id": null,
          "group_id": null
        }
      ],
      "merge_access_levels": [
        {
          "id": 5,
          "access_level": 40,
          "access_level_description": "Maintainers",
          "user_id": null,
          "group_id": null
        }
      ],
      "allow_force_push": false,
      "unprotect_access_levels": [],
      "code_owner_approval_required": false,
      "inherited": false
    }
  ],
  "applies_to_all_protected_branches": true
}
```

### Update group-level approval rules

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/440639) in GitLab 16.10.

Group admins can update group level approval rules using the following endpoint:

```shell
PUT /groups/:id/approval_rules/:approval_rule_id
```

Supported attributes:

| Attribute            | Type              | Required | Description                                                                                                                                          |
|----------------------|-------------------|----------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| `approval_rule_id`.  | integer           | Yes      | The ID of the approval rule.                                                                                                                         |
| `id`                 | integer or string | Yes      | The ID or [URL-encoded path of a group](rest/index.md#namespaced-path-encoding).                                                                     |
| `approvals_required` | string            | No       | The number of required approvals for this rule.                                                                                                      |
| `group_ids`          | integer           | No       | The IDs of users as approvers.                                                                                                                       |
| `name`               | string            | No       | The name of the approval rule.                                                                                                                       |
| `rule_type`          | array             | No       | The type of rule. `any_approver` is a pre-configured default rule with `approvals_required` at `0`. Other rules are `regular` (used for regular [merge request approval rules](../../ee/user/project/merge_requests/approvals/rules.md)) and `report_approver`. `report_approver` is used automatically when an approval rule is created from configured and enabled [merge request approval policies](../../ee/user/application_security/policies/scan-result-policies.md) and should not be used to create approval rule with this API. |
| `user_ids`           | array             | No       | The IDs of groups as approvers.                                                                                                                      |

Example request:

```shell
curl --request PUT --header "PRIVATE-TOKEN: <your_access_token>" \
  --url "https://gitlab.example.com/api/v4/groups/29/approval_rules/5?name=security2&approvals_required=1"
```

Example response:

```json
{
  "id": 5,
  "name": "security2",
  "rule_type": "any_approver",
  "eligible_approvers": [],
  "approvals_required": 1,
  "users": [],
  "groups": [],
  "contains_hidden_groups": false,
  "protected_branches": [
    {
      "id": 5,
      "name": "master",
      "push_access_levels": [
        {
          "id": 5,
          "access_level": 40,
          "access_level_description": "Maintainers",
          "deploy_key_id": null,
          "user_id": null,
          "group_id": null
        }
      ],
      "merge_access_levels": [
        {
          "id": 5,
          "access_level": 40,
          "access_level_description": "Maintainers",
          "user_id": null,
          "group_id": null
        }
      ],
      "allow_force_push": false,
      "unprotect_access_levels": [],
      "code_owner_approval_required": false,
      "inherited": false
    }
  ],
  "applies_to_all_protected_branches": true
}
```

## Project-level MR approvals

### Get Configuration

> - Moved to GitLab Premium in 13.9.
> - The `approvers` and `approver_groups` fields were deprecated in GitLab 12.3 and always return empty. Use the [project level approval rules](#get-project-level-rules) to access this information.

You can request information about a project's approval configuration using the
following endpoint:

```plaintext
GET /projects/:id/approvals
```

Supported attributes:

| Attribute | Type              | Required               | Description                                                                   |
|-----------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`      | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |

```json
{
  "approvers": [], // Deprecated in GitLab 12.3, always returns empty
  "approver_groups": [], // Deprecated in GitLab 12.3, always returns empty
  "approvals_before_merge": 2, // Deprecated in GitLab 12.3, use Approval Rules instead
  "reset_approvals_on_push": true,
  "selective_code_owner_removals": false,
  "disable_overriding_approvers_per_merge_request": false,
  "merge_requests_author_approval": true,
  "merge_requests_disable_committers_approval": false,
  "require_password_to_approve": true
}
```

### Change configuration

> - Moved to GitLab Premium in 13.9.

If you are allowed to, you can change approval configuration using the following
endpoint:

```plaintext
POST /projects/:id/approvals
```

Supported attributes:

| Attribute                                        | Type              | Required               | Description                                                                                                                                             |
|--------------------------------------------------|-------------------|------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `id`                                             | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding).                                                                           |
| `approvals_before_merge` (deprecated)            | integer           | No | How many approvals are required before a merge request can be merged. [Deprecated](https://gitlab.com/gitlab-org/gitlab/-/issues/11132) in GitLab 12.3. Use [Approval Rules](#create-project-level-rule) instead. |
| `disable_overriding_approvers_per_merge_request` | boolean           | No | Allow or prevent overriding approvers per merge request.                                                                                                |
| `merge_requests_author_approval`                 | boolean           | No | Allow or prevent authors from self approving merge requests; `true` means authors can self approve.                                                     |
| `merge_requests_disable_committers_approval`     | boolean           | No | Allow or prevent committers from self approving merge requests.                                                                                         |
| `require_password_to_approve`                    | boolean           | No | Require approver to enter a password to authenticate before adding the approval.                                                                        |
| `reset_approvals_on_push`                        | boolean           | No | Reset approvals on a new push.                                                                                                                          |
| `selective_code_owner_removals`                  | boolean           | No | Reset approvals from Code Owners if their files changed. Can be enabled only if `reset_approvals_on_push` is disabled.                                  |

```json
{
  "approvals_before_merge": 2, // Deprecated in GitLab 12.3, use Approval Rules instead
  "reset_approvals_on_push": true,
  "selective_code_owner_removals": false,
  "disable_overriding_approvers_per_merge_request": false,
  "merge_requests_author_approval": false,
  "merge_requests_disable_committers_approval": false,
  "require_password_to_approve": true
}
```

### Get project-level rules

> - Moved to GitLab Premium in 13.9.
> - Pagination support [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/31011) in GitLab 15.3 [with a flag](../administration/feature_flags.md) named `approval_rules_pagination`. Enabled by default.
> - `applies_to_all_protected_branches` property was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/335316) in GitLab 15.3.
> - Pagination support [generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/366823) in GitLab 15.7. Feature flag `approval_rules_pagination` removed.
> - `usernames` property was [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/102446) in GitLab 15.8.

You can request information about a project's approval rules using the following endpoint:

```plaintext
GET /projects/:id/approval_rules
```

Use the `page` and `per_page` [pagination](rest/index.md#offset-based-pagination) parameters to restrict the list of approval rules.

Supported attributes:

| Attribute | Type              | Required               | Description                                                                   |
|-----------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`      | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |

```json
[
  {
    "id": 1,
    "name": "security",
    "rule_type": "regular",
    "eligible_approvers": [
      {
        "id": 5,
        "name": "John Doe",
        "username": "jdoe",
        "state": "active",
        "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
        "web_url": "http://localhost/jdoe"
      },
      {
        "id": 50,
        "name": "Group Member 1",
        "username": "group_member_1",
        "state": "active",
        "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
        "web_url": "http://localhost/group_member_1"
      }
    ],
    "approvals_required": 3,
    "users": [
      {
        "id": 5,
        "name": "John Doe",
        "username": "jdoe",
        "state": "active",
        "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
        "web_url": "http://localhost/jdoe"
      }
    ],
    "groups": [
      {
        "id": 5,
        "name": "group1",
        "path": "group1",
        "description": "",
        "visibility": "public",
        "lfs_enabled": false,
        "avatar_url": null,
        "web_url": "http://localhost/groups/group1",
        "request_access_enabled": false,
        "full_name": "group1",
        "full_path": "group1",
        "parent_id": null,
        "ldap_cn": null,
        "ldap_access": null
      }
    ],
    "applies_to_all_protected_branches": false,
    "protected_branches": [
      {
        "id": 1,
        "name": "main",
        "push_access_levels": [
          {
            "access_level": 30,
            "access_level_description": "Developers + Maintainers"
          }
        ],
        "merge_access_levels": [
          {
            "access_level": 30,
            "access_level_description": "Developers + Maintainers"
          }
        ],
        "unprotect_access_levels": [
          {
            "access_level": 40,
            "access_level_description": "Maintainers"
          }
        ],
        "code_owner_approval_required": "false"
      }
    ],
    "contains_hidden_groups": false
  }
]
```

### Get a single project-level rule

> - Introduced in GitLab 13.7.
> - `applies_to_all_protected_branches` property was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/335316) in GitLab 15.3.
> - `usernames` property was [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/102446) in GitLab 15.8.

You can request information about a single project approval rules using the following endpoint:

```plaintext
GET /projects/:id/approval_rules/:approval_rule_id
```

Supported attributes:

| Attribute          | Type              | Required               | Description                                                                   |
|--------------------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`               | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |
| `approval_rule_id` | integer           | Yes | The ID of a approval rule.                                                    |

```json
{
  "id": 1,
  "name": "security",
  "rule_type": "regular",
  "eligible_approvers": [
    {
      "id": 5,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    },
    {
      "id": 50,
      "name": "Group Member 1",
      "username": "group_member_1",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/group_member_1"
    }
  ],
  "approvals_required": 3,
  "users": [
    {
      "id": 5,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    }
  ],
  "groups": [
    {
      "id": 5,
      "name": "group1",
      "path": "group1",
      "description": "",
      "visibility": "public",
      "lfs_enabled": false,
      "avatar_url": null,
      "web_url": "http://localhost/groups/group1",
      "request_access_enabled": false,
      "full_name": "group1",
      "full_path": "group1",
      "parent_id": null,
      "ldap_cn": null,
      "ldap_access": null
    }
  ],
  "applies_to_all_protected_branches": false,
  "protected_branches": [
    {
      "id": 1,
      "name": "main",
      "push_access_levels": [
        {
          "access_level": 30,
          "access_level_description": "Developers + Maintainers"
        }
      ],
      "merge_access_levels": [
        {
          "access_level": 30,
          "access_level_description": "Developers + Maintainers"
        }
      ],
      "unprotect_access_levels": [
        {
          "access_level": 40,
          "access_level_description": "Maintainers"
        }
      ],
      "code_owner_approval_required": "false"
    }
  ],
  "contains_hidden_groups": false
}
```

### Create project-level rule

> - Moved to GitLab Premium in 13.9.
> - [Removed](https://gitlab.com/gitlab-org/gitlab/-/issues/357300) the Vulnerability-Check feature in GitLab 15.0.
> - `applies_to_all_protected_branches` property was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/335316) in GitLab 15.3.
> - `usernames` property was [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/102446) in GitLab 15.8.

You can create project approval rules using the following endpoint:

```plaintext
POST /projects/:id/approval_rules
```

Supported attributes:

| Attribute                           | Type              | Required               | Description                                                                                                                                                                                                                     |
|-------------------------------------|-------------------|------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `id`                                | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding).                                                                                                                                                   |
| `approvals_required`                | integer           | Yes | The number of required approvals for this rule.                                                                                                                                                                                 |
| `name`                              | string            | Yes | The name of the approval rule.                                                                                                                                                                                                  |
| `applies_to_all_protected_branches` | boolean           | No | Whether the rule is applied to all protected branches. If set to `true`, the value of `protected_branch_ids` is ignored. Default is `false`. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/335316) in GitLab 15.3. |
| `group_ids`                         | Array             | No | The IDs of groups as approvers.                                                                                                                                                                                                 |
| `protected_branch_ids`              | Array             | No | The IDs of protected branches to scope the rule by. To identify the ID, [use the API](protected_branches.md#list-protected-branches).                                                                                           |
| `report_type`                       | string            | No | The report type required when the rule type is `report_approver`. The supported report types are `license_scanning` [(Deprecated in GitLab 15.9)](../update/deprecations.md#license-check-and-the-policies-tab-on-the-license-compliance-page) and `code_coverage`.                                                                                        |
| `rule_type`                         | string            | No | The type of rule. `any_approver` is a pre-configured default rule with `approvals_required` at `0`. Other rules are `regular` (used for regular [merge request approval rules](../../ee/user/project/merge_requests/approvals/rules.md)) and `report_approver`. `report_approver` is used automatically when an approval rule is created from configured and enabled [merge request approval policies](../../ee/user/application_security/policies/scan-result-policies.md) and should not be used to create approval rule with this API. |
| `user_ids`                          | Array             | No | The IDs of users as approvers. If you provide both `user_ids` and `usernames`, both lists of users are added. |
| `usernames`                         | string array      | No | The usernames of approvers for this rule (same as `user_ids` but requires a list of usernames). If you provide both `user_ids` and `usernames`, both lists of users are added. |

```json
{
  "id": 1,
  "name": "security",
  "rule_type": "regular",
  "eligible_approvers": [
    {
      "id": 2,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    },
    {
      "id": 50,
      "name": "Group Member 1",
      "username": "group_member_1",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/group_member_1"
    }
  ],
  "approvals_required": 1,
  "users": [
    {
      "id": 2,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    }
  ],
  "groups": [
    {
      "id": 5,
      "name": "group1",
      "path": "group1",
      "description": "",
      "visibility": "public",
      "lfs_enabled": false,
      "avatar_url": null,
      "web_url": "http://localhost/groups/group1",
      "request_access_enabled": false,
      "full_name": "group1",
      "full_path": "group1",
      "parent_id": null,
      "ldap_cn": null,
      "ldap_access": null
    }
  ],
  "applies_to_all_protected_branches": false,
  "protected_branches": [
    {
      "id": 1,
      "name": "main",
      "push_access_levels": [
        {
          "access_level": 30,
          "access_level_description": "Developers + Maintainers"
        }
      ],
      "merge_access_levels": [
        {
          "access_level": 30,
          "access_level_description": "Developers + Maintainers"
        }
      ],
      "unprotect_access_levels": [
        {
          "access_level": 40,
          "access_level_description": "Maintainers"
        }
      ],
      "code_owner_approval_required": "false"
    }
  ],
  "contains_hidden_groups": false
}
```

You can increase the default number of 0 required approvers like this:

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" \
  --header 'Content-Type: application/json' \
  --data '{"name": "Any name", "rule_type": "any_approver", "approvals_required": 2}'
```

Another example is creating an additional, user-specific rule:

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" \
  --header 'Content-Type: application/json' \
  --data '{"name": "Name of your rule", "approvals_required": 3, "user_ids": [123, 456, 789]}' \
  https://gitlab.example.com/api/v4/projects/<project_id>/approval_rules
```

### Update project-level rule

> - Moved to GitLab Premium in 13.9.
> - [Removed](https://gitlab.com/gitlab-org/gitlab/-/issues/357300) the Vulnerability-Check feature in GitLab 15.0.
> - `applies_to_all_protected_branches` property was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/335316) in GitLab 15.3.
> - `usernames` property was [introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/102446) in GitLab 15.8.

You can update project approval rules using the following endpoint:

```plaintext
PUT /projects/:id/approval_rules/:approval_rule_id
```

NOTE:
Approvers and groups (except hidden groups not in the `users` or `groups`
parameters) are **removed**. Hidden groups are private groups the user doesn't
have permission to view. Hidden groups are not removed by default unless the
`remove_hidden_groups` parameter is `true`. This ensures hidden groups are
not removed unintentionally when a user updates an approval rule.

Supported attributes:

| Attribute                           | Type              | Required               | Description                                                                                                                                                                                                                     |
|-------------------------------------|-------------------|------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `id`                                | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding).                                                                                                                                                   |
| `approvals_required`                | integer           | Yes | The number of required approvals for this rule.                                                                                                                                                                                 |
| `approval_rule_id`                  | integer           | Yes | The ID of a approval rule.                                                                                                                                                                                                      |
| `name`                              | string            | Yes | The name of the approval rule.                                                                                                                                                                                                  |
| `applies_to_all_protected_branches` | boolean           | No | Whether the rule is applied to all protected branches. If set to `true`, the value of `protected_branch_ids` is ignored. Default is `false`. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/335316) in GitLab 15.3. |
| `group_ids`                         | Array             | No | The IDs of groups as approvers.                                                                                                                                                                                                 |
| `protected_branch_ids`              | Array             | No | The IDs of protected branches to scope the rule by. To identify the ID, [use the API](protected_branches.md#list-protected-branches).                                                                                           |
| `remove_hidden_groups`              | boolean           | No | Whether hidden groups should be removed from approval rule. |
| `user_ids`                          | Array             | No | The IDs of users as approvers. If you provide both `user_ids` and `usernames`, both lists of users are added. |
| `usernames`                         | string array      | No | The usernames of approvers for this rule (same as `user_ids` but requires a list of usernames). If you provide both `user_ids` and `usernames`, both lists of users are added.|

```json
{
  "id": 1,
  "name": "security",
  "rule_type": "regular",
  "eligible_approvers": [
    {
      "id": 2,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    },
    {
      "id": 50,
      "name": "Group Member 1",
      "username": "group_member_1",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/group_member_1"
    }
  ],
  "approvals_required": 1,
  "users": [
    {
      "id": 2,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    }
  ],
  "groups": [
    {
      "id": 5,
      "name": "group1",
      "path": "group1",
      "description": "",
      "visibility": "public",
      "lfs_enabled": false,
      "avatar_url": null,
      "web_url": "http://localhost/groups/group1",
      "request_access_enabled": false,
      "full_name": "group1",
      "full_path": "group1",
      "parent_id": null,
      "ldap_cn": null,
      "ldap_access": null
    }
  ],
  "applies_to_all_protected_branches": false,
  "protected_branches": [
    {
      "id": 1,
      "name": "main",
      "push_access_levels": [
        {
          "access_level": 30,
          "access_level_description": "Developers + Maintainers"
        }
      ],
      "merge_access_levels": [
        {
          "access_level": 30,
          "access_level_description": "Developers + Maintainers"
        }
      ],
      "unprotect_access_levels": [
        {
          "access_level": 40,
          "access_level_description": "Maintainers"
        }
      ],
      "code_owner_approval_required": "false"
    }
  ],
  "contains_hidden_groups": false
}
```

### Delete project-level rule

> - Moved to GitLab Premium in 13.9.

You can delete project approval rules using the following endpoint:

```plaintext
DELETE /projects/:id/approval_rules/:approval_rule_id
```

Supported attributes:

| Attribute          | Type              | Required               | Description                                                                   |
|--------------------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`               | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |
| `approval_rule_id` | integer           | Yes | The ID of a approval rule.                                                    |

## Merge request-level MR approvals

Configuration for approvals on a specific merge request. Must be authenticated for all endpoints.

### Get Configuration

> - Moved to GitLab Premium in 13.9.

You can request information about a merge request's approval status using the
following endpoint:

```plaintext
GET /projects/:id/merge_requests/:merge_request_iid/approvals
```

Supported attributes:

| Attribute           | Type              | Required               | Description                                                                   |
|---------------------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`                | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |
| `merge_request_iid` | integer           | Yes | The IID of the merge request.                                                 |

```json
{
  "id": 5,
  "iid": 5,
  "project_id": 1,
  "title": "Approvals API",
  "description": "Test",
  "state": "opened",
  "created_at": "2016-06-08T00:19:52.638Z",
  "updated_at": "2016-06-08T21:20:42.470Z",
  "merge_status": "cannot_be_merged",
  "approvals_required": 2,
  "approvals_left": 1,
  "approved_by": [
    {
      "user": {
        "name": "Administrator",
        "username": "root",
        "id": 1,
        "state": "active",
        "avatar_url": "http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80\u0026d=identicon",
        "web_url": "http://localhost:3000/root"
      }
    }
  ]
}
```

### Get the approval state of merge requests

> - Moved to GitLab Premium in 13.9.

You can request information about a merge request's approval state by using the following endpoint:

```plaintext
GET /projects/:id/merge_requests/:merge_request_iid/approval_state
```

The `approval_rules_overwritten` are `true` if the merge request level rules
are created for the merge request. If there are none, it is `false`.

This includes additional information about the users who have already approved
(`approved_by`) and whether a rule is already approved (`approved`).

Supported attributes:

| Attribute           | Type              | Required               | Description                                                                   |
|---------------------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`                | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |
| `merge_request_iid` | integer           | Yes | The IID of the merge request.                                                 |

```json
{
  "approval_rules_overwritten": true,
  "rules": [
    {
      "id": 1,
      "name": "Ruby",
      "rule_type": "regular",
      "eligible_approvers": [
        {
          "id": 4,
          "name": "John Doe",
          "username": "jdoe",
          "state": "active",
          "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
          "web_url": "http://localhost/jdoe"
        }
      ],
      "approvals_required": 2,
      "users": [
        {
          "id": 4,
          "name": "John Doe",
          "username": "jdoe",
          "state": "active",
          "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
          "web_url": "http://localhost/jdoe"
        }
      ],
      "groups": [],
      "contains_hidden_groups": false,
      "approved_by": [
        {
          "id": 4,
          "name": "John Doe",
          "username": "jdoe",
          "state": "active",
          "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
          "web_url": "http://localhost/jdoe"
        }
      ],
      "source_rule": null,
      "approved": true,
      "overridden": false
    }
  ]
}
```

### Get merge request level rules

> - Moved to GitLab Premium in 13.9.
> - Pagination support [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/31011) in GitLab 15.3 [with a flag](../administration/feature_flags.md) named `approval_rules_pagination`. Enabled by default.
> - Pagination support [generally available](https://gitlab.com/gitlab-org/gitlab/-/issues/366823) in GitLab 15.7. Feature flag `approval_rules_pagination` removed.

You can request information about a merge request's approval rules using the following endpoint:

```plaintext
GET /projects/:id/merge_requests/:merge_request_iid/approval_rules
```

Use the `page` and `per_page` [pagination](rest/index.md#offset-based-pagination) parameters to restrict the list of approval rules.

Supported attributes:

| Attribute           | Type              | Required               | Description                                                                   |
|---------------------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`                | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |
| `merge_request_iid` | integer           | Yes | The IID of the merge request.                                                 |

```json
[
  {
    "id": 1,
    "name": "security",
    "rule_type": "regular",
    "eligible_approvers": [
      {
        "id": 5,
        "name": "John Doe",
        "username": "jdoe",
        "state": "active",
        "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
        "web_url": "http://localhost/jdoe"
      },
      {
        "id": 50,
        "name": "Group Member 1",
        "username": "group_member_1",
        "state": "active",
        "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
        "web_url": "http://localhost/group_member_1"
      }
    ],
    "approvals_required": 3,
    "source_rule": null,
    "users": [
      {
        "id": 5,
        "name": "John Doe",
        "username": "jdoe",
        "state": "active",
        "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
        "web_url": "http://localhost/jdoe"
      }
    ],
    "groups": [
      {
        "id": 5,
        "name": "group1",
        "path": "group1",
        "description": "",
        "visibility": "public",
        "lfs_enabled": false,
        "avatar_url": null,
        "web_url": "http://localhost/groups/group1",
        "request_access_enabled": false,
        "full_name": "group1",
        "full_path": "group1",
        "parent_id": null,
        "ldap_cn": null,
        "ldap_access": null
      }
    ],
    "contains_hidden_groups": false,
    "overridden": false
  }
]
```

### Get a single merge request level rule

> - [Introduced](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/82767) in GitLab 14.10.

You can request information about a single merge request approval rule using the following endpoint:

```plaintext
GET /projects/:id/merge_requests/:merge_request_iid/approval_rules/:approval_rule_id
```

Supported attributes:

| Attribute           | Type              | Required               | Description                                                                   |
|---------------------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`                | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |
| `approval_rule_id`  | integer           | Yes | The ID of an approval rule.                                                   |
| `merge_request_iid` | integer           | Yes | The IID of a merge request.                                                   |

```json
{
  "id": 1,
  "name": "security",
  "rule_type": "regular",
  "eligible_approvers": [
    {
      "id": 5,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    },
    {
      "id": 50,
      "name": "Group Member 1",
      "username": "group_member_1",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/group_member_1"
    }
  ],
  "approvals_required": 3,
  "source_rule": null,
  "users": [
    {
      "id": 5,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    }
  ],
  "groups": [
    {
      "id": 5,
      "name": "group1",
      "path": "group1",
      "description": "",
      "visibility": "public",
      "lfs_enabled": false,
      "avatar_url": null,
      "web_url": "http://localhost/groups/group1",
      "request_access_enabled": false,
      "full_name": "group1",
      "full_path": "group1",
      "parent_id": null,
      "ldap_cn": null,
      "ldap_access": null
    }
  ],
  "contains_hidden_groups": false,
  "overridden": false
}
```

### Create merge request level rule

> - Moved to GitLab Premium in 13.9.

You can create merge request approval rules using the following endpoint:

```plaintext
POST /projects/:id/merge_requests/:merge_request_iid/approval_rules
```

Supported attributes:

| Attribute                  | Type              | Required               | Description                                                                  |
|----------------------------|-------------------|------------------------|------------------------------------------------------------------------------|
| `id`                       | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding) |
| `approvals_required`       | integer           | Yes | The number of required approvals for this rule.                              |
| `merge_request_iid`        | integer           | Yes | The IID of the merge request.                                                |
| `name`                     | string            | Yes | The name of the approval rule.                                               |
| `approval_project_rule_id` | integer           | No | The ID of a project-level approval rule.                                     |
| `group_ids`                | Array             | No | The IDs of groups as approvers.                                              |
| `user_ids`                 | Array             | No | The IDs of users as approvers. If you provide both `user_ids` and `usernames`, both lists of users are added. |
| `usernames`                | string array      | No | The usernames of approvers for this rule (same as `user_ids` but requires a list of usernames). If you provide both `user_ids` and `usernames`, both lists of users are added. |

**Important:** When `approval_project_rule_id` is set, the `name`, `users` and
`groups` of project-level rule are copied. The `approvals_required` specified
is used.

```json
{
  "id": 1,
  "name": "security",
  "rule_type": "regular",
  "eligible_approvers": [
    {
      "id": 2,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    },
    {
      "id": 50,
      "name": "Group Member 1",
      "username": "group_member_1",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/group_member_1"
    }
  ],
  "approvals_required": 1,
  "source_rule": null,
  "users": [
    {
      "id": 2,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    }
  ],
  "groups": [
    {
      "id": 5,
      "name": "group1",
      "path": "group1",
      "description": "",
      "visibility": "public",
      "lfs_enabled": false,
      "avatar_url": null,
      "web_url": "http://localhost/groups/group1",
      "request_access_enabled": false,
      "full_name": "group1",
      "full_path": "group1",
      "parent_id": null,
      "ldap_cn": null,
      "ldap_access": null
    }
  ],
  "contains_hidden_groups": false,
  "overridden": false
}
```

### Update merge request level rule

> - Moved to GitLab Premium in 13.9.

You can update merge request approval rules using the following endpoint:

```plaintext
PUT /projects/:id/merge_requests/:merge_request_iid/approval_rules/:approval_rule_id
```

**Important:** Approvers and groups not in the `users`/`groups` parameters are **removed**

**Important:** Updating a `report_approver` or `code_owner` rule is not allowed.
These are system generated rules.

Supported attributes:

| Attribute              | Type              | Required               | Description                                                                   |
|------------------------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`                   | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |
| `approval_rule_id`     | integer           | Yes | The ID of an approval rule.                                                   |
| `merge_request_iid`    | integer           | Yes | The IID of a merge request.                                                   |
| `approvals_required`   | integer           |  No | The number of required approvals for this rule.                               |
| `group_ids`            | Array             | No | The IDs of groups as approvers.                                               |
| `name`                 | string            |  No | The name of the approval rule.                                                |
| `remove_hidden_groups` | boolean           | No | Whether hidden groups should be removed.                                      |
| `user_ids`             | Array             | No | The IDs of users as approvers. If you provide both `user_ids` and `usernames`, both lists of users are added. |
| `usernames`            | string array      | No | The usernames of approvers for this rule (same as `user_ids` but requires a list of usernames). If you provide both `user_ids` and `usernames`, both lists of users are added. |

```json
{
  "id": 1,
  "name": "security",
  "rule_type": "regular",
  "eligible_approvers": [
    {
      "id": 2,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    },
    {
      "id": 50,
      "name": "Group Member 1",
      "username": "group_member_1",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/group_member_1"
    }
  ],
  "approvals_required": 1,
  "source_rule": null,
  "users": [
    {
      "id": 2,
      "name": "John Doe",
      "username": "jdoe",
      "state": "active",
      "avatar_url": "https://www.gravatar.com/avatar/0?s=80&d=identicon",
      "web_url": "http://localhost/jdoe"
    }
  ],
  "groups": [
    {
      "id": 5,
      "name": "group1",
      "path": "group1",
      "description": "",
      "visibility": "public",
      "lfs_enabled": false,
      "avatar_url": null,
      "web_url": "http://localhost/groups/group1",
      "request_access_enabled": false,
      "full_name": "group1",
      "full_path": "group1",
      "parent_id": null,
      "ldap_cn": null,
      "ldap_access": null
    }
  ],
  "contains_hidden_groups": false,
  "overridden": false
}
```

### Delete merge request level rule

> - Moved to GitLab Premium in 13.9.

You can delete merge request approval rules using the following endpoint:

```plaintext
DELETE /projects/:id/merge_requests/:merge_request_iid/approval_rules/:approval_rule_id
```

**Important:** Deleting a `report_approver` or `code_owner` rule is not allowed.
These are system generated rules.

Supported attributes:

| Attribute           | Type              | Required               | Description                                                                   |
|---------------------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`                | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |
| `approval_rule_id`  | integer           | Yes | The ID of an approval rule.                                                   |
| `merge_request_iid` | integer           | Yes | The IID of the merge request.                                                 |

## Approve merge request

> - Moved to GitLab Premium in 13.9.

If you are allowed to, you can approve a merge request using the following
endpoint:

```plaintext
POST /projects/:id/merge_requests/:merge_request_iid/approve
```

Supported attributes:

| Attribute           | Type              | Required               | Description                                                                                                                                                                                            |
|---------------------|-------------------|------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `id`                | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding).                                                                                                                          |
| `approval_password` | string            | No | Current user's password. Required if [**Require user password to approve**](../user/project/merge_requests/approvals/settings.md#require-user-re-authentication-to-approve) is enabled in the project settings. |
| `merge_request_iid` | integer           | Yes | The IID of the merge request.                                                                                                                                                                          |
| `sha`               | string            | No | The `HEAD` of the merge request.                                                                                                                                                                       |

The `sha` parameter works in the same way as
when [accepting a merge request](merge_requests.md#merge-a-merge-request): if it is passed, then it must
match the current HEAD of the merge request for the approval to be added. If it
does not match, the response code is `409`.

```json
{
  "id": 5,
  "iid": 5,
  "project_id": 1,
  "title": "Approvals API",
  "description": "Test",
  "state": "opened",
  "created_at": "2016-06-08T00:19:52.638Z",
  "updated_at": "2016-06-09T21:32:14.105Z",
  "merge_status": "can_be_merged",
  "approvals_required": 2,
  "approvals_left": 0,
  "approved_by": [
    {
      "user": {
        "name": "Administrator",
        "username": "root",
        "id": 1,
        "state": "active",
        "avatar_url": "http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80\u0026d=identicon",
        "web_url": "http://localhost:3000/root"
      }
    },
    {
      "user": {
        "name": "Nico Cartwright",
        "username": "ryley",
        "id": 2,
        "state": "active",
        "avatar_url": "http://www.gravatar.com/avatar/cf7ad14b34162a76d593e3affca2adca?s=80\u0026d=identicon",
        "web_url": "http://localhost:3000/ryley"
      }
    }
  ]
}
```

## Unapprove merge request

> - Moved to GitLab Premium in 13.9.

If you did approve a merge request, you can unapprove it using the following
endpoint:

```plaintext
POST /projects/:id/merge_requests/:merge_request_iid/unapprove
```

Supported attributes:

| Attribute           | Type              | Required               | Description                                                                   |
|---------------------|-------------------|------------------------|-------------------------------------------------------------------------------|
| `id`                | integer or string | Yes | The ID or [URL-encoded path of a project](rest/index.md#namespaced-path-encoding). |
| `merge_request_iid` | integer           | Yes | The IID of a merge request.                                                   |

## Reset approvals of a merge request

Clear all approvals of merge request.

Available only for [bot users](../user/project/settings/project_access_tokens.md#bot-users-for-projects)
based on project or group tokens. Users without bot permissions receive a `401 Unauthorized` response.

```plaintext
PUT /projects/:id/merge_requests/:merge_request_iid/reset_approvals
```

| Attribute           | Type              | Required | Description                                                                                                     |
|---------------------|-------------------|----------|-----------------------------------------------------------------------------------------------------------------|
| `id`                | integer or string | Yes      | The ID or [URL-encoded path of the project](rest/index.md#namespaced-path-encoding) owned by the authenticated user. |
| `merge_request_iid` | integer           | Yes      | The internal ID of the merge request.                                                                           |

```shell
curl --request PUT --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/projects/76/merge_requests/1/reset_approvals"
```
