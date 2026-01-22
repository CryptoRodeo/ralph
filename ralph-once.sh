set -e

# Run Ralph once
claude --permission-mode acceptEdits "@prd.json @progress.txt \
You are operating in a STRICT Ralph Loop.
If you attempt to work on more than one feature, you have FAILED this task.

=== EXECUTION CONTRACT ===
You MUST:
- Select EXACTLY ONE feature from prd.json that is NOT marked completed
- Work ONLY on that single feature
- Make ONLY the minimal changes required to implement that feature
- Update progress.txt with what you did
- If the feature becomes complete, mark ONLY THAT feature as completed in prd.json
- STOP IMMEDIATELY after completing this feature

You MUST NOT:
- Start, partially implement, or plan any other feature
- Refactor, clean up, or improve unrelated code
- Add follow-up features, enhancements, or “while I’m here” changes
- Continue after the single feature is done

=== STEP-BY-STEP ===
1. Choose the single highest-priority incomplete feature from prd.json.
   - Record its feature ID mentally and do not change it.
2. Implement ONLY that feature.
3. Validate using available feedback loops (types, tests, build).
4. Append a concise entry to progress.txt describing:
   - Feature worked on
   - Files changed
   - Current status
5. If and ONLY IF the feature is fully complete:
   - Mark it completed in prd.json

=== HARD STOP CONDITION ===
After step 4 (and step 5 if applicable):
- Output EXACTLY:
  <promise>STOP</promise>
- Then EXIT immediately.
- Do NOT continue reasoning, planning, or coding.

Any work beyond this point is a violation of this contract.
"
