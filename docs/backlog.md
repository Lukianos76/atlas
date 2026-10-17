# Backlog

Réserve des tâches identifiées mais pas encore engagées. Chaque entrée renvoie au document qui l'a fait naître. Une entrée passe dans `docs/roadmap.md` avec l'accord du mainteneur.

- **Filtrer le trafic sortant du runner de Claude en CI** (par exemple `step-security/harden-runner` en mode blocage, avec une liste de domaines autorisés) : la liste d'outils de `.github/workflows/claude.yml` limite les usages ordinaires mais n'est pas une barrière ; seul un filtrage réseau empêcherait une exfiltration après injection de consignes. À tester sur un vrai run. Origine : revue de sécurité de la PR #7 (CLAUDE.md, Mode CI).
