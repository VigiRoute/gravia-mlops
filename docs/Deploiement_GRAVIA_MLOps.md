# Déploiement — GRAVIA-MLOps

`gravia-mlops` est le second des deux dépôts exigés par la certification (RNCP Architecte en
Intelligence Artificielle, projet GRAVIA) : [`gravia`](https://github.com/VigiRoute/gravia)
**construit** la solution (pipelines de données, modèle, API), `gravia-mlops` la **déploie**
(IaC Terraform, manifests Kubernetes, workflows de déploiement). Voir
[`gravia/CLAUDE.md`](https://github.com/VigiRoute/gravia/blob/main/CLAUDE.md) et
[`gravia/docs/Architecture_GRAVIA.md`](https://github.com/VigiRoute/gravia/blob/main/docs/Architecture_GRAVIA.md)
pour le contexte complet du projet et les choix d'architecture de la solution elle-même.

## Structure

```
gravia-mlops/
├── k8s/                     # manifests Kubernetes (déploiement du serving GRAVIA)
├── terraform/               # IaC prod (LocalStack → AWS) : network, storage, compute, mlops
└── .github/workflows/       # CD
```

## Kubernetes (`kind`)

### Pourquoi `kind` (Kubernetes in Docker)

**Le problème à résoudre** : le CDC exige des manifests Kubernetes pour la cible de production
(EKS, cf.
[`gravia/docs/Architecture_GRAVIA.md`](https://github.com/VigiRoute/gravia/blob/main/docs/Architecture_GRAVIA.md) :
scaling et haute disponibilité du serving). Sans budget cloud, impossible de déployer sur un vrai
EKS. LocalStack (utilisé pour Terraform, cf. section dédiée ci-dessous) n'est pas la bonne
réponse pour ça : **constaté en testant**, l'édition Community (gratuite) refuse même ECR (403
« not included within your LocalStack license ») — EKS n'est pas mieux loti, et de toute façon
une émulation d'API ne remplace pas un vrai control-plane Kubernetes exécutant de vrais Pods. Un
autre outil est nécessaire ici.

**La solution retenue : `kind`** (kubernetes-sigs/kind, v0.33.0, image de nœud figée par digest —
cf. `k8s/kind-config.yaml`). `kind` crée un **vrai cluster Kubernetes** en utilisant des
conteneurs Docker comme « nœuds » — gratuit, léger, standard pour ce type de
démonstration/CI.

**Ce que ça démontre** (même logique que LocalStack pour Terraform, cf.
[`gravia/docs/Architecture_GRAVIA.md` §2.1](https://github.com/VigiRoute/gravia/blob/main/docs/Architecture_GRAVIA.md)) :
les manifests K8s (`Deployment`, `Service`, `ConfigMap`, `Secret`) sont **réellement
exécutables** — Pods qui démarrent, health checks qui passent, scaling et auto-guérison qui
fonctionnent pour de vrai, pas des fichiers YAML jamais testés. **Ce que ça ne démontre pas** :
la haute disponibilité multi-nœuds/multi-AZ d'un vrai EKS (un seul nœud ici) ni une charge de
production réelle. C'est le rôle de la cible AWS/EKS, documentée mais non déployée.

**Alternative écartée : `minikube`** — équivalent fonctionnel à `kind`, mais `kind` a été
préféré car plus léger (pas de VM, uniquement des conteneurs) et plus proche de l'esprit
« éphémère, reproductible » déjà adopté pour LocalStack côté `gravia`.

### Reproduire la démo K8s

Prérequis : la stack dev `gravia` démarrée (`docker compose -f infra/docker-compose.yml
--env-file .env up -d` depuis le dépôt `gravia`) — MLflow doit servir le modèle `@staging` et
MinIO doit être accessible, tous deux publiés sur l'hôte.

```bash
# 1. Construire l'image serving (depuis le dépôt gravia)
docker compose -f ../gravia/infra/docker-compose.yml --env-file ../gravia/.env build serving

# 2. Créer le cluster kind (nœud unique, image figée)
kind create cluster --name gravia --config k8s/kind-config.yaml

# 3. Charger l'image serving dans le cluster (pas de registry configuré)
kind load docker-image gravia-serving:python3.12 --name gravia

# 4. Préparer le Secret réel (jamais committé, cf. .gitignore)
cp k8s/serving-secret.example.yaml k8s/serving-secret.yaml

# 5. Déployer
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/serving-configmap.yaml
kubectl apply -f k8s/serving-secret.yaml
kubectl apply -f k8s/serving-deployment.yaml
kubectl apply -f k8s/serving-service.yaml

# 6. Vérifier (les Pods mettent ~30-60s à charger le modèle)
kubectl get pods -n gravia
kubectl port-forward -n gravia service/gravia-serving 8001:8000
curl http://localhost:8001/health

# 7. Nettoyer
kind delete cluster --name gravia
```

**`kubectl port-forward service/...` ne répartit pas la charge entre répliques** : contrairement
à ce que le nom laisse penser, il forwarde vers *un seul* Pod choisi au démarrage du tunnel, pas
à travers le vrai équilibrage du Service — constaté en testant : supprimer ce Pod précis casse
le tunnel (`kubectl port-forward` doit être relancé), alors que le Service lui-même continue de
router vers l'autre réplique sans interruption. Pour tester le vrai équilibrage de charge, il
faudrait un client qui frappe le Service depuis l'intérieur du cluster (un Pod de test), pas
`port-forward` depuis l'hôte.

### Pièges rencontrés en testant (vraie infra, pas supposés)

- **`CrashLoopBackOff` au premier déploiement** : les délais de `readinessProbe`/`livenessProbe`
  copiés du healthcheck docker-compose (15s) étaient trop courts. L'image `serving` lance 4
  workers uvicorn (cf. `gravia/infra/serving/Dockerfile`), chacun rechargeant indépendamment le
  modèle LightGBM + SHAP depuis MLflow/MinIO — nettement plus lent ici, contraint à 1 CPU/1Gi
  (limites initiales) contre un accès libre aux cœurs de la machine hôte pour docker-compose.
  Corrigé en portant les limites à 2 CPU/2Gi et les délais à 30s (readiness)/60s (liveness) —
  cf. `k8s/serving-deployment.yaml`.
- **`403 Invalid Host header` au démarrage** : MLflow rejetait les requêtes du Pod via
  `host.docker.internal` (protection anti-DNS-rebinding, `--allowed-hosts` non configuré pour ce
  nom). Corrigé côté `gravia` (`infra/docker-compose.yml`, PR
  [VigiRoute/gravia#12](https://github.com/VigiRoute/gravia/pull/12)) — un fix dans le dépôt qui
  **construit**, découvert en testant le dépôt qui **déploie**.

### Vérifié sur cluster réel (2026-09-13)

- `kubectl apply` des 5 manifests → 2/2 Pods `Running`, `/health` → `200 OK`.
- Requête réelle `POST /v1/predict-severity` → prédiction + explication SHAP correctes.
- Auto-guérison : `kubectl delete pod` sur une réplique → remplacée automatiquement, le Service
  reste disponible via l'autre réplique pendant ce temps.
- Scaling : `kubectl scale --replicas=3` puis retour à 2 → les deux transitions fonctionnent.

## Terraform — IaC (LocalStack → AWS)

Un module par responsabilité (cf.
[`gravia/docs/Architecture_GRAVIA.md` §6.2](https://github.com/VigiRoute/gravia/blob/main/docs/Architecture_GRAVIA.md)) :

| Module | Ressources | Applicable sur LocalStack Community ? |
|---|---|---|
| `network` | VPC, sous-réseau public + 2 sous-réseaux privés (2 AZ, exigence RDS), Internet Gateway, groupes de sécurité | ✅ oui (`ec2`) |
| `storage` | Bucket S3 (lac de données) + RDS PostgreSQL (Gold/Airflow/MLflow) | ✅ S3 oui — ❌ RDS non (Pro) |
| `compute` | Rôle IAM (nœuds EKS) + dépôts ECR + cluster EKS | ✅ IAM oui — ❌ ECR/EKS non (Pro) |
| `mlops` | Secret Secrets Manager (identifiants PostgreSQL) | ✅ oui (`secretsmanager`) |

### Pourquoi LocalStack (et sa vraie limite, constatée en testant)

Même logique que côté `gravia`
([`Architecture_GRAVIA.md` §2.1](https://github.com/VigiRoute/gravia/blob/main/docs/Architecture_GRAVIA.md)) :
le **même code Terraform** cible LocalStack ou AWS réel, seuls l'endpoint et les identifiants
changent (cf. `providers.tf`, `var.localstack_endpoint`). `terraform apply` contre LocalStack
crée de **vraies ressources** (vérifiées via `awslocal`, pas seulement l'état Terraform) — pas
un plan simulé.

**Mais l'énoncé « même code, aucune ligne spécifique à l'émulateur » a une limite réelle,
découverte en interrogeant directement l'API LocalStack Community (`/_localstack/health` puis
un appel direct à `CreateRepository`/`DescribeDBInstances`) :**

```
{"message": "Sorry, the ecr service is not included within your LocalStack license, ..."}
{"message": "Sorry, the rds service is not included within your LocalStack license, ..."}
```

**ECR et RDS sont réservés à la licence Pro** (payante) — seuls `s3`, `iam`, `ec2`, `kms`,
`sts`, `secretsmanager` sont disponibles gratuitement. Solution : la variable
`var.include_pro_only_services` (défaut `false`) conditionne (`count = ... ? 1 : 0`) les
ressources RDS/ECR/EKS — écrites et valides (`terraform plan -var="include_pro_only_services=true"`
les affiche correctement) pour satisfaire l'exigence CDC d'une architecture AWS **intégralement
documentée**, mais jamais appliquées contre LocalStack Community. À activer uniquement contre
AWS réel (ou une licence LocalStack Pro, non utilisée ici).

**EKS n'est de toute façon jamais appliqué dans ce dépôt**, licence Pro ou non : sa réalité
opérationnelle (Deployment/Service/scaling/auto-guérison) est déjà vérifiée pour de vrai via
`kind` (section ci-dessus) — le bloc `aws_eks_cluster` documente la cible AWS, il ne remplace
pas cette vérification.

### Reproduire

```bash
# 1. Démarrer LocalStack (indépendant de la stack dev gravia)
docker compose -f terraform/docker-compose.localstack.yml up -d

# 2. Préparer les variables réelles (jamais committées, cf. .gitignore)
cd terraform
cp terraform.tfvars.example terraform.tfvars

# 3. Init, plan, apply
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# 4. Vérifier avec le CLI AWS embarqué dans le conteneur LocalStack (pas seulement l'état
#    Terraform) — la région doit être explicite (eu-west-1, sinon le CLI retombe sur us-east-1)
docker exec gravia-mlops-localstack-1 awslocal s3 ls
docker exec gravia-mlops-localstack-1 awslocal ec2 describe-vpcs --region eu-west-1
docker exec gravia-mlops-localstack-1 awslocal secretsmanager get-secret-value \
  --region eu-west-1 --secret-id gravia-dev-db-credentials --query SecretString --output text

# 5. Nettoyer
terraform destroy
docker compose -f terraform/docker-compose.localstack.yml down -v
```

### Vérifié sur LocalStack réel (2026-09-13)

- `terraform apply` : **14 ressources créées** (network + storage/S3 + compute/IAM + mlops),
  0 avec `include_pro_only_services=false` en échec.
- Chaque ressource vérifiée individuellement via `awslocal` (pas seulement l'état Terraform) :
  VPC `gravia-dev-vpc`, 2 sous-réseaux privés dans `eu-west-1a`/`eu-west-1b`, sous-réseau public,
  2 groupes de sécurité, bucket S3 `gravia-dev-lake`, secret Secrets Manager avec la bonne
  valeur, rôle IAM.
- `terraform plan` après apply : **aucune dérive** (idempotence confirmée).
- `terraform plan -var="include_pro_only_services=true"` : les 5 ressources RDS/ECR/EKS
  apparaissent correctement dans le plan (jamais appliquées ici).

## CD (`.github/workflows/deploy.yml`)

Deux jobs indépendants, chacun exécutant réellement l'infra dans le runner GitHub Actions (pas
des manifests jamais testés), déclenchés sur push vers `main` ou manuellement :

- **`terraform-apply`** : LocalStack en service du job, `terraform apply` réel, vérifié via
  `awscli` (pas seulement l'état Terraform).
- **`k8s-deploy`** : cluster `kind` réel, récupère l'image publiée par `gravia`
  (`ghcr.io/vigiroute/gravia-serving`, cf.
  `gravia/.github/workflows/publish-serving-image.yml`), déploie les mêmes manifests que la
  démo locale.

### Accès cross-repo au package GHCR

Les deux dépôts étant **privés**, le package GHCR publié par `gravia` est privé par défaut —
inaccessible depuis les workflows de `gravia-mlops` sans configuration explicite. Pas d'endpoint
API documenté pour ça : réglé manuellement via **Manage Actions access** sur la page du package
(`https://github.com/orgs/VigiRoute/packages/container/gravia-serving/settings` → *Add
Repository* → `gravia-mlops`), pas via `gh api`/Terraform.

### Deux bugs réels trouvés et corrigés en testant

1. **Erreur de syntaxe YAML** : une commande `sed` contenant `image: gravia-serving:python3.12`
   avait ses deux-points non protégés — YAML les interprétait comme un nouveau couple clé/valeur
   (`mapping values are not allowed here`), rejetant le workflow avant même de créer les jobs
   (échec en 0s, aucun job listé). Corrigé en passant ce `run:` en bloc littéral (`|`).
2. **Retries MLflow par défaut** (même piège que `gravia/.github/workflows/ci.yml`) : les Pods
   du cluster `kind` de CI restaient `Running` sans avoir encore loggué de tentative MLflow après
   20 secondes fixes — MLflow retente 7 fois avec backoff exponentiel avant d'abandonner.
   `MLFLOW_HTTP_REQUEST_MAX_RETRIES=1` ajouté au ConfigMap ; l'étape de vérification sonde
   désormais les logs (jusqu'à 2 min) plutôt qu'un délai fixe.

### Limite assumée pour `k8s-deploy` (documentée, pas contournée)

Ce runner n'a pas de vrai MLflow avec le modèle `@staging` entraîné (contrairement à la démo
locale, où la stack dev `gravia` tourne en parallèle du cluster `kind`) — le Pod ne peut donc pas
devenir `Running`. Confirmé en pratique : `NameResolutionError` sur `host.docker.internal`
(contrairement à Docker Desktop en local, ce nom spécial n'est pas résolu par défaut sur un
runner Linux GitHub-hosted). Le job vérifie que le déploiement est correctement câblé jusqu'à ce
point précis (logs montrant la tentative de connexion), pas un bug de packaging K8s.

## Réentraînement planifié (CDC EF-6)

Vit dans **`gravia`**, pas ici (`gravia/.github/workflows/retrain.yml`) : appelle directement
`ml.training.benchmark`, déjà écrit et validé dans ce dépôt — pas de checkout cross-repo
nécessaire, contrairement au déploiement K8s/Terraform. Même limite assumée que `k8s-deploy` :
vérifie réellement la joignabilité de MLflow/PostgreSQL avant de lancer l'entraînement, s'arrête
proprement si l'infra manque plutôt que de planter.
