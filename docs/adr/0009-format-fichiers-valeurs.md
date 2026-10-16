# ADR 0009 — Format des fichiers de valeurs

- **Statut** : accepté, révisé le 2026-10-17 (procédés de représentation dans le manifeste, `docs/schema.md` §8.2)
- **Date** : 2026-10-16

## Contexte

Les tuiles ne portent que les géométries, l'identifiant d'entité et les bornes de validité. Les valeurs statistiques sont chargées à part et jointes dans le navigateur par identifiant d'entité (ADR 0004). Elles sont publiées avec l'archive, de façon versionnée et immuable, sous un même identifiant de publication.

Le format doit :

- tenir à l'échelle mondiale (des millions d'entités × millésimes × variables) ;
- permettre de ne lire qu'une partie d'un fichier (une variable, une plage d'entités ou de dates) ;
- garder pour chaque valeur sa source, sa nature (originale ou dérivée, §8.3 et §8.4 du modèle) et sa marge, pour que l'interface dise toujours d'où vient ce qu'on regarde ;
- être produit facilement par les pipelines Python (ADR 0006).

Vérification faite avec Context7 (octobre 2026) : **hyparquet** lit le Parquet en JavaScript pur dans le navigateur. Il fait des requêtes HTTP partielles (`asyncBufferFromUrl`) et ne lit que les colonnes et les lignes demandées. Il gère nativement les fichiers non compressés et snappy, et les autres codecs via `hyparquet-compressors`.

## Options envisagées

| Option | Points forts | Limites |
|---|---|---|
| **A. Parquet + manifeste JSON par publication** | Compact et compressé. Lecture partielle par colonnes et blocs de lignes, via des requêtes HTTP partielles. Écrit nativement par Polars et DuckDB | Décodage en JavaScript plus lent qu'Arrow. Codecs autres que snappy via une dépendance supplémentaire |
| B. Apache Arrow IPC | Décodage quasi immédiat en tableaux typés, très adapté à deck.gl | Fichiers plus gros. Pas de lecture partielle simple |
| C. JSON ou CSV compressé | Lisible, simple | Lourd et lent à analyser à l'échelle mondiale |
| D. Binaire maison (tableaux typés) | Le plus rapide | Format à maintenir et à documenter, peu ouvert aux contributeurs |

## Décision

On retient **Parquet, avec un manifeste JSON par publication**.

Organisation d'une publication :

- **`publication.json`** (manifeste) : identifiant de publication, point de vue, date d'enregistrement R, période couverte, liste des fichiers (archive PMTiles comprise) avec leur empreinte SHA-256, licences, et **procédés de représentation** appliqués à l'export : méthode et paramètres du point de la couche de points (ADR 0004, décision 6), règle de choix de la valeur affichée par défaut quand aucune préférence n'est stockée (en tranche 1, la valeur INSEE, Q13 du modèle) ;
- **un fichier Parquet de valeurs par variable**, trié par identifiant d'entité puis par date. Colonnes : identifiant d'entité, période de référence, membres des dimensions, valeur, marge, nature (originale ou dérivée), référence de citation ;
- **un fichier Parquet des citations** : œuvre et localisateur, désignés par la référence de citation.

## Conséquences

- le navigateur ne télécharge que les variables et les plages utiles, ce qui garde le chargement léger à l'échelle mondiale ;
- à l'échelle mondiale, les entités devront être **triées selon un ordre spatial** (courbe de Hilbert ou équivalent) plutôt que par identifiant, pour qu'une lecture partielle reste efficace sur la zone affichée : les entités voisines tombent alors dans les mêmes blocs de lignes. Rien n'est à implémenter pour la tranche 1 ;
- les empreintes du manifeste permettent de vérifier qu'une publication citée n'a pas changé (§10.4) ;
- les pipelines produisent les fichiers avec Polars ou DuckDB, sans outillage supplémentaire ;
- le schéma exact des colonnes (types, encodage des périodes et des membres, taille des blocs de lignes) reste à fixer avec la première publication de la tranche 1 ;
- si deck.gl a besoin de tableaux typés pour de gros volumes, une conversion côté client ou un format complémentaire pourra être réexaminé.
