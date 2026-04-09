# Ausarbeitung Notes

This folder collects project decisions and implementation notes that are useful
for the written report (`Ausarbeitung`) and presentation.

## Files

- `disaster-recovery.md`
  Documents the disaster recovery concept, including the separation between VM
  self-healing and Firestore data recovery, the monitoring path, and the final
  live demo flow used in the presentation.
- `load-balancer-migration.md`
  Documents the move from a single externally addressed app VM to a
  load-balanced Managed Instance Group, including the deployment changes,
  operational issues we hit, and the final architecture rationale.
- `claude-chat-decisions.md`
  Synthesizes the Claude chat history for this repository into a structured
  decision log, including which ideas were adopted, changed later, or
  superseded.
- `claude-chat-appendix.md`
  Appendix of the Claude sessions found in the local Claude project store for
  this repository, including titles, dates, main discussion topics, and notable
  outcomes.

## Suggested use in the report

- Use the "Initial situation" and "Problem" sections to explain why the old
  deployment was not ideal for `N > 1`.
- Use the "Architecture decisions" section to justify why Terraform and the
  startup script now own the app deployment while Ansible remains responsible
  for the monitoring VM.
- Use `disaster-recovery.md` for the resilience chapter, especially when you
  want to explain the difference between app-instance recovery and Firestore
  data recovery.
- Use the "Observed issues and fixes" section as material for lessons learned
  or troubleshooting.
- Use the "Final result" section for presentation notes and grading-related
  arguments around IaaS, automation, monitoring, self-healing, and bonus load
  balancing.
- Use `claude-chat-decisions.md` when you want to show that the final
  architecture was not arbitrary, but the result of multiple design iterations.
- Use `claude-chat-appendix.md` as a source appendix or internal working note
  for the written report.
