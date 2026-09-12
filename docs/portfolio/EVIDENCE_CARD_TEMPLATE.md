# Evidence Card — <short problem title>

Status: DRAFT
Milestone: <M#>
Evidence maturity: <E0–E5>
Source release SHA: <full SHA when measured>

## Context / assumption
Why is this scenario plausible? Separate assumptions from observed facts.

## Problem
What was actually observed? Do not state the intended solution here.

## Baseline
Record dataset/seed, workload/concurrency, environment/topology, release SHA, duration, relevant measurements or correctness outcome, and supporting SQL/plan/trace/log/CI evidence.

## Analysis
How was the cause narrowed? List evidence, not guesses.

## Options considered
Record meaningful alternatives, pros/cons, and why they were rejected or accepted.

## Decision / action
Describe the smallest implemented change and why it addresses the evidence.

## Verification
Repeat the same or equivalent condition. Record before, after, unchanged controls, regressions checked, and unexpected results. Do not hide a non-improvement.

## Trade-off / limit
What complexity, cost, failure mode, or limitation remains? What does this evidence not prove?

## Repository evidence
- code/config:
- migration:
- focused tests:
- workload/experiment:
- CI:
- runtime/query-plan/log evidence:

## Portfolio claim
One factual sentence suitable for a résumé/interview.

Avoid invented scale, production claims, generic technology lists, and percentage improvements without retained comparable measurements.
