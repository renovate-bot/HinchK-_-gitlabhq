---
stage: AI-powered
group: Duo Chat
info: Any user with at least the Maintainer role can merge updates to this content. For details, see https://docs.gitlab.com/ee/development/development_processes.html#development-guidelines-review.
---

# GitLab Duo Chat

[Chat](../../user/gitlab_duo_chat.md) is a part of the [GitLab Duo](../../user/ai_features.md) offering.

How Chat describes itself: "I am GitLab Duo Chat, an AI assistant focused on helping developers with DevSecOps,
software development, source code, project management, CI/CD, and GitLab. Please feel free to engage me in these areas."

Chat can answer different questions and perform certain tasks. It's done with the help of [prompts](glossary.md) and [tools](#adding-a-new-tool).

To answer a user's question asked in the Chat interface, GitLab sends a [GraphQL request](https://gitlab.com/gitlab-org/gitlab/-/blob/4cfd0af35be922045499edb8114652ba96fcba63/ee/app/graphql/mutations/ai/action.rb) to the Rails backend.
Rails backend sends then instructions to the Large Language Model (LLM) via the [AI Gateway](../../architecture/blueprints/ai_gateway/index.md).

## Set up GitLab Duo Chat

There is a difference in the setup for Saas and self-managed instances.
We recommend to start with a process described for SaaS-only AI features.

1. [Setup SaaS-only AI features](index.md#test-saas-only-ai-features-locally).
1. [Setup self-managed AI features](index.md#test-ai-features-with-ai-gateway-locally).

## Working with GitLab Duo Chat

Prompts are the most vital part of GitLab Duo Chat system. Prompts are the instructions sent to the LLM to perform certain tasks.

The state of the prompts is the result of weeks of iteration. If you want to change any prompt in the current tool, you must put it behind a feature flag.

If you have any new or updated prompts, ask members of AI Framework team to review, because they have significant experience with them.

### Troubleshooting

When working with Chat locally, you might run into an error. Most commons problems are documented in this section.
If you find an undocumented issue, you should document it in this section after you find a solution.

| Problem                                               | Solution |
| ----------------------------------------------------- | -------- |
| There is no Chat button in the GitLab UI.             | Make sure your user is a part of a group with enabled Experimental and Beta features. |
| Chat replies with "Forbidden by auth provider" error. | Backend can't access LLMs. Make sure your [AI Gateway](index.md#test-ai-features-with-ai-gateway-locally) is setup correctly. |
| Requests takes too long to appear in UI  | Consider restarting Sidekiq by running `gdk restart rails-background-jobs`. If that doesn't work, try `gdk kill` and then `gdk start`. Alternatively, you can bypass Sidekiq entirely. To do that temporary alter `Llm::CompletionWorker.perform_async` statements with `Llm::CompletionWorker.perform_inline` |

## Contributing to GitLab Duo Chat

From the code perspective, Chat is implemented in the similar fashion as other AI features. Read more about GitLab [AI Abstraction layer](index.md#abstraction-layer).

The Chat feature uses a [zero-shot agent](https://gitlab.com/gitlab-org/gitlab/blob/master/ee/lib/gitlab/llm/chain/agents/zero_shot/executor.rb) that includes a system prompt explaining how the large language model should interpret the question and provide an
answer. The system prompt defines available tools that can be used to gather
information to answer the user's question.

The zero-shot agent receives the user's question and decides which tools to use to gather information to answer it.
It then makes a request to the large language model, which decides if it can answer directly or if it needs to use one
of the defined tools.

The tools each have their own prompt that provides instructions to the large language model on how to use that tool to
gather information. The tools are designed to be self-sufficient and avoid multiple requests back and forth to
the large language model.

After the tools have gathered the required information, it is returned to the zero-shot agent, which asks the large language
model if enough information has been gathered to provide the final answer to the user's question.

### Adding a new tool

To add a new tool:

1. Create files for the tool in the `ee/lib/gitlab/llm/chain/tools/` folder. Use existing tools like `issue_identifier` or
   `resource_reader` as a template.

1. Write a class for the tool that includes:

    - Name and description of what the tool does
    - Example questions that would use this tool
    - Instructions for the large language model on how to use the tool to gather information - so the main prompts that
      this tool is using.

1. Test and iterate on the prompt using RSpec tests that make real requests to the large language model.
    - Prompts require trial and error, the non-deterministic nature of working with LLM can be surprising.
    - Anthropic provides good [guide](https://docs.anthropic.com/claude/docs/introduction-to-prompt-design) on working on prompts.
    - GitLab [guide](prompts.md) on working with prompts.

1. Implement code in the tool to parse the response from the large language model and return it to the zero-shot agent.

1. Add the new tool name to the `tools` array in `ee/lib/gitlab/llm/completions/chat.rb` so the zero-shot agent knows about it.

1. Add tests by adding questions to the test-suite for which the new tool should respond to. Iterate on the prompts as needed.

The key things to keep in mind are properly instructing the large language model through prompts and tool descriptions,
keeping tools self-sufficient, and returning responses to the zero-shot agent. With some trial and error on prompts,
adding new tools can expand the capabilities of the Chat feature.

There are available short [videos](https://www.youtube.com/playlist?list=PL05JrBw4t0KoOK-bm_bwfHaOv-1cveh8i) covering this topic.

## Debugging

To gather more insights about the full request, use the `Gitlab::Llm::Logger` file to debug logs.
The default logging level on production is `INFO` and **must not** be used to log any data that could contain personal identifying information.

To follow the debugging messages related to the AI requests on the abstraction layer, you can use:

```shell
export LLM_DEBUG=1
gdk start
tail -f log/llm.log
```

## Testing GitLab Duo Chat

Because the success of answers to user questions in GitLab Duo Chat heavily depends
on toolchain and prompts of each tool, it's common that even a minor change in a
prompt or a tool impacts processing of some questions.

To make sure that a change in the toolchain doesn't break existing
functionality, you can use the following RSpec tests to validate answers to some
predefined questions when using real LLMs:

1. `ee/spec/lib/gitlab/llm/completions/chat_real_requests_spec.rb`
   This test validates that the zero-shot agent is selecting the correct tools
   for a set of Chat questions. It checks on the tool selection but does not
   evaluate the quality of the Chat response.
1. `ee/spec/lib/gitlab/llm/chain/agents/zero_shot/qa_evaluation_spec.rb`
   This test evaluates the quality of a Chat response by passing the question
   asked along with the Chat-provided answer and context to at least two other
   LLMs for evaluation. This evaluation is limited to questions about issues and
   epics only. Learn more about the [GitLab Duo Chat QA Evaluation Test](#gitlab-duo-chat-qa-evaluation-test).

If you are working on any changes to the GitLab Duo Chat logic, be sure to run
the [GitLab Duo Chat CI jobs](#testing-with-ci) the merge request that contains
your changes. Some of the CI jobs must be [manually triggered](../../ci/jobs/job_control.md#run-a-manual-job).

## Testing locally

To run the QA Evaluation test locally, the following environment variables
must be exported:

```ruby
export VERTEX_AI_EMBEDDINGS='true' # if using Vertex embeddings
export ANTHROPIC_API_KEY='<key>' # can use dev value of Gitlab::CurrentSettings
export VERTEX_AI_CREDENTIALS='<vertex-ai-credentials>' # can set as dev value of Gitlab::CurrentSettings.vertex_ai_credentials
export VERTEX_AI_PROJECT='<vertex-project-name>' # can use dev value of Gitlab::CurrentSettings.vertex_ai_project

REAL_AI_REQUEST=1 bundle exec rspec ee/spec/lib/gitlab/llm/completions/chat_real_requests_spec.rb
```

When you update the test questions that require documentation embeddings,
make sure you [generate a new fixture](index.md#use-embeddings-in-specs) and
commit it together with the change.

## Testing with CI

The following CI jobs for GitLab project run the tests tagged with `real_ai_request`:

- `rspec-ee unit gitlab-duo-chat-zeroshot`:
  the job runs `ee/spec/lib/gitlab/llm/completions/chat_real_requests_spec.rb`.
  The job must be manually triggered and is allowed to fail.

- `rspec-ee unit gitlab-duo-chat-qa`:
  The job runs the QA evaluation tests in
  `ee/spec/lib/gitlab/llm/chain/agents/zero_shot/qa_evaluation_spec.rb`.
  The job must be manually triggered and is allowed to fail.
  Read about [GitLab Duo Chat QA Evaluation Test](#gitlab-duo-chat-qa-evaluation-test).

- `rspec-ee unit gitlab-duo-chat-qa-fast`:
  The job runs a single QA evaluation test from `ee/spec/lib/gitlab/llm/chain/agents/zero_shot/qa_evaluation_spec.rb`.
  The job is always run and not allowed to fail. Although there's a chance that the QA test still might fail,
  it is cheap and fast to run and intended to prevent a regression in the QA test helpers.

- `rspec-ee unit gitlab-duo pg14`:
  This job runs tests to ensure that the GitLab Duo features are functional without running into system errors.
  The job is always run and not allowed to fail.
  This job does NOT conduct evaluations. The quality of the feature is tested in the other jobs such as QA jobs.

### Management of credentials and API keys for CI jobs

All API keys required to run the rspecs should be [masked](../../ci/variables/index.md#mask-a-cicd-variable)

The exception is GCP credentials as they contain characters that prevent them from being masked.
Because the CI jobs need to run on MR branches, GCP credentials cannot be added as a protected variable
and must be added as a regular CI variable.
For security, the GCP credentials and the associated project added to
GitLab project's CI must not be able to access any production infrastructure and sandboxed.

### GitLab Duo Chat QA Evaluation Test

Evaluation of a natural language generation (NLG) system such as
GitLab Duo Chat is a rapidly evolving area with many unanswered questions and ambiguities.

A practical working assumption is LLMs can generate a reasonable answer when given a clear question and a context.
With the assumption, we are exploring using LLMs as evaluators
to determine the correctness of a sample of questions
to track the overall accuracy of GitLab Duo Chat's responses and detect regressions in the feature.

For the discussions related to the topic,
see [the merge request](https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/merge_requests/431)
and [the issue](https://gitlab.com/gitlab-org/gitlab/-/issues/427251).

The current QA evaluation test consists of the following components.

#### Epic and issue fixtures

The fixtures are the replicas of the _public_ issues and epics from projects and groups _owned by_ GitLab.
The internal notes were excluded when they were sampled. The fixtures have been commited into the canonical `gitlab` repository.
See [the snippet](https://gitlab.com/gitlab-org/gitlab/-/snippets/3613745) used to create the fixtures.

#### RSpec and helpers

1. [The RSpec file](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/spec/lib/gitlab/llm/chain/agents/zero_shot/qa_evaluation_spec.rb)
   and the included helpers invoke the Chat service, an internal interface with the question.

1. After collecting the Chat service's answer,
   the answer is injected into a prompt, also known as an "evaluation prompt", that instructs
   a LLM to grade the correctness of the answer based on the question and a context.
   The context is simply a JSON serialization of the issue or epic being asked about in each question.

1. The evaluation prompt is sent to two LLMs, Claude and Vertex.

1. The evaluation responses of the LLMs are saved as JSON files.

1. For each question, RSpec will regex-match for `CORRECT` or `INCORRECT`.

#### Collection and tracking of QA evaluation with CI/CD automation

The `gitlab` project's CI configurations have been setup to run the RSpec,
collect the evaluation response as artifacts and execute
[a reporter script](https://gitlab.com/gitlab-org/gitlab/-/blob/master/scripts/duo_chat/reporter.rb)
that automates collection and tracking of evaluations.

When `rspec-ee unit gitlab-duo-chat-qa` job runs in a pipeline for a merge request,
the reporter script uses the evaluations saved as CI artifacts
to generate a Markdown report and posts it as a note in the merge request.

To keep track of and compare QA test results over time, you must manually
run the `rspec-ee unit gitlab-duo-chat-qa` on the `master` the branch:

1. Visit the [new pipeline page](https://gitlab.com/gitlab-org/gitlab/-/pipelines/new).
1. Select "Run pipeline" to run a pipeline against the `master` branch
1. When the pipeline first starts, the `rspec-ee unit gitlab-duo-chat-qa` job under the
   "Test" stage will not be available. Wait a few minutes for other CI jobs to
   run and then manually kick off this job by selecting the "Play" icon.

When the test runs on `master`, the reporter script posts the generated report as an issue,
saves the evaluations artfacts as a snippet, and updates the tracking issue in
[`GitLab-org/ai-powered/ai-framework/qa-evaluation#1`](https://gitlab.com/gitlab-org/ai-powered/ai-framework/qa-evaluation/-/issues/1)
in the project [`GitLab-org/ai-powered/ai-framework/qa-evaluation`](<https://gitlab.com/gitlab-org/ai-powered/ai-framework/qa-evaluation>).

## GraphQL Subscription

The GraphQL Subscription for Chat behaves slightly different because it's user-centric. A user could have Chat open on multiple browser tabs, or also on their IDE.
We therefore need to broadcast messages to multiple clients to keep them in sync. The `aiAction` mutation with the `chat` action behaves the following:

1. All complete Chat messages (including messages from the user) are broadcasted with the `userId`, `aiAction: "chat"` as identifier.
1. Chunks from streamed Chat messages and currently used tools are broadcasted with the `userId`, `resourceId`, and the `clientSubscriptionId` from the mutation as identifier.

Note that we still broadcast chat messages and currently used tools using the `userId` and `resourceId` as identifier.
However, this is deprecated and should no longer be used. We want to remove `resourceId` on the subscription as part of [this issue](https://gitlab.com/gitlab-org/gitlab/-/issues/420296).

## Testing GitLab Duo Chat in production-like environments

GitLab Duo Chat is enabled in the [Staging](https://staging.gitlab.com) and
[Staging Ref](https://staging-ref.gitlab.com/) GitLab environments.

Because GitLab Duo Chat is currently only available to members of groups in the
Premium and Ultimate tiers, Staging Ref may be an easier place to test changes as a GitLab
team member because
[you can make yourself an instance Admin in Staging Ref](https://handbook.gitlab.com/handbook/engineering/infrastructure/environments/staging-ref/#admin-access)
and, as an Admin, easily create licensed groups for testing.

## Product Analysis

To better understand how the feature is used, each production user input message is analyzed using LLM and Ruby,
and the analysis is tracked as a Snowplow event.

The analysis can contain any of the attributes defined in the latest [iglu schema](https://gitlab.com/gitlab-org/iglu/-/blob/master/public/schemas/com.gitlab/ai_question_category/jsonschema).

- All possible "category" and "detailed_category" are listed [here](https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/gitlab/llm/fixtures/categories.xml).
- The following are yet to be implemented:
  - "is_proper_sentence"
  - "asked_on_the_same_page"
- The following are deprecated:
  - "number_of_questions_in_history"
  - "length_of_questions_in_history"
  - "time_since_first_question"

[Dashboards](https://handbook.gitlab.com/handbook/engineering/development/data-science/duo-chat/#-dashboards-internal-only) can be created to visualize the collected data.

## How `access_duo_chat` policy works

In the table below I present what requirements must be fulfilled so the `access_duo_chat` policy would return `true` in different
contexts.

|                                                                      | on SaaS                                                                                                                                                                  | on Self-managed                                                                                                                                                                      |
|----------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| for user (`user.can?(:access_duo_chat)`)                             | User need to belong to at least one group on Ultimate tier and with `experiment_and_beta_features` group setting switched on                                             | Instance need to be on Ultimate tier and instance need to have `instance_level_ai_beta_features_enabled` setting switched on                                                         |
| for user in group context (`user.can?(:access_duo_chat, group)`)     | User need to be a member of that group, root ancestor group of this group needs to be on Ultimate tier and with `experiment_and_beta_features` group setting switched on | Instance need to be on Ultimate tier and instance need to have `instance_level_ai_beta_features_enabled` setting switched on, user needs to have at least _read_ permission to group |
| for user in project context (`user.can?(:access_duo_chat, project)`) | User need to be a member of that project, project needs to have root ancestor group on Ultimate tier and with `experiment_and_beta_features` group setting switched on   | Instance need to be on Ultimate tier and instance need to have `instance_level_ai_beta_features_enabled` setting switched on, user needs to have at least _read_ permission to project |
