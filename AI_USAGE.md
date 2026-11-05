# AI usage: dsc26-flt-w04

AI tools are allowed in this task. Fill in every section in your own words. This file is read by your Track Mentor, not by the grader.

## 1. Tools I used

ChatGPT: I used it to understand the requirements, discuss implementation ideas, review my code, and investigate issues.

Flutter test and Flutter analyze: I used them to verify my implementation and check for errors.
## 2. My best prompts

<!-- Paraphrasing is fine. -->

1.Explain the outbox requirements step by step and help me understand how persistence, retries, and synchronization should work.
2.Review my existing Flutter code against the task requirements, identify possible issues, and explain how to fix them without replacing my implementation.

## 3. One bug I found in AI-generated outbox or layout code, and how

One issue was in the retry delay calculation. The delay must be capped at 300 seconds starting from the seventh attempt, not later. I noticed this by comparing the calculated sequence with the task requirements and testing the retryDelay function. I corrected the condition and ran the test again to verify it.

I do not copy and paste generated code. I first try to understand the logic, discuss anything I do not understand, and then write the code myself. I also test my implementation instead of relying only on AI suggestions.
## 4. Why 409 is a success, and why corrections are appended after an attempt

A 409 response means the server already has this outcome, so sending it again is unnecessary. It is treated as success because the outcome has already been received by the server. If an entry has already been attempted, we cannot be sure whether the server received it or not. Therefore, a correction is appended as a new entry instead of replacing the original, preserving its ID and preventing us from losing track of a previous attempt.