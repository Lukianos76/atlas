# ADR 0007 — Hébergement

- **Statut** : accepté
- **Date** : 2026-10-16

## Contexte

Quatre ensembles sont à héberger :

1. **Contenu public statique** : l'application web, les archives PMTiles des états matérialisés publiés et le fond de carte Protomaps (ADR 0004). À l'échelle mondiale, ces archives se comptent en dizaines voire centaines de gigaoctets. Elles sont servies par requêtes HTTP partielles : le **coût de sortie réseau (egress)** devient le premier poste de dépense.
2. **Base de référence PostGIS** (ADR 0003) : volumineuse à terme, à sauvegarder, non exposée au public en tranche 1.
3. **Services dynamiques ultérieurs** : Martin pour la prévisualisation des contributions, une API de contribution.
4. **Exécution des pipelines** (ADR 0006) : traitements par lots, parfois lourds (imports mondiaux, Tippecanoe).

La performance à l'échelle mondiale est un critère de premier rang. Le projet est contributif et doit rester sobre en coûts. La **souveraineté européenne** de l'hébergement est un critère à peser au choix des fournisseurs, sans être une exigence.

Vérification faite avec Context7 (octobre 2026) : la documentation PMTiles décrit l'envoi d'archives vers Cloudflare R2, Amazon S3 et Google Cloud Storage, avec la configuration CORS nécessaire.

## Options envisagées

| Option | Points forts | Limites |
|---|---|---|
| A. Tout statique et serverless (front et PMTiles sur stockage objet + CDN) ; base en local pour les pipelines | Coût minimal. Certains stockages objet ne facturent pas l'egress. Rien à exploiter en production | Ne couvre pas la phase contributive (base en ligne, Martin, API) |
| B. Serveur dédié ou VPS en Docker Compose (PostGIS, Martin, front), avec un CDN devant | Coût prévisible, contrôle total, gros disques et beaucoup de RAM pour PostGIS et Tippecanoe. Hébergement européen possible | Exploitation à la charge du projet. Servir soi-même des archives de plusieurs centaines de Go coûte en bande passante |
| C. PaaS managés (PostgreSQL managé avec PostGIS, hébergeur de front, stockage objet) | Démarrage simple, peu d'exploitation | Coûts qui montent vite avec le volume. Dépendance variable selon les fournisseurs |
| D. Hyperscaler (AWS, GCP, Azure) | Passage à l'échelle illimité, services managés complets | Egress coûteux pour les tuiles. Complexité et coût disproportionnés pour le projet |
| **E. Hybride A + B, par étapes** | Le contenu public lourd coûte presque rien à diffuser. La base a les ressources qu'il lui faut. Correspond à l'ADR 0004 | Deux environnements à gérer à partir de la phase contributive |

## Décision

On retient un **hébergement hybride, introduit par étapes** :

- **Tranche 1** : l'application web et les archives PMTiles sont publiées sur un **stockage objet sans frais d'egress, derrière un CDN**. PostGIS tourne en local, pour les pipelines.
- **Phase contributive** : un **serveur dédié** accueille PostGIS, Martin et l'API de contribution. Les pipelines lourds s'exécutent sur ce serveur ou sur une machine louée à la demande.

Les fournisseurs précis sont choisis au moment du déploiement, sur des tarifs vérifiés à cette date. La souveraineté européenne fait partie des critères pesés.

## Conséquences

- En tranche 1, il n'y a aucun service à exploiter en production : seulement des fichiers statiques à publier.
- Le coût de diffusion des tuiles reste faible même à l'échelle mondiale, à condition de retenir un stockage objet sans frais d'egress.
- La publication d'un état matérialisé consiste à générer son archive et à la téléverser : cette étape est à automatiser dans les pipelines.
- Le passage à la phase contributive demandera de mettre en place l'exploitation du serveur dédié : sauvegardes de PostGIS, mises à jour, supervision.
- Le choix des fournisseurs reste ouvert. Il sera consigné, avec la pesée de la souveraineté européenne, au moment du déploiement.
