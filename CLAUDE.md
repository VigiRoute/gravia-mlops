# CLAUDE.md — gravia-mlops

## Contexte

`gravia-mlops` est le second des deux dépôts exigés par la certification (RNCP Architecte en
Intelligence Artificielle, projet GRAVIA) : **[gravia](https://github.com/VigiRoute/gravia)
construit** la solution (pipelines de données, modèle, API), **`gravia-mlops` la déploie**
(IaC Terraform, manifests Kubernetes, workflows de déploiement). Voir
[gravia/CLAUDE.md](https://github.com/VigiRoute/gravia/blob/main/CLAUDE.md) pour le contexte
complet du projet.

## Structure

```
gravia-mlops/
├── k8s/                     # manifests Kubernetes (déploiement du serving GRAVIA)
├── terraform/                # IaC prod (LocalStack → AWS) — pas encore commencé
└── .github/workflows/        # CD — pas encore commencé
```

## Workflow Git

Mêmes règles que `gravia` :

⚠️ **Ne jamais merger une branche depuis le terminal.** L'utilisateur merge lui-même depuis
l'interface GitHub. Créer la PR (`gh pr create`) reste possible sur demande.

✅ **Toute nouvelle branche créée doit être immédiatement poussée sur `origin`.**

## Pourquoi `kind` (Kubernetes in Docker)

**Le problème à résoudre** : le CDC exige des manifests Kubernetes pour la cible de production
(EKS, cf. `Architecture_GRAVIA.md` côté `gravia` : scaling et haute disponibilité du serving).
Sans budget cloud, impossible de déployer sur un vrai EKS. Pour Terraform, la solution retenue
côté `gravia` a été **LocalStack** (émulation locale et gratuite de l'API AWS) — mais LocalStack,
même dans une édition payante Pro, n'émule pas EKS de la même façon qu'un vrai cluster K8s
exécutable : ce n'est pas l'outil pertinent ici.

**La solution retenue : `kind`** (kubernetes-sigs/kind, v0.33.0, image de nœud figée par digest
— cf. `k8s/kind-config.yaml`). `kind` crée un **vrai cluster Kubernetes** en utilisant des
conteneurs Docker comme "nœuds" — gratuit, léger, standard pour ce type de démonstration/CI.

**Ce que ça démontre** (même logique que LocalStack pour Terraform, cf.
`Architecture_GRAVIA.md` §2.1 côté `gravia`) : les manifests K8s (`Deployment`, `Service`,
`ConfigMap`, `Secret`) sont **réellement exécutables** — Pods qui démarrent, health checks qui
passent, scaling et auto-guérison qui fonctionnent pour de vrai, pas des fichiers YAML jamais
testés. **Ce que ça ne démontre pas** : la haute disponibilité multi-nœuds/multi-AZ d'un vrai
EKS (un seul nœud ici) ni une charge de production réelle. C'est le rôle de la cible AWS/EKS,
documentée mais non déployée.

**Alternative écartée : `minikube`** — équivalent fonctionnel à `kind`, mais `kind` a été
préféré car plus léger (pas de VM, uniquement des conteneurs) et plus proche de l'esprit
"éphémère, reproductible" déjà adopté pour LocalStack côté `gravia`.

## Reproduire la démo K8s

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

## Pièges rencontrés en testant (vraie infra, pas supposés)

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

## Vérifié sur cluster réel (2026-09-13)

- `kubectl apply` des 5 manifests → 2/2 Pods `Running`, `/health` → `200 OK`.
- Requête réelle `POST /v1/predict-severity` → prédiction + explication SHAP correctes.
- Auto-guérison : `kubectl delete pod` sur une réplique → remplacée automatiquement, le Service
  reste disponible via l'autre réplique pendant ce temps.
- Scaling : `kubectl scale --replicas=3` puis retour à 2 → les deux transitions fonctionnent.

## Pas encore commencé

- **Terraform** (`terraform/`) — IaC pour storage/network/compute/mlops contre LocalStack.
- **CI/CD** (`.github/workflows/`) — déploiement automatisé, réentraînement planifié.
