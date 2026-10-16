# Politique éditoriale de l'atlas

> **Statut** : version 1 (octobre 2026).
> **Portée** : règles de neutralité et de fiabilité de l'atlas. Ce document applique `docs/vision.md` et encadre les choix éditoriaux prévus par `docs/modele-donnees.md`. Il ne retient aucune technologie.
> **Force** : une préférence du point de vue par défaut qui ne s'appuie pas sur cette politique peut être contestée pour ce seul motif (`modele-donnees.md`, §10.2).

---

## 1. Objet et principes

L'atlas veut que chaque donnée affichée soit **neutre, vérifiable et sourcée** (`vision.md`). Le modèle de données en donne les moyens :
- **pas de donnée sans source** : toute assertion porte au moins une citation (P3) ;
- **les désaccords sont conservés** : des assertions contradictoires coexistent (P4) ;
- **la neutralité passe par les points de vue** : l'affichage applique un point de vue explicite (P5).

Le modèle ne dit pas **quelles** sources sont recevables, **quel** point de vue s'affiche par défaut, ni **comment** on représente une donnée sensible. C'est l'objet de ce document.

Chaque section commence par un rappel des pratiques de référence. Ce rappel justifie les choix ; il n'est pas normatif.

---

## 2. Territoires disputés

### 2.1 Pratiques de référence

| Référence | Pratique |
|---|---|
| [Wikipédia, neutralité de point de vue](https://fr.wikipedia.org/wiki/Wikip%C3%A9dia:Neutralit%C3%A9_de_point_de_vue) | Présenter tous les points de vue pertinents, chacun attribué à ceux qui le défendent, avec un poids proportionné à sa place dans les sources fiables. |
| [OpenStreetMap, territoires disputés](https://wiki.openstreetmap.org/wiki/Disputed_territories) | Règle *On the Ground* : la frontière principale reflète le contrôle effectif. La règle atteint ses limites dans les conflits actifs : la Crimée est cartographiée à la fois dans l'Ukraine et dans la Russie, et une décision de 2018 appliquant le contrôle de fait a été annulée par la fondation OSM. Aucun schéma de balisage des revendications n'est adopté. |
| [Natural Earth, politique des frontières disputées](https://www.naturalearthdata.com/about/disputed-boundaries-policy/) | Frontières tracées selon le statut *de facto*, marquées « disputées » ; la ligne *de jure* est fournie à part comme « revendication ». Depuis la version 5 (décembre 2021), 31 points de vue par pays. |
| Cartographie onusienne et européenne ([carte ONU n° 4144 Rev. 60](https://digitallibrary.un.org/record/4072804/files/4144_Rev-60.pdf), [GISCO](https://ec.europa.eu/assets/estat/E/E4/gisco/website/basic-services/education/map)) | Frontières selon la position de l'institution, avec une clause de non-responsabilité sur le statut juridique des territoires et le tracé des frontières. |

### 2.2 Définition

Un territoire est **disputé** quand :
- son **contrôle de fait** et sa **souveraineté revendiquée** divergent ; ou
- **deux entités de catégorie politique** (au sens du modèle, §4.2) en revendiquent la souveraineté ;

et que **chaque position est appuyée par une source primaire** : acte, constitution, résolution.

Une revendication sans source primaire ne suffit pas à rendre un territoire disputé.

### 2.3 Rendu par défaut

Le point de vue par défaut de l'atlas **ne retient aucune lecture**. Un territoire disputé s'affiche avec :
- des **hachures** qui portent les deux lectures : contrôle de fait d'une part, souveraineté revendiquée ou reconnue d'autre part ;
- la mention explicite **« disputé »**.

Exemples : la Crimée depuis 2014 (`modele-donnees.md`, §13.3) ; l'Alsace-Moselle de 1940 à 1945 (§12.5).

### 2.4 Points de vue disponibles

La liste des points de vue est **fermée** :

| Point de vue | Disponibilité |
|---|---|
| **Par défaut de l'atlas** | Toujours (§2.3) |
| **Contrôle de fait** | Toujours |
| **Souveraineté de droit** (droit international de l'époque) | Toujours |
| **Position d'une entité politique** | Ajouté **sur demande**, si les positions de cette entité sont sourcées sur ses **actes officiels**. L'entité est de catégorie politique au sens du modèle (§4.2) : un État, mais aussi un gouvernement en exil ou un État à la reconnaissance limitée |

Les règles de sélection de chaque point de vue sont celles du modèle (§10.3).

**Souveraineté de droit.** Ce point de vue couvre toutes les périodes. Il retient, dans l'ordre :
1. la position des **Nations unies**, quand l'Assemblée générale ou le Conseil de sécurité s'est prononcé (à partir du 24 octobre 1945, entrée en vigueur de la Charte) ;
2. sinon, la souveraineté issue du **dernier traité en vigueur entre les parties**, qualifiée par une source secondaire académique (§3.2) ;
3. à défaut : **« non tranché »**.

Il reflète le droit international **de l'époque affichée**, et son libellé le dit. Une colonie y apparaît sous la souveraineté que lui donnaient les traités de son temps. Exemple : en 1942, l'Alsace annexée de fait reste française, aucun traité n'ayant remplacé le traité de Versailles (`modele-donnees.md`, §12.5).

### 2.5 Mentions obligatoires

1. **Point de vue actif.** Le nom du point de vue appliqué est visible en permanence sur la carte.
2. **Infobulle.** Au survol ou au clic d'un territoire disputé : les deux lectures, leurs sources et un lien vers les autres points de vue.
3. **Clause de non-responsabilité**, affichée avec la carte :

   > Les limites, noms et désignations figurant sur cette carte n'impliquent de la part de l'atlas aucune prise de position sur le statut juridique d'un pays, d'un territoire ou d'une zone, ni sur le tracé de ses frontières. Ils correspondent au point de vue indiqué en légende ; d'autres points de vue sont disponibles.

4. **Exports.** Toute image ou donnée exportée porte le point de vue, la date et, le cas échéant, la mention « disputé ».

### 2.6 Hors du périmètre de cette section

- **Q14** (souveraineté portée par les circonscriptions) reste ouverte : elle relève du modèle.
- **Q7** (nom par défaut) et **Q8** (typage disputé des événements) restent ouvertes.

---

## 3. Sources

### 3.1 Pratiques de référence

| Référence | Pratique |
|---|---|
| [Wikipédia, vérifiabilité](https://fr.wikipedia.org/wiki/Wikip%C3%A9dia:V%C3%A9rifiabilit%C3%A9) | Les articles se fondent principalement sur des sources secondaires fiables ; les sources primaires peuvent convenir mais leur usage est délicat. Les sources autopubliées, wikis compris, ne sont généralement pas acceptables. |

L'atlas cite chaque assertion (P3) et s'appuie largement sur des sources primaires (actes, recensements). Il lui faut donc ses propres règles de recevabilité.

### 3.2 Hiérarchie selon la nature de l'assertion

| Nature de l'assertion | Source qui prime |
|---|---|
| Données statistiques, actes, noms et statuts officiels | **Source primaire officielle** : publication de l'institut statistique, texte de l'acte |
| Qualifications historiques et reconstitutions : géométries anciennes, qualification d'un événement, création ou suppression d'une entité | **Source secondaire académique** |

Les autres sources restent recevables. La hiérarchie sert à choisir entre assertions concurrentes (§6.3).

### 3.3 Sources exclues

Les **bases collaboratives** (Wikipédia, Wikidata, OpenStreetMap et leurs semblables) ne sont **jamais une source**. Elles servent à trouver la source d'origine, que l'on cite.

**Exception** : un identifiant Wikidata ou OSM est une assertion d'identifiant (`modele-donnees.md`, §5.3), dont le référentiel tient lieu de source.

### 3.4 Sources émanant d'une partie à un différend

Une source émanant d'une partie (gouvernement, parti, mouvement) est recevable **pour établir la position de son auteur** : c'est une assertion qui porte une autorité (§5.6 du modèle), lue « selon X ».

Elle n'est **jamais** recevable pour établir un fait contesté. **Un fait disputé exige une source indépendante.**

### 3.5 Accessibilité et pérennité

| Règle | Contenu |
|---|---|
| **Copie archivée** | Exigée pour **valider** une assertion qui cite une source en ligne, pas pour la proposer. Si l'archivage est impossible (site qui l'interdit), l'exception est justifiée, et la citation porte la date de consultation et un extrait. |
| **Sources hors ligne** | Admises : archive non numérisée, ouvrage imprimé. La citation porte une cote ou un ISBN, un localisateur précis et un **extrait obligatoire**. |
| **Identifiant pérenne** | DOI, ARK, ISBN ou cote, **obligatoire quand il existe**. Une URL seule ne suffit pas dans ce cas. |
| **Millésime** | Obligatoire pour tout jeu de données révisé (COG, NUTS, ADMIN EXPRESS…). |

---

## 4. Licences

### 4.1 Pratiques de référence

| Référence | Pratique |
|---|---|
| [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/) | Licence de base de données avec partage à l'identique. Le partage à l'identique s'applique aux **bases dérivées**, pas aux **œuvres produites** (images, textes) : celles-ci demandent seulement une mention de la base et de sa licence. |
| [Conditions de contribution de la fondation OSM](https://osmfoundation.org/wiki/Licence/Contributor_Terms) | Les contributeurs autorisent un changement ultérieur vers une autre licence libre et ouverte, décidé par un vote des membres et approuvé par les deux tiers des contributeurs actifs. |
| [Licence Ouverte 2.0](https://static.data.gouv.fr/resources/licence-ouverte-2-0/20260909-072646/etalab-licence-ouverte-v2.0.pdf) | Licence de la plupart des données publiques françaises. Conçue pour être compatible avec toute licence libre qui exige au moins la mention de paternité, notamment CC BY, ODC-BY et l'OGL britannique. |
| [Licences de réutilisation des données publiques](https://www.data.gouv.fr/pages/legal/licences/) | Pour les informations publiques, la liste fixée par décret comprend la Licence Ouverte 2.0 et l'ODbL 1.0. |
| [Directive 96/9/CE](https://eur-lex.europa.eu/legal-content/FR/TXT/?uri=CELEX:31996L0009), art. 7 | Le producteur d'une base peut interdire l'extraction d'une partie substantielle de son contenu, ainsi que l'extraction répétée et systématique de parties non substantielles. |

### 4.2 Licence de l'atlas

Les **données de l'atlas** sont publiées sous **ODbL 1.0**.
- Les **œuvres produites** (images de cartes, graphiques) sont réutilisables avec mention de l'atlas et de sa licence.
- Les contributions sont soumises à des **conditions de contribution** qui autorisent un changement ultérieur vers une autre licence ouverte.
- La licence du **code** relève d'un ADR à part.

Un **avis juridique** est recommandé avant la première publication.

### 4.3 Licences acceptées

Sont acceptées d'office les sources sous :
- Licence Ouverte 1.0 et 2.0 ;
- CC0, PDDL ;
- CC BY 4.0, ODC-BY ;
- ODbL ;
- domaine public : actes officiels, sources anciennes (traités, recensements anciens).

**Toute autre licence** est examinée par un humain au **premier usage de l'œuvre source**, et non à chaque lot. La page de licence est **archivée** à ce moment-là, et la licence est consignée dans l'attribut `licence` de l'œuvre (§9.1 du modèle).

### 4.4 Sources sous licence non commerciale ou sans modification

Une source sous licence NC ou ND est **citable** : pour corroborer une assertion, ou pour un fait ponctuel. Son contenu n'est en revanche :
- **jamais importé** par lot ;
- **jamais extrait en masse** ;
- **jamais redistribué**.

Conséquence : la version 6 du projet COMMUNES (CC BY-NC 4.0) ne peut pas être importée. La version 2 (CC BY 4.0) reste à évaluer (`docs/backlog.md`).

### 4.5 Propagation dans les dérivations

- Une observation dérivée (§8.4 du modèle) porte la **licence la plus contraignante** de ses entrées.
- Une dérivée dont les entrées ont des licences **incompatibles** n'est **pas publiée**.

---

## 5. Représentations sensibles

### 5.1 Pratiques de référence

| Référence | Pratique |
|---|---|
| [Insee, *Guide de sémiologie cartographique* (2018)](https://www.insee.fr/fr/statistiques/3640429) | Volumes en ronds proportionnels ; ratios, densités, évolutions et parts en aplats de couleur, « des indications qui doivent guider le choix plutôt que des règles absolues ». 3 à 5 classes selon le nombre d'observations. Méthodes : quantiles, amplitudes égales, Jenks, k-means, bornes manuelles ; une bonne discrétisation part de classes homogènes puis ajuste les bornes à la main. Deux cartes comparées partagent une légende unique. Les couleurs ont des connotations (le vert est positif). |
| [ColorBrewer](https://colorbrewer2.org/) ([types de palettes](https://colorbrewer2.org/learnmore/schemes_full.html)) | Palettes séquentielles pour les données ordonnées, divergentes quand une valeur centrale a un sens (moyenne, médiane, zéro), qualitatives pour les catégories. Filtre des palettes sûres pour les daltoniens. |

### 5.2 Couleurs électorales

Les partis prennent leurs **couleurs conventionnelles**. Elles sont consignées dans une **table par parti et par époque**, et chaque couleur est **sourcée** : charte du parti, ou usage médiatique de référence.

Des couleurs trop proches pour être distinguées sont ajustées, et l'ajustement est signalé.

### 5.3 Carte électorale par défaut

La carte par défaut d'un scrutin montre le **candidat ou la liste arrivé en tête**. La **carte du score de chaque candidat** (choroplèthe séquentielle) est accessible en un clic depuis la légende.

### 5.4 Discrétisation

- Chaque variable a des **seuils fixes**, arrondis, choisis et **justifiés dans la fiche de la variable** (§8.1 du modèle).
- Ces seuils sont **communs à toutes les dates** : les cartes de deux années se comparent.
- L'utilisateur peut basculer vers une discrétisation par quantiles ou par Jenks.

### 5.5 Règles générales

1. **Une choroplèthe ne représente que des taux.** Un effectif (population, voix) se représente par des symboles proportionnels ou une densité.
2. **La légende est complète** : méthode de discrétisation, seuils, unité, source, point de vue, et la mention « dérivée » pour une observation dérivée.
3. **Une échelle non linéaire** (logarithmique, racine) est signalée dans la légende.

### 5.6 Accessibilité des couleurs

- Les **palettes séquentielles et divergentes** sont **sûres pour les daltoniens par défaut**, et contrastées sur le fond sombre.
- Une palette **divergente** n'est employée qu'autour d'un **centre qui a un sens** (moyenne, 50 %), nommé dans la légende.
- Les **couleurs de partis** (§5.2) ne peuvent pas toutes être sûres. Un **mode daltonien** les remplace par une palette distinguable, avec motifs et étiquettes.
- **L'information n'est jamais portée par la couleur seule** : l'infobulle la donne en texte.

---

## 6. Données incertaines ou contradictoires

### 6.1 Pratiques de référence

| Référence | Pratique |
|---|---|
| [Wikipédia, neutralité de point de vue](https://fr.wikipedia.org/wiki/Wikip%C3%A9dia:Neutralit%C3%A9_de_point_de_vue) | Les positions sont attribuées, sans être tranchées. |
| [Wikidata, rangs](https://www.wikidata.org/wiki/Help:Ranking) | Plusieurs valeurs coexistent avec un rang : *privilégié* (consensus ou valeur la plus actuelle), *normal* (neutre), *obsolète* (erroné, mais toujours vérifiable). C'est la pratique la plus proche des préférences du modèle (§10.2). |
| [Insee, *Guide de sémiologie cartographique*](https://www.insee.fr/fr/statistiques/3640429) | Code couleur conventionnel : le blanc pour l'absence de données, le gris pour les données non disponibles ou soumises au secret statistique. |

### 6.2 Niveaux de certitude

Le modèle donne à toute assertion une `certitude` sur quatre niveaux (§5.1). Leurs critères :

| Niveau | Critère | Exemple |
|---|---|---|
| **Établi** | L'assertion est attestée directement, soit par une source qui fait foi pour ce type d'assertion (§3.2), soit par une source de synthèse qui constate un consensus. Aucune source recevable ne la contredit. | La date du traité de Francfort ; la population légale INSEE d'une commune |
| **Probable** | Une source recevable l'appuie, mais par une interprétation (qualification, lecture d'un acte) ou par une source secondaire unique, sans synthèse. Aucune source recevable ne la contredit. | La qualification du Bezirk Unterelsass comme division nouvelle (`modele-donnees.md`, §12.2), tant que l'acte allemand n'a pas été lu |
| **Possible** | Les sources sont partielles ou indirectes, ou l'assertion se déduit de sources qui ne l'énoncent pas, ou elle est contredite sans qu'une préférence soit fondée. | Le contour d'une commune absorbée, reconstitué à partir des sections cadastrales actuelles |
| **Conjectural** | Une hypothèse d'auteur ou une reconstitution, présentée comme telle par sa source, sans attestation directe. | L'extension maximale de la zone floue d'un royaume médiéval |

Règles :
- la certitude qualifie l'**assertion**, pas la source ;
- elle se distingue de la `precision` (la marge) et du caractère flou d'une date ;
- le contributeur la **propose**, le relecteur la **valide** ;
- la certitude d'une **observation dérivée** ne dépasse pas celle de la **moins certaine de ses entrées**.

### 6.3 Critères de choix d'une préférence par défaut

Quand des assertions sont concurrentes, la préférence du point de vue par défaut (§10.2 du modèle) se fixe ainsi :
1. **hiérarchie des sources** selon la nature de l'assertion (§3.2) ;
2. à égalité, la source **la plus récente qui discute les précédentes** ;
3. puis la source dont la **méthode est la mieux documentée** ;
4. si rien ne départage : **« non tranché »**.

La justification de la préférence nomme le critère appliqué.

### 6.4 Procédure de décision

- Tant que le projet n'a pas de communauté, **le mainteneur valide chaque préférence par défaut**, sur une proposition motivée.
- Une **procédure communautaire** sera fixée plus tard, par une révision de cette politique.
- Toute préférence peut être **contestée à tout moment**, avec une source. La contestation suit le cycle de vie du modèle (§10.1).

### 6.5 Affichage de l'incertitude

- Les données **moins certaines** sont **atténuées** (opacité réduite).
- Les **zones floues** (§6.1 du modèle) ont un **contour estompé**.
- Le niveau de certitude, la marge et les sources sont donnés **au clic**.
- Ce signal reste **distinct des hachures « disputé »** (§2.3).

### 6.6 Affichage du « non tranché »

L'atlas n'affiche jamais une valeur qu'aucune source n'affirme : ni moyenne ni médiane des valeurs concurrentes.

| Représentation | Affichage |
|---|---|
| **Aplat** | Si toutes les valeurs concurrentes tombent dans la **même classe**, la zone prend la couleur de cette classe, avec le marqueur **« sources divergentes »**. Sinon, elle reçoit un **motif neutre « divergent »**, distinct des hachures « disputé » (§2.3) et de l'atténuation de l'incertitude (§6.5). |
| **Cercle proportionnel** | Un **cercle plein** pour la plus petite valeur, un **contour** pour la plus grande, avec le marqueur « sources divergentes ». |
| **Géométrie** | Les tracés concurrents sont **superposés en contours**. |

Dans tous les cas, la fiche liste chaque valeur et sa source.

---

## 7. Révision de la politique

Cette politique est révisée par le **mainteneur**. Chaque révision change le numéro de version de l'en-tête. La procédure communautaire de décision (§6.4) y sera inscrite par une révision.

---

## 8. Correspondance avec les questions du modèle

| Question (`modele-donnees.md`, §14.2) | État | Où |
|---|---|---|
| **Q2.** Gouvernance des points de vue | **Tranchée pour l'essentiel** : liste fermée (par défaut, contrôle de fait, souveraineté de droit), point de vue d'une entité politique ajouté sur demande s'il est sourcé sur ses actes officiels | §2.4 |
| **Q3.** Point de vue par défaut des territoires disputés | **Tranchée** : rendu « disputé », aucune lecture retenue | §2.2, §2.3 |
| **Q9.** Licences incompatibles | **Tranchée** : licence la plus contraignante des entrées ; pas de publication si les entrées sont incompatibles | §4.5 |
| **Q11.** Dérivations en cascade | **Tranchée en partie** : la certitude d'une dérivée ne dépasse pas celle de ses entrées. La profondeur des cascades reste ouverte | §6.2 |
| **Q7.** Nom par défaut | Ouverte | — |
| **Q8.** Typage disputé des événements | Ouverte | — |
| **Q14.** Souveraineté portée par les circonscriptions | Ouverte | — |

Le modèle annonçait aussi des critères écrits pour les niveaux de certitude (§14.1) : ils figurent au §6.2.
