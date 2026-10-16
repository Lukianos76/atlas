# ADR 0011 — Licence du code

- **Statut** : accepté
- **Date** : 2026-10-17

## Contexte

Le dépôt est public et ne porte encore aucune licence : en l'état, personne n'a le droit de réutiliser, modifier ni redistribuer le code, contributeurs compris.

La politique éditoriale (§4.2) fixe la licence des **données** : ODbL 1.0, avec des conditions de contribution qui autorisent un changement ultérieur vers une autre licence ouverte. Elle renvoie la licence du **code** à un ADR à part.

Éléments à prendre en compte :

- **Projet contributif** (`docs/vision.md`, « L'intelligence collective ») : la licence doit être lisible pour un contributeur occasionnel et ne pas le décourager.
- **Service en ligne** (ADR 0007) : l'atlas est d'abord une application web. Le cas d'un tiers qui reprendrait le code pour opérer un service concurrent, modifié et fermé, est le cas réaliste de réutilisation.
- **Dépendances actuelles**, toutes permissives : `maplibre-gl` 6.14.0 (BSD-3-Clause), `react` et `react-dom` 19.3.1 (MIT), `react-map-gl` 8.1.3 (MIT) (champ `license` de leur `package.json`). Elles sont compatibles avec les trois licences comparées. PostGIS, Tippecanoe et dbmate sont des programmes distincts, lancés à côté du code de l'atlas et non intégrés à lui.
- **Code et données restent séparés.** La FSF juge l'ODbL incompatible avec la GPL et déconseille de l'employer pour du logiciel ([liste des licences](https://www.gnu.org/licenses/license-list.html), entrée ODbL). Le dépôt ne contient que de petits extraits de test (CLAUDE.md, règle 7), qui gardent la licence de leur source.

## Options envisagées

### Effets comparés

| | **A. MIT** | **B. Apache 2.0** | **C. AGPL 3.0 ou ultérieure** |
|---|---|---|---|
| **Nature** | Permissive | Permissive, avec clause de brevets | *Copyleft* fort, étendu à l'usage en réseau |
| **Contributeurs** | Rien n'encadre les contributions entrantes : elles sont sous MIT par usage, pas par le texte | §5 : une contribution soumise est sous Apache 2.0, sauf mention contraire. §3 : licence de brevets de chaque contributeur sur sa contribution, résiliée pour qui intente une action en contrefaçon | Licence de brevets des contributeurs (§11). Leurs contributions ne peuvent pas être refermées par un tiers. Sans accord de contribution, changer de licence demande l'accord de tous, sauf vers une version ultérieure de l'AGPL (§14, « ou toute version ultérieure ») |
| **Réutilisateurs** | Tout est permis, à condition de conserver l'avis de copyright et la licence | Idem, plus : signaler les fichiers modifiés (§4b), reprendre le fichier `NOTICE` s'il existe (§4d) | Toute redistribution, modifiée ou non, se fait sous AGPL avec son code source. Le code peut être combiné avec du code GPL 3.0 (§13, 2ᵉ alinéa) |
| **Service en ligne qui reprendrait le code** | Peut modifier, opérer et garder ses modifications fermées | Idem | S'il modifie le programme, il doit offrir le code source de sa version modifiée à tous les utilisateurs qui interagissent avec lui par le réseau (§13, 1ᵉʳ alinéa) |
| **Code de tiers que l'atlas peut intégrer** | Permissif seulement (MIT, BSD, Apache 2.0…) | Idem. Incompatible avec la GPL 2.0, compatible avec la GPL 3.0 (liste de la FSF) | Permissif, GPL 3.0, AGPL 3.0 |
| **Cohérence avec l'ODbL** | Faible : les données sont en partage à l'identique, le code ne l'est pas | Faible, pour la même raison | Forte (voir ci-dessous) |

### Cohérence avec l'ODbL

L'ODbL est une licence à **partage à l'identique** qui ne s'arrête pas à la distribution de copies :

- une base dérivée **utilisée publiquement** reste sous ODbL (§4.4a), y compris lorsque seule une œuvre produite à partir d'elle est utilisée publiquement (§4.4c) ;
- celui qui utilise publiquement une base dérivée, ou une œuvre produite à partir d'elle, doit offrir une copie de la base dérivée, ou des modifications apportées, sous une forme lisible par machine (§4.6).

L'AGPL applique la même logique au code : un service qui exploite une version modifiée doit en offrir le source à ses utilisateurs (§13). Avec MIT ou Apache 2.0, un tiers pourrait opérer un atlas concurrent dont les **données** resteraient ouvertes (ODbL) mais dont le **code** des traitements et de l'interface serait fermé.

Les deux licences ne se combinent pas pour autant : chacune couvre son domaine. Le partage à l'identique de l'ODbL ne s'étend pas aux œuvres produites, et l'AGPL ne s'étend pas aux données que le code traite.

### Points d'attention

- **AGPL et réutilisation institutionnelle** : certaines organisations interdisent en interne l'usage de code AGPL. Un média ou une collectivité qui intègre une **carte produite** (image, `iframe`) n'est pas concerné. Celui qui **modifie et opère** le code l'est.
- **AGPL et front** : le JavaScript envoyé au navigateur est généralement considéré comme une distribution du programme. L'application doit donc indiquer où trouver son code source. Le dépôt étant public, un lien dans l'interface suffit.
- **Conditions de contribution** : la politique éditoriale (§4.2) prévoit, pour les données, des conditions qui autorisent un changement ultérieur de licence. Pour le code, deux voies :
  - le **DCO** (*Developer Certificate of Origin*, une ligne `Signed-off-by` par commit) : léger, il atteste que le contributeur a le droit de soumettre son code, sans cession. Le seul changement possible est alors vers une version ultérieure de l'AGPL (§14) ;
  - un **accord de contribution** (CLA) qui accorde au projet le droit de changer de licence : il aligne le code sur les données, mais demande plus aux contributeurs et doit être rédigé, idéalement avec l'avis juridique déjà recommandé par la politique éditoriale (§4.2).

## Décision

On retient l'**option C** pour le code, et une licence de contenu pour la documentation.

1. **Code** : AGPL 3.0 ou toute version ultérieure (`AGPL-3.0-or-later`). Elle couvre tout le dépôt hors `docs/` et hors extraits de test : `apps/`, `pipelines/`, `db/`, `scripts/`, `styles/`, `tiles/`, les fichiers de configuration et les fichiers de la racine. Les champs `license` de `apps/web/package.json` et `pipelines/pyproject.toml` la portent. Le fichier `LICENSE` de la racine en reprend le texte, pour les outils qui ne lisent que lui.
2. **Documentation** (`docs/`) : CC BY-SA 4.0 (`CC-BY-SA-4.0`).
3. **Extraits de test** : chacun garde la licence de sa source (CLAUDE.md, règle 7).
4. **Conformité REUSE** (spécification 3.3) :
   - le dossier `LICENSES/` contient le texte de chaque licence employée, nommé par son identifiant SPDX. Les textes ont été obtenus par `reuse download` ;
   - `REUSE.toml` attribue les licences par chemin. Le dossier des extraits de test n'y reçoit volontairement aucune licence : chaque extrait doit y avoir sa propre table, avec la licence de sa source, sinon la vérification échoue ;
   - `check.sh --reuse` lance `reuse lint` (outil `reuse` 6.2.0, épinglé). La CI le lance sur chaque changement, sans filtre de chemins.
5. **Contributions** : sous **DCO**, dès maintenant et pour tous, mainteneur compris. Chaque commit porte la ligne `Signed-off-by` (`git commit -s`). Les commits antérieurs à cette décision ne sont pas réécrits. Des conditions de contribution qui n'autorisent un changement de licence que vers une autre licence libre, alignées sur celles des données (politique éditoriale, §4.2), seront réexaminées avant de fusionner la première contribution extérieure (`docs/backlog.md`).
6. **Lien vers le code source** dans l'interface : inscrit au backlog de la tranche 1.

## Conséquences

- Aucun tiers ne peut opérer une version modifiée et fermée de l'atlas : code et données restent en partage à l'identique.
- Des réutilisateurs qui refusent le *copyleft* se détourneront du code. La réutilisation des cartes produites n'est pas touchée.
- L'atlas peut intégrer du code permissif ou GPL 3.0. Du code de l'atlas ne peut pas entrer dans un projet sous licence permissive ou propriétaire sans l'accord de ses auteurs.
- Avec le DCO seul, un passage ultérieur à une licence autre qu'une version de l'AGPL demanderait l'accord de chaque contributeur. D'où le réexamen avant la première contribution extérieure.
- Tout fichier ajouté au dépôt doit être couvert par `REUSE.toml`, ou porter ses propres informations de licence, sinon la vérification échoue. Un extrait de test demande une table dédiée et, si sa licence est nouvelle, son texte dans `LICENSES/`.
- La protection par le droit d'auteur du code produit avec l'assistance d'une IA, et son effet sur l'application de l'AGPL, est soumise à l'avis juridique recommandé avant la première publication (politique éditoriale, §4.2).

## Sources

- [GNU Affero General Public License, version 3](https://www.gnu.org/licenses/agpl-3.0.html), §11, §13, §14.
- [Apache License, version 2.0](https://www.apache.org/licenses/LICENSE-2.0), §3, §4b, §4d, §5.
- [Licence MIT (Expat)](https://opensource.org/license/mit).
- [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/), §1, §4.4, §4.5, §4.6.
- [FSF, liste des licences et commentaires](https://www.gnu.org/licenses/license-list.html) : entrées Apache 2.0, Expat et ODbL.
- [Developer Certificate of Origin](https://developercertificate.org/).
- [Spécification REUSE, version 3.3](https://reuse.software/spec-3.3/) (2024-11-14) : fichiers couverts, dossier `LICENSES/`, `REUSE.toml` (« seule la dernière table qui couvre un fichier s'applique »).
