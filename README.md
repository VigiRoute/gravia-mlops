# gravia-mlops

CI/CD et déploiement de [GRAVIA](https://github.com/VigiRoute/gravia) : IaC (Terraform), manifests
Kubernetes, workflows de déploiement. `gravia` **construit** la solution, `gravia-mlops` la
**déploie** (cf.
[gravia/docs/Architecture_GRAVIA.md](https://github.com/VigiRoute/gravia/blob/main/docs/Architecture_GRAVIA.md)).

Voir [docs/Deploiement_GRAVIA_MLOps.md](docs/Deploiement_GRAVIA_MLOps.md) pour le détail des
choix techniques (pourquoi `kind`, pourquoi LocalStack, comment lancer la démo locale, pièges
rencontrés et vérifications sur infra réelle).
