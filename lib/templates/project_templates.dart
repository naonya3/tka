const Map<String, String> projectTemplates = {
  'sample': '''
version: 2
name: sample
description: General-purpose task tracker. A minimal starting point for any workflow.
fields:
  detail:
    type: string
    description: What needs to be done. The agent reads this on the todo→in_progress transition.
states:
  initial: todo
  guide:
    todo: Read the ticket title and detail. When ready to start, transition to in_progress.
    in_progress: Work on the task. Transition to done when complete, or back to todo if blocked.
    done: Task is complete. No further action needed.
  transitions:
    todo: [in_progress]
    in_progress: [done, todo]
''',
  'tdd': '''
version: 2
name: tdd
description: Test-driven development cycle. Machine-enforces the Red-Green-Refactor discipline — verify gates run the ticket's test_cmd, so progress cannot be self-reported.
fields:
  detail:
    type: string
    description: What feature or behavior to implement. The agent reads this on the todo state to decide what test to write.
  test_cmd:
    type: string
    description: Shell command that runs the test for this ticket (e.g. "dart test test/foo_test.dart"). The verify gates run it on every transition, so it must be set before leaving todo.
  history:
    type: list
    description: Append-only progress notes (e.g. "Wrote failing test", "Implementation passes locally").
states:
  initial: todo
  guide:
    todo: 'Read detail, write a FAILING test for the behavior, and set test_cmd via tka update {{id}} --set test_cmd=... Then transition to red — the gate runs test_cmd and blocks unless it fails (no implementation yet).'
    red: 'The failing test is confirmed. Write the minimum code to make it pass, then transition to green — the gate re-runs test_cmd and blocks while it fails.'
    green: 'Test passes. Refactor if the code needs it (transition to refactor), otherwise transition to done — the gate re-runs test_cmd to catch regressions.'
    refactor: 'Improve structure without changing behavior. Transition to done when satisfied — the gate re-runs test_cmd — or back to green if new tests are needed.'
    done: Implementation complete. The test passed at every gate.
  transitions:
    todo:
      targets: [red]
      verify:
        red: '[ -n "\$TKA_TICKET_FIELD_TEST_CMD" ] || { echo "Set test_cmd before leaving todo." >&2; exit 1; }; if sh -c "\$TKA_TICKET_FIELD_TEST_CMD" >/dev/null 2>&1; then echo "test_cmd passes, but red requires a FAILING test. Write the test first." >&2; exit 1; fi'
    red:
      targets: [green, todo]
      verify:
        green: 'sh -c "\$TKA_TICKET_FIELD_TEST_CMD"'
    green:
      targets: [refactor, done]
      verify:
        done: 'sh -c "\$TKA_TICKET_FIELD_TEST_CMD"'
    refactor:
      targets: [done, green]
      verify:
        done: 'sh -c "\$TKA_TICKET_FIELD_TEST_CMD"'
''',
  'review-loop': '''
version: 2
name: review-loop
description: Iterative review and revision cycle. Useful for writing, documentation, or code review.
fields:
  detail:
    type: string
    description: What is being drafted/written. Read on the draft state.
  target:
    type: string
    description: Success criteria — audience, format, and quality bar the draft must meet to be approved.
  history:
    type: list
    description: Append-only log of review findings, fixes applied, and revision decisions.
states:
  initial: draft
  guide:
    draft: Create the initial draft. Focus on getting content down rather than perfection. Transition to review when ready for feedback.
    review: Review the draft against the target criteria. Record findings in history. Transition to fix if issues found, or to approved if quality is acceptable.
    fix: Address the issues identified during review. Transition back to review when fixes are applied.
    approved: Draft has passed review. Transition to done to finalize.
    done: Work is finalized and published.
  transitions:
    draft: [review]
    review: [fix, approved]
    fix: [review]
    approved: [done]
''',
  'bug-hunt': '''
version: 2
name: bug-hunt
description: Bug lifecycle from report to verified fix. Tracks reproduction steps and expected vs actual behavior.
fields:
  reproduce:
    type: string
    description: Step-by-step instructions an agent can follow to trigger the bug locally.
  expected:
    type: string
    description: What should happen at the end of the reproduce steps.
  actual:
    type: string
    description: What actually happens — the broken behavior — observed when following the reproduce steps.
  history:
    type: list
    description: Append-only investigation log — hypotheses, findings, attempted fixes.
states:
  initial: reported
  guide:
    reported: A bug has been reported. Read the title and reproduction steps. Transition to investigating to begin analysis, or to wontfix if the behavior is intentional.
    investigating: Reproduce the bug and identify the root cause. Document findings in history. Transition to fixing once the cause is understood.
    fixing: Implement the fix. Write a regression test if possible. Transition to verifying when the fix is ready.
    verifying: Verify the fix resolves the issue and no regressions are introduced. Transition to done if verified, or back to fixing if the issue persists.
    wontfix: Closed as intentional behavior or not worth fixing.
    done: Bug is fixed and verified.
  transitions:
    reported: [investigating, wontfix]
    investigating: [fixing, wontfix]
    fixing: [verifying]
    verifying: [done, fixing]
''',
  'agent-harness': '''
version: 2
name: agent-harness
description: Multi-agent task orchestration. Tracks assignment, execution, and results across agents.
fields:
  detail:
    type: string
    description: The handoff brief — what the assigned agent should accomplish, with enough context to act without asking back.
  agent:
    type: string
    description: Identifier of the agent assigned to execute this task (e.g. "claude-sonnet-4-6", "gpt-5", "internal-pipeline").
  priority:
    type: enum
    values: [p0, p1, p2, p3]
    description: "p0=critical, p1=high, p2=medium, p3=low"
  result:
    type: string
    description: Final output or error message produced by the executing agent on completion or failure.
  history:
    type: list
    description: Append-only progress log written by the executing agent — useful for retries and debugging.
states:
  initial: queued
  guide:
    queued: Task is waiting for assignment. Set the agent field and transition to assigned.
    assigned: Agent is assigned. Review the task detail and prepare to execute. Transition to running when execution begins.
    running: Agent is actively working. Update history with progress. Transition to done on success, failed on error, or blocked if waiting on a dependency.
    failed: Execution failed. Record the error in result. Transition to queued to reassign, or to running to retry.
    blocked: Waiting on an external dependency. Document what is blocking in history. Transition to queued when unblocked.
    done: Task completed successfully. Result field contains the output.
  transitions:
    queued: [assigned]
    assigned: [running]
    running: [done, failed, blocked]
    failed: [queued, running]
    blocked: [queued]
''',
  'evolve': '''
version: 2
name: evolve
description: Hypothesis-driven improvement loop. Test ideas with measurable outcomes.
fields:
  hypothesis:
    type: string
    description: A specific, falsifiable claim — "if we change X, then Y will improve". The whole experiment hinges on this.
  metric:
    type: string
    description: What to measure (e.g. "p95 response time", "conversion rate"). Must be the same units as baseline and result.
  baseline:
    type: number
    description: Current value of the metric before the experiment. Set during the idea state.
  result:
    type: number
    description: Measured value of the metric after the experiment. Compared against baseline to accept or reject the hypothesis.
  history:
    type: list
    description: Append-only log of experiment design choices, intermediate observations, and decision rationale.
states:
  initial: idea
  guide:
    idea: Define a hypothesis and the metric to measure. Set baseline value. Transition to experiment when the experiment design is ready.
    experiment: Run the experiment as designed. Do not change the hypothesis mid-experiment. Transition to measuring when data collection is complete.
    measuring: Compare result against baseline. Record findings in history. Transition to accepted if the hypothesis is supported, or to rejected if not.
    accepted: Hypothesis confirmed. Apply the improvement permanently.
    rejected: Hypothesis not supported. Review findings and transition to idea to form a new hypothesis.
  transitions:
    idea: [experiment]
    experiment: [measuring]
    measuring: [accepted, rejected]
    rejected: [idea]
''',
};

const Map<String, String> templateDescriptions = {
  'sample': 'General-purpose task tracker with todo/in_progress/done workflow',
  'tdd': 'Test-driven development enforcing Red-Green-Refactor discipline',
  'review-loop': 'Iterative review and revision cycle for writing or code review',
  'bug-hunt': 'Bug lifecycle from report through investigation to verified fix',
  'agent-harness': 'Multi-agent task orchestration with assignment and execution tracking',
  'evolve': 'Hypothesis-driven improvement loop with measurable outcomes',
};
