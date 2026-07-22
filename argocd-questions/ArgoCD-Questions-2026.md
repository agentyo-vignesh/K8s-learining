# ArgoCD Interview Questions — 3 Years Experience (2026)

Questions only. (Answers are in `argocd-demo/ArgoCD-Interview-Prep-2026.md`.)

---

## Scenario-Based Questions

1. An Application shows `OutOfSync` even though nobody pushed to Git. How do you debug and fix it?
2. ArgoCD reports `Synced` and `Healthy`, but users say the app is down. What's happening and how do you handle it?
3. You can't commit plaintext secrets to Git. How do you manage secrets with ArgoCD?
4. How do you promote the same app version through dev → staging → prod?
5. How do you scale ArgoCD to manage 200 clusters / 500 apps?
6. A bad deploy hit production — how do you roll it back the GitOps way?
7. Your namespace/CRDs must exist before the workloads that use them. How do you enforce sync ordering?

---

## Fundamentals

8. What is GitOps and how does ArgoCD implement it? (Pull vs push model.)
9. Explain the ArgoCD architecture: API server, Repo server, Application controller, Redis, Dex.
10. What's the difference between Sync Status and Health Status?
11. What are the sync policy options and what does each mean?
12. Difference between ArgoCD and Flux? When would you pick one?

---

## Intermediate

13. What is the App of Apps pattern and how does it differ from ApplicationSet? Why is ApplicationSet preferred now?
14. Explain ApplicationSet generators (List, Cluster, Git, Matrix, Merge, SCM Provider, Pull Request). Give a real use case for the Git and Cluster generators.
15. How do sync waves and resource hooks work? Give an example of each.
16. How does selfHeal work and when would it cause problems?
17. How do you configure RBAC in ArgoCD? Explain AppProjects and their role in multi-tenancy.
18. What is an AppProject and what can you restrict with it?
19. How does ArgoCD integrate Helm and Kustomize? What's a Config Management Plugin (CMP)?
20. What are ignoreDifferences and when do you use them?

---

## Advanced

21. How do you scale ArgoCD? Explain controller sharding.
22. How do you implement progressive delivery with ArgoCD? (Argo Rollouts.)
23. Write a custom Lua health check for a CRD — why would you need one?
24. How do you handle multi-cluster deployments? How are external clusters registered?
25. How does ArgoCD do drift detection and what are its limits?
26. Explain ArgoCD Notifications — triggers, templates, and integrations.
27. What is ArgoCD Image Updater and its two write-back methods?
28. How do you secure ArgoCD? (SSO, RBAC, TLS, disabling admin, secrets.)
29. What changed in ArgoCD 3.x?

---

## GitOps Design / Opinion

30. Mono-repo vs multi-repo for GitOps — trade-offs?
31. How do you structure repos for dev/staging/prod? Branch-per-env vs directory-per-env?
32. How do you prevent config drift AND still allow emergency manual changes?
33. Where does CI end and CD (ArgoCD) begin in your pipeline?

---

## Rapid-Fire

34. Pull vs push model — explain.
35. What triggers a sync?
36. How to speed up sync detection?
37. What is prune?
38. Where does ArgoCD store state?
39. What is the default sync wave?
40. How to exclude a resource from pruning?
41. What diffing mode is used for large CRDs?

---

## Behavioral / Experience

42. Walk me through an ArgoCD outage or incident you debugged.
43. How did you migrate from a push-based CD (e.g. Jenkins) to GitOps?
44. How do you onboard a new team onto your ArgoCD platform safely?
45. What's the biggest GitOps anti-pattern you've seen?
