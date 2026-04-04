const Map<String, String> projectTemplates = {
  'sample': '''
version: 1
name: sample
description: Sample project
fields:
  title:  { type: string, required: true }
  detail: { type: string }
states:
  initial: todo
  transitions:
    todo: [in_progress]
    in_progress: [done, todo]
''',
  'tdd': '''
version: 1
name: tdd
description: TDD development cycle
fields:
  title:    { type: string, required: true }
  detail:   { type: string }
  test_cmd: { type: string }
  history:  { type: list }
states:
  initial: todo
  transitions:
    todo: [red]
    red: [green, todo]
    green: [refactor, done]
    refactor: [done, green]
''',
  'review-loop': '''
version: 1
name: review-loop
description: Self-review improvement loop
fields:
  title:   { type: string, required: true }
  detail:  { type: string }
  target:  { type: string }
  history: { type: list }
states:
  initial: draft
  transitions:
    draft: [review]
    review: [fix, approved]
    fix: [review]
    approved: [done]
''',
  'bug-hunt': '''
version: 1
name: bug-hunt
description: Bug discovery and fix cycle
fields:
  title:     { type: string, required: true }
  reproduce: { type: string }
  expected:  { type: string }
  actual:    { type: string }
  history:   { type: list }
states:
  initial: reported
  transitions:
    reported: [investigating, wontfix]
    investigating: [fixing, wontfix]
    fixing: [verifying]
    verifying: [done, fixing]
''',
  'agent-harness': '''
version: 1
name: agent-harness
description: Multi-agent task orchestration
fields:
  title:   { type: string, required: true }
  detail:  { type: string }
  agent:   { type: string }
  priority:
    type: enum
    values: [p0, p1, p2, p3]
    description: "p0=critical, p1=high, p2=medium, p3=low"
  result:  { type: string }
  history: { type: list }
states:
  initial: queued
  transitions:
    queued: [assigned]
    assigned: [running]
    running: [done, failed, blocked]
    failed: [queued, running]
    blocked: [queued]
''',
  'evolve': '''
version: 1
name: evolve
description: Self-improvement hypothesis loop
fields:
  title:      { type: string, required: true }
  hypothesis: { type: string }
  metric:     { type: string }
  baseline:   { type: number }
  result:     { type: number }
  history:    { type: list }
states:
  initial: idea
  transitions:
    idea: [experiment]
    experiment: [measuring]
    measuring: [accepted, rejected]
    rejected: [idea]
''',
};

const Map<String, String> templateDescriptions = {
  'sample': 'Sample project',
  'tdd': 'TDD development cycle',
  'review-loop': 'Self-review improvement loop',
  'bug-hunt': 'Bug discovery and fix cycle',
  'agent-harness': 'Multi-agent task orchestration',
  'evolve': 'Self-improvement hypothesis loop',
};
