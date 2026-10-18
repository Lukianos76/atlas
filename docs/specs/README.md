# Spécifications des fonctionnalités

Une spec par fonctionnalité, rédigée avant toute implémentation (commande `/new-spec` en local, ou `@claude spec` dans une issue : CLAUDE.md, Mode CI). Chaque tâche de `docs/roadmap.md` renvoie à sa spec.

## Statuts

| Statut | Sens |
|---|---|
| **proposé** | Rédigée, en attente de validation par le mainteneur. Aucune implémentation. |
| **validé** | Le mainteneur a approuvé ce contenu. La tâche peut être planifiée. |
| **livré** | Tous les critères d'acceptation sont remplis et la branche est fusionnée. |

Une spec modifiée après validation repasse à « proposé ».

## Index

| Spec | Phase | Statut |
|---|---|---|
| [Migrations du schéma et tests de violation](migrations-schema.md) | 1. Tranche 1 | proposé |

## Gabarit

Fichier `docs/specs/<sujet-en-kebab-case>.md` :

```markdown
# <Fonctionnalité>

- **Statut** : proposé | validé | livré
- **Date** : AAAA-MM-JJ
- **Phase** : <phase de docs/roadmap.md>
- **Documents de référence** : <modèle §…, ADR …, politique §…>

## Objectif

## Contexte

## Critères d'acceptation

- [ ] <vérifiable : test, commande ou contrôle visuel précis>

## Hors périmètre

## Données et sources

<entrées de docs/data-sources.md concernées>

## Décisions à prendre

<options et recommandation ; tranchées par le mainteneur>

## Questions ouvertes
```
