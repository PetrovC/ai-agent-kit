# Dogfood Audit — `ai-agent-kit`

**Date** : 2026-05-25
**Périmètre** : audit read-only complet du repo, historique entier, 8 sections.
**Méthodologie** : 3 agents `codebase-investigator` en parallèle + vérifications directes.
**Version analysée** : `VERSION` = 1.19.38, branche `master`, dernier commit `a150925`.

---

## Synthèse exécutive

| Sévérité | Nombre | Action recommandée |
|---|---|---|
| **P0** — installation cassée / régression utilisateur | **2** | Corriger en priorité |
| **P1** — dérive future garantie | **5** | Couvrir par tests CI |
| **P2** — gap structurel | **4** | Documenter ou normaliser |
| **P3** — nettoyage | **3** | Optionnel |

**Conclusion read-only (snapshot du 2026-05-25, avant corrections)** : le kit est globalement sain. La PR #213 a fermé la classe principale de bug "dérive Claude/Codex". Restent deux trous concrets — **les permissions de hooks dogfood ne sont pas exécutables** (P0) et **le CHANGELOG n'a pas été mis à jour pour les 6 dernières PRs** (P0) — plus un trou structurel : **Gemini n'a aucun check de dérive** (P1).

> **Note post-corrections** : tous les findings ci-dessus ont été résolus par les PRs [#214](https://github.com/PetrovC/ai-agent-kit/pull/214)–[#223](https://github.com/PetrovC/ai-agent-kit/pull/223) (release v1.20.1). Voir le tableau "Statut de correction" ci-dessous pour l'état actuel.

---

## Statut de correction

Tableau vivant : mis à jour à chaque PR qui résout un finding. Le rapport ci-dessous reste un snapshot daté ; le statut reflète l'état post-corrections.

| Finding | Description | PR | Statut |
|---|---|---|---|
| **P0-A** | Permissions hooks dogfood non exécutables | **[#216](https://github.com/PetrovC/ai-agent-kit/pull/216)** | **✅ résolu — `chmod +x` + validate mode check** |
| **P0-B** | CHANGELOG en retard de 17 PRs + pas de `[Unreleased]` | **[#214](https://github.com/PetrovC/ai-agent-kit/pull/214)** | **✅ résolu — v1.20.0** |
| **P1-A** | Gemini sans check de dérive validate | **[#217](https://github.com/PetrovC/ai-agent-kit/pull/217)** | **✅ résolu — cases ajoutés + gate étendue** |
| ~~P1-B~~ | ~~`tooling/gemini/gemini-extension.json` orphelin~~ | **PR-D (en cours)** | **❌ faux positif — documenté à [`README.md:201`](../../README.md), validé par CI (`pr-versioning.yml` / `lint-plugin-manifest`)** |
| ~~P1-C~~ | ~~`tooling/codex/global-config-template.toml` orphelin~~ | **PR-D (en cours)** | **❌ faux positif — documenté à [`README.md:200`](../../README.md) (template `~/.codex/config.toml`, par-user, pas par-projet)** |
| **P1-D** | **Asymétrie `*.windows.json` ↔ `*.json` non vérifiée** | **PR-I (en cours)** | **✅ résolu — `lint-platform-variant-parity` dans `pr-tooling.yml` (Claude settings: 30 clés alignées, Codex hooks: 17 clés alignées)** |
| **P1-E** | `validate.sh` ne compare pas les modes | **[#216](https://github.com/PetrovC/ai-agent-kit/pull/216)** | **✅ résolu — git ls-files mode parity** |
| P2-A | Pas de `## [Unreleased]` dans CHANGELOG | inclus dans [#214](https://github.com/PetrovC/ai-agent-kit/pull/214) | ✅ résolu |
| P2-B/C/D | Gaps structurels divers | PR-G + tests CI | 🔲 ouvert |
| P3-A/B/C | Cleanup | PR-H | 🔲 ouvert |
| **Post-release** | `.kit-version` 1.19.38 vs `VERSION` 1.20.1 (post-#223 dogfood drift) | **PR cleanup (en cours)** | **✅ résolu — `.kit-version` rafraîchi + check CI ajouté dans `lint-plugin-manifest`** |
| **Post-release** | Loops bash `while read` sans guard `\|\| [[ -n "$p" ]]` ignorent dernière ligne sans newline final | **PR cleanup (en cours)** | **✅ résolu — 6 loops protégés** |
| **Post-release** | Docs stale post-corrections (BACKLOG, DOGFOOD_AUDIT prose, validate.ps1 header, COMMANDS.md) | **PR cleanup (en cours)** | **✅ résolu** |

### Tests anti-dérive (Phase 2)

Plan original = 8 tests CI permanents pour fermer structurellement les classes de bug trouvées. Tracking ci-dessous.

| Test | Couvre | PR | Statut |
|---|---|---|---|
| T1 | Manifest exhaustivity (orphelins + manifest périmé) | [#220](https://github.com/PetrovC/ai-agent-kit/pull/220) | ✅ résolu — reverse check dans `dogfood-install-policy` |
| T2 | Source ↔ dogfood byte-equal Gemini | [#217](https://github.com/PetrovC/ai-agent-kit/pull/217) | ✅ résolu |
| T3 | Install → update dry-run = up-to-date | [#221](https://github.com/PetrovC/ai-agent-kit/pull/221) | ✅ résolu — bash via `e2e-lifecycle` (déjà en place), Windows via assertion ajoutée à `smoke-install-windows` |
| T4 | Cross-OS parity (bash vs ps1 produisent même set) | [#221](https://github.com/PetrovC/ai-agent-kit/pull/221) | ✅ résolu — nouveau workflow `pr-install-parity.yml` |
| T5 | PR-classifier — refuse dogfood-only modifications | déprio. — fermé via #213/#216/#217/#219 | 🔁 redondant |
| T6 | CHANGELOG entry required for feat/fix/perf | [#219](https://github.com/PetrovC/ai-agent-kit/pull/219) | ✅ résolu |
| T7 | Version sync (couvert par `pr-versioning.yml`) | déjà en place | ✅ existant |
| T8 | Doc-reference validity (liens markdown intra-repo) | [#220](https://github.com/PetrovC/ai-agent-kit/pull/220) | ✅ résolu — `lint-doc-links` dans `pr-docs.yml` |

---

## Section A — Cartographie des surfaces

| Path | Kind | Installé ? | Manifest ? | Validate ? |
|---|---|---|---|---|
| `tooling/claude/` | source-canonical | Y (→ `.claude/`, `CLAUDE.md`, `.mcp.example.jsonc`) | N (source) | Y |
| `tooling/codex/` | source-canonical | Y (→ `.codex/`, `AGENTS.md`) | N (source) | Y |
| `tooling/gemini/` | source-canonical | Y (→ `GEMINI.md`, `.geminiignore`, `.gemini/`) | N (source) | **N** ❌ |
| `skills/` | source-canonical | Y (→ `.claude/skills/`, `.agents/skills/`, `.gemini/skills/`) | N (source) | Y |
| `project-template/` | template | Y (→ `docs/ai/`) | N (project-owned) | Y (placeholders) |
| `prompts/` | distribution-alt | **N — pas auto-installé** | N | N |
| `.claude-plugin/` | distribution-alt | **N — voie marketplace séparée** | N | N |
| `.claude/`, `.codex/`, `.agents/` | dogfood-output | Y | Y (tous) | Y (sauf Gemini) |
| `CLAUDE.md`, `AGENTS.md` | dogfood-output | Y | Y | Y |
| `.mcp.example.jsonc` | dogfood-output | Y | Y | Y |
| `.mcp.json` | config | Bootstrappé une fois | N (intentionnel) | N (intentionnel) |
| `GEMINI.md`, `.geminiignore`, `.gemini/` | dogfood-output | Y | Y | **N** ❌ |
| `.kit-manifest`, `.kit-version` | config | Y (écrit par install) | N (auto-référence) | N (exclus) |
| `scripts/`, `.github/`, `examples/` | ci/docs | N | N | N |
| `VERSION`, `CHANGELOG.md`, `LICENSE`, `README.md` | meta | N (kit-source) | N | N |
| `tooling/codex/global-config-template.toml` | distribution-alt | **N — orphelin** | N | N |
| `tooling/gemini/gemini-extension.json` | distribution-alt | **N — orphelin** | N | N |

---

## Section B — Pivot manifest

**`.kit-manifest`** : 101 entrées, toutes existent sur disque, toutes ont une source canonique identifiable.

### B.1 — Couverture validate

| Groupe | Entrées | Couvert par validate.sh ? |
|---|---|---|
| Codex (`AGENTS.md`, `.codex/*`, `.agents/skills/*`) | 44 | ✅ |
| Claude (`CLAUDE.md`, `.mcp.example.jsonc`, `.claude/*`) | 57 | ✅ |
| **Gemini (`GEMINI.md`, `.geminiignore`, `.gemini/*`)** | **22** | **❌ aucun check** |

### B.2 — Orphelins dogfood

Aucun. Tous les fichiers trackés sous `.claude/`, `.codex/`, `.agents/` sont dans le manifest. `.claude/settings.local.json` est correctement gitignored.

### B.3 — Sources non distribuées (`MISSING_DISTRIBUTION`)

| Fichier source | Devrait être installé ? | Action |
|---|---|---|
| `tooling/codex/global-config-template.toml` | Ambigu — pas de doc d'usage | P3 — clarifier intention ou supprimer |
| `tooling/gemini/gemini-extension.json` | Probable (manifest d'extension Gemini) | P1 — vérifier intention puis ajouter au pipeline |

---

## Section C — Traçabilité issues → source (historique complet)

**Méthodologie** : agent 1 a reconstruit l'historique depuis le CHANGELOG (60 versions, ~60 PRs documentés) et croisé avec les fichiers réellement modifiés.

### Statistiques globales

| Classification | Count | Notes |
|---|---|---|
| `SOURCE_OK` | ~48 | Touche `tooling/`, `skills/`, `scripts/`, `prompts/`, `.github/`, root `*.md` |
| `DOGFOOD_INTENTIONAL` | 2 | PR #213, v1.16.5 |
| `DOCS_ONLY` | ~5 | README/CHANGELOG/docs |
| `CI_ONLY` | ~3 | `.github/workflows/` |
| **`DOGFOOD_ONLY` user-facing** | **0 confirmé** | ✅ |

### Suspects investigués (tous innocentés par diff)

| PR / Version | Raison de suspicion | Verdict |
|---|---|---|
| v1.19.10 — Consolidation sweep | CHANGELOG ambigu sur quel `AGENTS.md` modifié | ✅ `tooling/codex/AGENTS.md` explicite |
| v1.19.5 — commit-style rule | CHANGELOG dit "moved into CLAUDE.md, AGENTS.md, GEMINI.md" sans préfixe `tooling/` | ✅ `tooling/claude/CLAUDE.md` contient bien `## Git rules` aujourd'hui |
| v1.11.0 — doc pass | "Added section to CLAUDE.md" — laquelle ? | ✅ section présente dans `tooling/claude/CLAUDE.md` |

**Verdict section C** : aucun bug DOGFOOD_ONLY confirmé sur l'historique complet. La PR #213 a structurellement fermé cette classe de bug pour Claude+Codex. Reste le risque historique pré-v1.16.5 et le trou Gemini (section H).

**Note** : ton intuition de départ — "mes issues ont été appliquées uniquement à l'installation locale" — n'est **pas confirmée** par l'audit. Les PRs récentes touchent bien `tooling/`/`skills/`. Le vrai problème est ailleurs (sections D et F.5).

---

## Section D — CHANGELOG

### D.1 — Présence dans CHANGELOG des 10 dernières PRs `feat`/`fix`/`perf`

| Commit | PR | Type | Sujet | Dans CHANGELOG ? |
|---|---|---|---|---|
| `a150925` | #213 | fix | catch dogfood source drift | **❌ MANQUANT** |
| `401414b` | #211 | feat | read kit version from root VERSION | **❌ MANQUANT** |
| `6fc02d7` | #209 (#185) | feat | document features.* flags | **❌ MANQUANT** |
| `7f5d1c7` | #208 (#152) | perf | scope format-on-save | **❌ MANQUANT** |
| `8d452a1` | #199 (#142) | perf | align subagents | **❌ MANQUANT** |
| `a67ad40` | #133 | fix | Windows hook execution portable | **❌ MANQUANT** |
| `2fee3fa` | #135 (#92) | fix | skills frontmatter contract | ✅ |
| `39f5d70` | #134 (#81) | fix | PR diff materialization | ✅ |
| `4148f5c` | #131 (#57, #94) | fix | format-on-save patch scope | ✅ |
| `c5ac07a` | #130 (#41, #42) | fix | Windows ExecutionPolicy | ✅ |

**Conclusion D.1** : `CHANGELOG.md` s'arrête à v1.19.38 (2026-05-24). Au moins **6 PRs `feat`/`fix`/`perf`** ont été mergées après sans bump de version ni entrée CHANGELOG. `VERSION` est resté à `1.19.38`. **C'est le bug que ton intuition cherchait.**

### D.2 — Synchronisation des versions

| Fichier | Version trouvée | Aligné sur `VERSION` (1.19.38) ? |
|---|---|---|
| `VERSION` | 1.19.38 | — |
| `CHANGELOG.md` (top) | 1.19.38 (2026-05-24) | ✅ |
| `.claude-plugin/plugin.json` | 1.19.38 | ✅ |
| `tooling/gemini/gemini-extension.json` | 1.19.38 | ✅ |
| `.claude-plugin/marketplace.json` | **(absent)** | N/A — format catalogue, pas plugin |

Les versions sont alignées **entre elles**, mais collectivement **6 PRs en retard** sur l'état du code.

### D.3 — Format

- Conforme à keepachangelog.com ✅
- Pas de section `## [Unreleased]` ❌ — l'absence explique en partie pourquoi les 6 PRs récentes flottent sans destination

---

## Section E — Documentation

### E.1 — Références fichiers depuis docs racine

| Doc | Références cassées |
|---|---|
| README.md | Aucune détectée |
| CONTRIBUTING.md | Non vérifié en détail (agent stallé), à recheck en Phase 2 |
| SECURITY.md | Non vérifié en détail |
| CLAUDE.md | Tables de routage à vérifier (E.2) |
| AGENTS.md | Tables de routage à vérifier (E.2) |

### E.2 — Tables de routage (skills/commands/subagents)

**Non vérifiée en exhaustivité** (l'agent 3 a stallé sur cette section). Vérification rapide manuelle :

| Surface | Compte canonique | Compte dogfood | Compte tooling |
|---|---|---|---|
| Skills | `skills/` = 30 dirs | `.claude/skills/` = 30 + README | `.agents/skills/` = 30 + 5 agents + README |
| Slash commands | `prompts/` = 11 .md | `.claude/commands/` = 11 | `tooling/gemini/commands/` = 11 .toml |
| Subagents | `tooling/claude/agents/` = 5 | `.claude/agents/` = 5 | `tooling/gemini/agents/` = 5 |

Les **comptes sont cohérents** entre source et dogfood pour les 3 axes. Recommandation : ajouter en Phase 2 un test CI qui vérifie cette cohérence par **nom** et pas seulement par compte.

### E.3 — Claims numériques

- CLAUDE.md : "shipping the 30 skills" ✅ (skills/ = 30)
- README.md : "**30 skills**" et "30 skill files" ✅
- marketplace.json description : "30 tool-agnostic engineering skills" ✅

### E.4 — Frontmatter skills

Non vérifié exhaustivement. À couvrir par test T7 en Phase 2 (un script qui valide `name:` et `description:` dans chaque `SKILL.md`).

### E.5 — Liens markdown brisés

Non vérifié. À couvrir par test T8 en Phase 2.

---

## Section F — Hygiène repo complète

### F.1 — Fichiers orphelins

Aucun. Tous les fichiers racine sont des meta-fichiers attendus (LICENSE, VERSION, *.md, .mcp.example.jsonc, .mcp.json, .gitignore).

### F.2 — TODOs / FIXMEs

| Fichier | Présence |
|---|---|
| `.agents/skills/README.md`, `.claude/skills/README.md` | OK (doc référentielle) |
| `examples/filled-project/docs/ai/TESTING.md` | OK (exemple) |
| `prompts/tech-debt.md`, `.claude/commands/tech-debt.md` | OK (le mot apparaît, c'est l'objet du skill) |
| `scripts/new-skill.ps1`, `scripts/new-skill.sh` | À vérifier si TODO réel ou pattern littéral |

Aucun TODO suspect en première lecture.

### F.3 — Parité Bash ↔ PowerShell des scripts

Non vérifié exhaustivement. L'agent 2 confirme la parité de `validate.sh`/`validate.ps1` (même structure, mêmes 4 checks). Reste à vérifier `install`, `update`, `new-skill`, `uninstall`.

### F.4 — .gitignore / .gitattributes

`.gitignore` propre et explicite. Section "Gemini install outputs are not dogfooded" intentionnelle. Pas de `.gitattributes` détecté.

### F.5 — **🔴 Permissions hooks (P0)**

**Découverte critique** : les fichiers `.sh` dans le dogfood ne sont **PAS exécutables**, alors que les sources canoniques le sont.

| Hook | Mode source (`tooling/`) | Mode dogfood (root) |
|---|---|---|
| `claude/hooks/format-on-save.sh` | **100755** ✅ | **100644** ❌ |
| `claude/hooks/notify-done.sh` | **100755** ✅ | **100644** ❌ |
| `claude/hooks/pre-bash-guard.sh` | **100755** ✅ | **100644** ❌ |
| `claude/hooks/session-summary.sh` | **100755** ✅ | **100644** ❌ |
| `codex/hooks/format-on-save.sh` | **100755** ✅ | **100644** ❌ |
| `codex/hooks/notify-done.sh` | **100755** ✅ | **100644** ❌ |
| `codex/hooks/pre-bash-guard.sh` | **100755** ✅ | **100644** ❌ |

**Impact** :
- Sur Linux/Mac, **les hooks dogfood ne s'exécutent pas** quand ce repo est utilisé en local — sauf si le shell les invoque via `bash <fichier>`.
- `validate.sh` compare le **contenu** (`cmp`), pas le **mode** — la dérive est invisible aux checks actuels.
- Risque additionnel : si `scripts/install.sh` ne préserve pas le mode lors de la copie (`cp` sans `-p`), les nouvelles installations héritent du même bug.

**Reste à vérifier en Phase 2** : `install.sh` préserve-t-il le mode exécutable ? Si non, **toute installation Linux/Mac est cassée** — escalade à P0 critique.

### F.6 — Examples

`examples/filled-project/` est référencé une fois (`README.md:526`). OK.

### F.7 — Licence cascade

`LICENSE` (MIT) uniquement à la racine. `.claude-plugin/` distribué via marketplace n'inclut pas de LICENSE — c'est probablement OK car le plugin pointe vers `./` (source: `./` dans marketplace.json) qui inclut LICENSE. **P3 — vérifier en Phase 2.**

### F.8 — CI workflow triggers

Tous les workflows triggent sur `pull_request` (branches ouvertes). `powershell.yml` triggert également sur `push` to `master` ✅ (cohérent avec branche par défaut).

**Aucune divergence `main` vs `master`** détectée.

---

## Section G — Audit historique mécanique

Voir Section C. Résultat : 0 PR DOGFOOD_ONLY user-facing confirmée sur l'historique complet.

---

## Section H — Parité installeurs (cross-check 5 systèmes)

### H.1 — Codex (44 entrées manifest)

| Système | Couverture |
|---|---|
| `install.ps1` | ✅ |
| `install.sh` | ✅ |
| `update.ps1` | ✅ |
| `update.sh` | ✅ |
| `validate.sh` / `validate.ps1` | ✅ |

### H.2 — Claude (57 entrées)

| Système | Couverture |
|---|---|
| Tous (5/5) | ✅ |

### H.3 — **🟠 Gemini (22 entrées manifest, P1)**

| Système | Couverture |
|---|---|
| `install.ps1` | ✅ |
| `install.sh` | ✅ |
| `update.ps1` | ✅ |
| `update.sh` | ✅ |
| **`validate.sh` / `validate.ps1`** | **❌ AUCUN check de dérive** |

`scripts/validate.sh` lignes 153–201 (et `.ps1` lignes 149–176) n'a aucun cas pour `GEMINI.md`, `.geminiignore`, `.gemini/settings.json`, `.gemini/agents/*`, `.gemini/commands/*`. Toute édition de `tooling/gemini/*` peut diverger silencieusement.

**Second effet** : `.gitignore` exclut `/GEMINI.md`, `/.geminiignore`, `/.gemini/`. Si quelqu'un lance `validate.sh -Target .`, les 22 entrées Gemini du manifest seront signalées "missing from dogfood install" → **22 faux positifs**. Le check ne marche ni dans un sens ni dans l'autre.

### H.4 — Sources non distribuées (orphelines)

| Fichier | install.* | update.* | validate.* |
|---|---|---|---|
| `tooling/codex/global-config-template.toml` | ❌ | ❌ | ❌ |
| `tooling/gemini/gemini-extension.json` | ❌ | ❌ | ❌ |

~~Intention de distribution non documentée. **P1**.~~

**Errata (PR-D)** : les deux fichiers se sont avérés être des références/scaffolds intentionnels, déjà documentés dans `README.md:195-204` :
- `global-config-template.toml` = template pour `~/.codex/config.toml` (per-user, pas per-projet)
- `gemini-extension.json` = scaffold pour distribution via `gemini extensions install`, validé par CI (`lint-plugin-manifest`) qui assure `version == VERSION`

L'agent codebase-investigator qui a produit cette section H a lu `tooling/` mais pas la section "Two maintained files are intentionally not placed by the install script" du README. Voir le tableau "Statut de correction" en haut.

### H.5 — Asymétries `*.windows.json` ↔ `*.json`

- `tooling/codex/hooks.json` (POSIX) vs `tooling/codex/hooks.windows.json` — pas de check d'alignement sémantique
- `tooling/claude/settings.json` (POSIX) vs `tooling/claude/settings.windows.json` — idem

Risque : une modification d'un côté n'est pas répliquée de l'autre. **P2**.

---

## Classement final des findings

### 🔴 P0 — installation cassée / régression utilisateur

**P0-A — Permissions hooks dogfood non exécutables**
Fichiers : 7 fichiers `.sh` sous `.claude/hooks/` et `.codex/hooks/`. Source : 100755 ; dogfood : 100644.
Impact : hooks ne tournent pas sur Linux/Mac en mode dogfood. Si `install.sh` ne préserve pas le mode, **toutes les installations POSIX sont cassées**.
Action Phase 2 :
1. Vérifier le comportement de `install.sh` (cp -p ? chmod +x ?).
2. `chmod +x` puis `git update-index --chmod=+x` sur les 7 fichiers dogfood.
3. Étendre `validate.sh` pour comparer aussi le mode (`git ls-files -s`).

**P0-B — CHANGELOG en retard de 6 PRs**
Fichiers : `CHANGELOG.md`, `VERSION`.
PRs manquantes : #199, #208, #209, #211, #212 (docs, optionnel), #213, #133 (déjà ?).
Impact : tag/release suivant aura un changelog incomplet ; users qui suivent le changelog n'ont pas le détail du fix #213.
Action Phase 2 :
1. Ajouter une section `## [Unreleased]` à `CHANGELOG.md`.
2. Backfiller les 6 entrées manquantes.
3. Décider du prochain bump version (probablement `1.20.0` vu `feat` de #211 et #209).
4. Ajouter un test CI T6 (cf. Phase 2) qui refuse une PR `feat`/`fix`/`perf` sans diff dans CHANGELOG.

### 🟠 P1 — dérive future garantie

**P1-A — Gemini sans check de dérive validate** (22 fichiers).
**P1-B — `tooling/gemini/gemini-extension.json` orphelin** (intention de distribution ?).
**P1-C — `tooling/codex/global-config-template.toml` orphelin** (idem).
**P1-D — Asymétrie `*.windows.json` ↔ `*.json` non vérifiée sémantiquement**.
**P1-E — `validate.sh` ne compare pas les permissions** (cause de P0-A).

### 🟡 P2 — gap structurel

**P2-A — Pas de section `## [Unreleased]` dans CHANGELOG** (favorise l'oubli).
**P2-B — Gate validate `tooling/codex && tooling/claude` ne mentionne pas Gemini**.
**P2-C — Parité ps1/sh des scripts `install`, `update`, `new-skill`, `uninstall` non auditée exhaustivement**.
**P2-D — Frontmatter skills + liens markdown non vérifiés** (limite agent 3).

### 🟢 P3 — nettoyage

**P3-A — 22 faux positifs Gemini si on lance validate sur ce repo source**.
**P3-B — `.claude-plugin/` n'a pas son propre LICENSE** (probablement OK via marketplace.json `source: ./`).
**P3-C — `marketplace.json` sans champ `version`** (probablement intentionnel par spec).

---

## Plan de correction recommandé (Phase 2 — non démarrée)

Ordre suggéré, **une PR par concern** :

1. **PR Phase-1** — ce rapport (`docs/ai/DOGFOOD_AUDIT.md`), 0 modif source.
2. **PR-A** (P0-A) — chmod +x sur les 7 hooks dogfood + extension `validate.sh` pour comparer le mode.
3. **PR-B** (P0-B) — backfill CHANGELOG des 6 PRs + section `[Unreleased]` + bump VERSION.
4. **PR-C** (P1-A) — extension `validate.sh`/`validate.ps1` pour couvrir les 22 entrées Gemini + revoir la gate.
5. **PR-D** (P1-B/C) — clarifier intention de `gemini-extension.json` et `global-config-template.toml` (installer ou documenter comme refs).
6. **PR-E** — test CI T5 "PR-classifier" : refuse une PR qui touche dogfood sans toucher la source (ferme structurellement la classe de bug).
7. **PR-F** — test CI T6 "CHANGELOG check" : refuse `feat`/`fix`/`perf` sans entrée CHANGELOG.
8. **PR-G** — tests T2 (cross-OS install), T7 (frontmatter), T8 (liens markdown).
9. **PR-H** — nettoyage P3 (faux positifs, LICENSE cascade).

Chaque PR doit : `validate.sh` ✅ + `install --dry-run` ✅ + CI verte ✅ + ajouter son propre test pour fermer la régression.

---

## Fichiers consultés pour cet audit

- `.kit-manifest`
- `scripts/{install,update,validate}.{sh,ps1}`
- `tooling/claude/`, `tooling/codex/`, `tooling/gemini/` (tree)
- `CHANGELOG.md`, `VERSION`, `README.md`, `CLAUDE.md`, `AGENTS.md`
- `.claude-plugin/{marketplace,plugin}.json`
- `.gitignore`, `.github/workflows/*.yml`
- `git log` (historique complet), `git ls-files -s` (modes)
- `docs/ai/ARCHITECTURE.md`

Tous les findings P0 et P1 ont au moins un fichier:ligne ou un chemin précis pour reproduction.
