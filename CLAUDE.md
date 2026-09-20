# CLAUDE.md : gravia-mlops

## Contexte

`gravia-mlops` est le second des deux dépôts exigés par la certification (RNCP Architecte en
Intelligence Artificielle, projet GRAVIA) : **[gravia](https://github.com/VigiRoute/gravia)
construit** la solution (pipelines de données, modèle, API), **`gravia-mlops` la déploie**
(IaC Terraform, manifests Kubernetes, workflows de déploiement). Voir
[gravia/CLAUDE.md](https://github.com/VigiRoute/gravia/blob/main/CLAUDE.md) pour le contexte
complet du projet.

Documentation du déploiement (pourquoi `kind`, pourquoi LocalStack et sa vraie limite, comment
reproduire la démo K8s/Terraform, pièges rencontrés, vérifications sur infra réelle) :
[docs/Deploiement_GRAVIA_MLOps.md](docs/Deploiement_GRAVIA_MLOps.md), à lire avant de proposer un
changement d'architecture de déploiement, pour ne pas re-découvrir un piège déjà documenté.

## Structure

```
gravia-mlops/
├── k8s/                     # manifests Kubernetes (déploiement du serving GRAVIA)
├── terraform/               # IaC prod (LocalStack → AWS) : network, storage, compute, mlops
├── docs/                    # documentation de déploiement
└── .github/workflows/       # CD
```

## Workflow Git

Mêmes règles que `gravia` :

⚠️ **Ne jamais merger une branche depuis le terminal.** L'utilisateur merge lui-même depuis
l'interface GitHub. Créer la PR (`gh pr create`) reste possible sur demande.

✅ **Toute nouvelle branche créée doit être immédiatement poussée sur `origin`.**
