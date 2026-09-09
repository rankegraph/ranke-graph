# Changelog

What each release changed in the artifacts a reader depends on: the rules an
implementation follows, the papers' claims, the series' vocabulary, and the
conformance vectors. A change earns an entry when it alters what a document
requires, defines, or removes; rewording does not.

## Unreleased

**`R-QTIMEOP` names one form per field, and drops a trigger no query could
carry.** Its "a `V-TIME` timestamp or an EDTF Level 1 value" read as the
caller's choice, and EDTF admits `2026-01-01T00:00:02Z`,
`2026-01-01T00:00:02.000000000Z` and `2026-01-01T01:00:02+01:00` as one instant
spelled three ways — so a backend comparing stored text against a loosely
spelled bound answered for the neighbouring second. The form is now the field's:
a `V-TIME` field admits a `V-TIME` timestamp alone, a `V-DATED` field an EDTF
value alone, and a glob is rejected with everything else, naming neither form —
a pattern names no instant, and matching one against a fixed-width form half
works, `2026-*` catching a year where `2026-01-01T00:00:02Z*` catches nothing.
An interval is a pair of bounds. The rule also triggered on `compare: temporal`,
which is an ordering collation (`R-QTEMPORAL`) and names no comparison operand,
so no implementation could honour it; the trigger is now the field alone.

**A binding may take its own language's temporal type.** The rule said the value
must be a `V-TIME` timestamp, which is a *text* form, so a caller holding a
native instant was refused — while every implementation that offers one renders
it correctly anyway. The form binds the value as encoded, and a binding MAY
accept its language's temporal type provided it renders it into that form.
Passing one through, or rendering it another way, remains the rejection. The
distinction is worth fixing in the rule because it is unobservable over the
wire: no conformance run can catch a binding that diverges here, so the text is
the only thing governing it.

## v0.25.3 — 2026-09-02

**`R-QTIMEOP` fixes the form of a time a query compares against.** The schema
said the shape of a value a comparison tests was "unconstrained here", so an
implementation had nothing to read and matched whatever the reference engine
happened to accept. Where a comparison tests a time, that value MUST now be a
`V-TIME` timestamp or an EDTF Level 1 value (`V-DATED`), and an engine MUST
reject anything else.

**`R-QTEMPORAL` compares midpoints in nanoseconds.** Its prose said
milliseconds while `rql.schema.json` said nanoseconds, so the unit was the
implementation's choice. `V-TIME` fixes timestamps at nanosecond precision, and
a millisecond midpoint tied two `created_at` values microseconds apart,
discarding a distinction the data model guarantees.

**A tag with no release run fails the release.** The wait for the tag-triggered
workflow reported a missing run and then exited 0, so a release that never built
read as one that had. It now fails, and says how to delete the tag and retry.
The run is matched by an id above a pre-push mark as well, since a commit can
carry several tags and the older runs sit on its SHA.

**The changelog stamp moves into `release-cycle.sh`.** Stamping `## Unreleased`
into `## vX.Y.Z — <date>` was each consumer's own `scripts/release-pretag.sh`,
and a changelog every repository keeps is shared behaviour: a per-repo copy
would recreate the forks this script was extracted to end. The script now
stamps for every consumer, writes a `CHANGELOG.md` where none exists, and
refuses a release whose `## Unreleased` section records nothing. The
`release-pretag.sh` hook stays for pre-tag work that genuinely differs and runs
after the stamp; this repository's own hook is gone, the built-in covering it.

## v0.25.2 — 2026-09-02

**The Sequencer's thread note names step 7.** §Sequencer said step 6 was the
only step advancing the archive head and the only one needing the sequencing
thread, which v0.24.0 made false when it inserted step 7: step 6 writes $k'$
inert, and the advance takes effect at the bookmark. Steps 6 and 7 both run on
the sequencing thread. (`R-C7BOOKMARK`, `R-ABOOKMARK`)

## v0.25.1 — 2026-09-02

**`release-cycle.sh` waits for the pull request's checks, and resumes an
interrupted release.** The script merged the pull request seconds after opening
it, so a base with required status checks refused the merge: ranke-ts's `test`
check made every release there fail. It now waits for the checks and merges once
they pass, stopping on the first red one. It waits rather than passing
`gh pr merge --auto`, which needs "Allow auto-merge" enabled in each
repository's own settings and is on in one of the six. Second fix: a run whose
merge landed and whose tag did not left nothing to open a pull request from, so
re-running failed at `gh pr create` on zero commits ahead. The script now
recognises a branch already on the default branch and tags the merged tip.

## v0.25.0 — 2026-09-02

**Conformance vectors.** Regenerated from ranke-go v0.27.0-rc.2, with a
`bookmarks` array beside the claims. Two accepted cases sit at indices 0 and 1
of one archive's list, recording the two branch tables; seven refusals give
every bookmark rule a case: `V-BMGAPLESS` (a list holding indices 0 and 2,
offered at each end), `V-BMENV` (a two-element payload, and a `kid` naming a
source/note claim), `V-BMSIG`, `V-BMSLOT`, and `V-BMREF`. Each case pairs its
bytes with the `id_seq(i, s)` slot it is offered at, and names the list it
belongs to and whether that list is open. The claims gain the empty initial
branch table and its revision, both accepted, and `rejected-first-table-height`
against `V-ARCHIVEHEIGHT` and `V-HEIGHT`.

## v0.24.3 — 2026-09-02

**The bootstrap snippets build their URL from `RANKE_GRAPH_RAW`.** Both blocks
carried the whole raw.githubusercontent URL on one line, 128 characters in
`fetch-ranke-docs.sh` and 112 in `release-cycle.sh`, over brokkr's 110-character
comment limit. A consumer caches these scripts into its own `bin/` and lints
them there, so the width was a downstream build failure rather than a local
style point: ranke-go's `make lint` broke on it. Each snippet now names the host
once and builds its URL from that.

**`make lint` runs brokkr, and `verify` runs it first.** The gate a release
depends on now covers the scripts it ships, so a comment too wide for a
consumer's linter fails here instead of there. brokkr is assumed present;
a missing one fails with where to install it.

## v0.24.2 — 2026-09-02

**The fetcher's bootstrap carries an `upgrade` recipe.** `$(RANKE_FETCHER)` is a
file target with no prerequisite, so make builds it once and the cached copy then
stands for good: a consumer goes on running the script it first downloaded,
missing every fix and every new document directory since. The BOOTSTRAP block in
`scripts/fetch-ranke-docs.sh` now states the `rm -f` and re-make that makes
`upgrade` mean what it says, for the fetcher and for every other script a
consumer caches from here.

## v0.24.1 — 2026-09-02

**`V-BMGAPLESS`: a bookmark list is gapless.** Its present indices form one
contiguous range, so the list is searchable in both directions from any entry
and the $O(log n)$ search for the latest head stays correct. Contiguity was
previously RankeDB's own discipline inside `R-C7BOOKMARK`; that rule now cites
`V-BMGAPLESS` instead of carrying the clause itself.

## v0.24.0 — 2026-09-02

**Bookmarks replace the Head History.** A bookmark is a signed record of seed,
index, and reference, held in the bookmark store $U_"hist"$: a store of its own
beside the Universe, sequentially addressed by $op("id")_"seq"(i, s)$, may be mutable,
its guarantees deliberately weaker than a claim's. Every bookmark carries the
seed, so any remembered bookmark id recovers the list. The Universe reverts to
content-addressed keys, and `contribution/history` leaves the node classes.
Glossary: bookmark, bookmark store, and bookmark seed replace head index and
history seed. (foundation paper §Bookmarks)

**The Sequencer bookmarks in a step of its own, and the spec fixes the bookmark's
form.** The merge procedure gains step 7: step 6 writes the new branch table $k'$,
inert until step 7 records it as the next bookmark — the advance takes effect
there, so a failure at any step leaves the archive unchanged (RankeDB paper
§Sequencer). In the spec, `V-BMENV` fixes the bookmark as a `COSE_Sign1` over the
bare triplet $S([i, s, k])$ with a `kid` naming its signing contributor claim;
`V-BMSIG`, `V-BMSLOT`, and `V-BMREF` fix its verification; `R-C7BOOKMARK` (gapless
list), `R-ABOOKMARK` (Sequencer-only writes), and `R-BMPREFIX` (keyspace
separation) carry RankeDB's choices. `V-HISTCLAIM`, `V-HISTCLAIM0`, `V-HISTCHAIN`,
`V-HISTREF`, `V-IDSEQVERIFY`, `R-C2HISTORY`, and `R-C6HISTORY` are removed;
`V-TABLEREF` reverts to branch-tables-only referrers; the `history_index`,
`history_seed`, and `history` aliases are withdrawn — no released archive ever
held a record using them.

## v0.23.8 — 2026-09-01

**`V-HISTCHAIN` admits a Head History with gaps.** The walk-back from the
head named at index $i$ to the one named at index $0$ now only needs to
reach it, at whatever distance the intervening advances left — previously it
had to land exactly $i$ predecessor steps back, which only holds if every
single archive advance gets its own entry. That was a portable, `FORCED`
requirement; writing on every advance is `R-C6HISTORY`, RankeDB's own
choice (`FREE`), so the ADT-level rule shouldn't have assumed it. RankeDB's
own history still stays gapless; another implementation MAY now batch
entries and still verify.

## v0.23.7 — 2026-09-01

**§Backup states two recovery paths, not one conflated with the other.** A
single head id $k$ recovers and verifies $RG_k$ directly. The id of the Head
History's first claim recovers the seed instead, from which the sequence of
per-step pointers can be looked up and each referenced archive recovered the
same way — not, as an earlier pass said, a direct route to "whichever head
the archive currently holds." RankeDB's `$universe` access right is worded to
match: "an id kept outside RankeDB," not "a head id," since the Head
History's first-claim id isn't a head id either.

## v0.23.6 — 2026-09-01

**`V-ARCHIVEHEIGHT` states why an archive's genesis branch-table has height
1.** Its `contribution/contributor` edge is its only reference, resolving
directly to the archive's initial claim, height 0 — the derivation
`V-HISTCLAIM0` needs to anchor `V-HISTCHAIN`'s base case to true genesis
rather than an arbitrary point in the chain, not just the number itself.
`V-ROOT` now points to it as the concrete case of its own height-0/height-1
split; `V-HISTCLAIM0` cites it instead of repeating the derivation.

## v0.23.5 — 2026-09-01

**`fetch-ranke-docs.sh` also carries `TYPST_VERSION`.** It names the Typst
release that renders the fetched documents correctly (`shared/handbook.typ`
among them), which makes it a fact about the fetch, the same as
`vocabulary.typ` already is — not a pin a consumer decides and maintains on
its own. That let one part repo's copy silently drift from ranke-graph's;
`ranke-website`'s downstream feedback caught it before `G-TYPST` did.

**`V-HISTCHAIN` verifies Head History traces back to this archive's own
genesis.** Signature checking alone cannot catch a `contribution/history`
claim signed by, or pointing into, an unrelated graph: a foreign
contributor's signature verifies exactly as cleanly as a local one. Walking
the head a history claim names back exactly $i$ steps along its own
`contribution/diff`/`contribution/branches` predecessor edges, and checking
it reaches the head named at `id_seq(0, s)`, roots the check in this
archive's own seed instead — the one thing a foreign claim can't share.
`V-HISTCLAIM0` now also requires that anchor to be a `contribution/branches`
claim of height 1, the archive's genesis table.

## v0.23.4 — 2026-09-01

**`make release` checks the tree is clean before `verify`, not after.**
`release: verify` ran the whole gate — every paper, the schema check, both
docs backends — before `scripts/release.sh`'s own first line ever asked
whether the tree was even clean. `check-clean-tree` is now `release`'s first
prerequisite: free and instant, so a dirty tree fails immediately rather than
after a full build. Moved out of `release.sh` (redundant now) and its later
steps renumbered down by one.

**`make release` also checks the bump word before `verify`, not after.** Same
gap: `major|minor|patch` (and its aliases) was validated by `scripts/release.sh`'s
own case statement, which only runs once `verify` already has. `check-release-bump`
checks `$(MAKECMDGOALS)` for one of the six recognized words first, so a forgotten
or misspelled bump word fails immediately.

**`scripts/release.sh` is now `scripts/release-cycle.sh`, shared across every
consumer.** ranke-go, ranke-ts, ranke-db and ranke-graph each carried their own
near-identical copy of the same release mechanics (branch resolution, the
merge-then-tag dance, the wait for CI) — the two bugs just fixed above had to
be hand-applied to four files because of it. What differs per repo (how the
next version is decided, what must happen before the tag is cut) is now a
convention, not a fork: a consumer drops `scripts/release-next-version.sh`,
`scripts/release-pretag.sh`, and/or `scripts/release-feature-branch-only` at
those fixed names, and this script picks them up. ranke-graph's own former
changelog-stamping step is now its `scripts/release-pretag.sh`, unchanged in
behaviour. See the script's own header for the full interface.

**`V-TABLEREF` was blocking every Head History claim it should have allowed.**
It restricted a `contribution/branches` claim's referrers to another
`contribution/branches` claim, with no exception — but a `contribution/history`
claim's `contribution/head` edge (`V-HISTCLAIM`) always names the archive's
head, which is always a branch-table claim (`V-ARCHIVE`). Every history claim
therefore failed verification the moment a real implementation checked one.
`contribution/history`, through its `contribution/head` edge, is now a second
permitted referrer.

**`V-HISTADVANCE` is gone; `R-C6HISTORY` alone covers what it was for.**
`V-HISTADVANCE` (v0.23.1) was misclassified `FORCED`: a `FORCED` rule must be
decidable from a record or a closure, and this one was not, since a history
claim sits outside both by design (`V-HISTREF`). What it required, the
Sequencer writing a Head History entry at merge time, is `R-C6HISTORY`'s
obligation already, correctly `FREE`. Keeping both would have restated the
same requirement twice; `R-C6HISTORY` now states it in full on its own.

## v0.23.3 — 2026-09-01

**`fetch-ranke-docs.sh` gains a `--release R` mode.** The release tarball
`docs-bundle` publishes was documented as usable by a consumer that cannot
clone, but nothing in the script actually fetched it — every consumer still
cloned `main` (or `--if-moved`'s cheap check against it) even for a build that
wanted a released version. `--release R` (`R` a tag, or `latest`) downloads
and unpacks `releases/.../ranke-docs.tar.gz` in place of the clone, no git
required, and reads the tarball's own embedded stamp so `--if-moved`'s
freshness check reads a release-fetched tree exactly as it reads a cloned
one. A consumer pinning `R` to a tag traces its documents to a released
version rather than to `main`'s tip — the discipline `tools/go.mod` already
holds `ranke-go` to.

## v0.23.2 — 2026-09-01

**The release bundle carries `docs-spec/`.** `ranke-docs.tar.gz` packed the
numbered papers, `shared/`, `spec/`, and `glossary/`, but not `docs-spec/` — so
the worked example the specification points a backend author at (a reference
chapter tree, a stub HTML backend) was reachable only by fetching it file by
file through the GitHub trees API. It is in the bundle now, the two gitignored
shims a consumer supplies themselves excluded.

**Part repositories publish the Typst version they built with.** `G-TYPST`
(docs-spec) requires it: a plain-text file, one line, attached beside the
release asset — not a fact a consumer has to read a Makefile to find.
`ranke-graph` follows its own rule: `TYPST_VERSION` at the repository root is
now the one pin `scripts/check.sh`, the release workflow, and
`dist/TYPST_VERSION` all read, replacing three copies that could drift apart.
`docs-spec/scripts/check-typst-upgrade.sh` ships beside the specification for
a part repository to copy: it checks a pin against Typst's latest release and
reports the difference, never writing it.

## v0.23.1 — 2026-09-01

**A Ranke-Archive's head history is addressed independently of content.** The
foundation paper adds a second identity function, `id_seq(i, s)`, keyed on a
step and a per-history seed rather than on a claim's own bytes. A
`contribution/history` claim recorded under it lets an archive's current head
be found by a doubling-then-binary search over the Universe alone — no
pointer kept outside the graph. Universe, Verifiability, Backup, Composing the
Universe, and the Type Vocabulary state the mechanism and its one exception to
content addressing.

RankeDB's Sequencer used to keep this history in its own persistence adapter,
a bespoke port with its own backends (in-memory, filesystem, Postgres). That
port is gone: the history now rides the existing Blob Store contract, and the
merge procedure records the next entry on every advance. The normative
specification gains six rules for the mechanism (`V-IDSEQ`, `V-HISTCLAIM`,
`V-HISTCLAIM0`, `V-HISTREF`, `V-HISTADVANCE`, `V-IDSEQVERIFY`) and two
reserving history claims to the Sequencer (`R-C2HISTORY`, `R-C6HISTORY`).

*This is new, mandatory behaviour.* `V-HISTADVANCE` is FORCED: any archive
advance not accompanied by a Head History entry fails verification. An
existing implementation needs Head History support to stay conformant.

**A branch's head need not be a `contribution/head` claim.** §Branches said
otherwise, overstating the consolidation case (multiple open heads gathered
into one) as the general rule. The ordinary case leaves a branch's head as
whatever claim was last contributed — a `derivation`, an `entity`, anything.

## v0.23.0 — 2026-09-01

**The authoring guide says where the example tree is.** It told a reader to copy
the directory without saying where to find it, and the fetcher does not deliver
it — reasonably, since what the fetcher delivers is what a chapter imports,
while the example is copied once and then owned. The annex now carries the URL
and says why it arrives that way.

**Release tooling.** `scripts/release.sh` leaves a fresh `## Unreleased` heading
behind after stamping one, so a change always has a section to write into.
Cutting a release consumed the heading and put nothing back, which is why there
was none. It also now refuses to stamp an *empty* `## Unreleased`: without that
check, leaving a heading behind would let the next release ship recording
nothing, which is the failure the step exists to prevent.

## v0.22.0 — 2026-08-31

**`docs-format/` is now `docs-spec/`**, and the document it holds is
`ranke-docs-spec.typ`, released as `ranke-docs-spec.pdf`. The old name said what
the directory was about; the new one says what it *is*, in the same way `spec/`
does — the rules, with `shared/vocabulary.typ` and ranke-website's backend as
implementations of them, not the other way round. The document now states that
precedence itself, which it had left unsaid: where a backend and the
specification disagree, the backend is the defect.

*This changes a release asset URL.* `releases/latest/download/ranke-docs-format.pdf`
becomes `.../ranke-docs-spec.pdf`. Only v0.21.0 published the old name, and the
README is the only thing that linked it.

**Construct groups.** `shared/constructs.typ` declares three groups where it
declared one flat list: `common`, `paper`, and `manual`. The series has two
kinds of document — a paper argues and proves, a manual says how something is
used — and the split says which constructs belong to which. The chapter
contract a backend must bind is `common + manual`; the print backend binds all
three, since it serves both kinds. `unbound()` takes the set to check against.

This changes the shape of `constructs.typ` released in v0.21.0. A backend
written against that version binds a superset of what it now owes, so it keeps
passing; a backend that bound only the old list gains four names.

**Paper constructs leave the chapter contract.** `theorem`, `corollary`,
`proof`, and `definition` join `imageonside` in the paper group. A web backend
is no longer asked to render a proof. `G-CONSTRUCTS` states it: a manual that
proves a theorem has mistaken its kind, and should state the guarantee and cite
where it is proved.

**New constructs.** `note` and `warning`, the two admonition levels — and
deliberately only two, since a third sits between them in no way an author can
decide quickly. `item(signature, body)` for a named thing with a signature: a
flag, a configuration key, an API field. `example(body, title: none)` for a
worked case. `listing(body, size:)` and `rule(id, tier, body)` move into the
vocabulary from the two documents that had each written them separately.

**The specification and the authoring guide adopt them**, dropping their local
copies. The specification renders identically to v0.21.0: `listing` keeps its
size as a parameter, because its type listings are long and set at 0.82em.

**Both examples named for what they exemplify.** The contract has two parties,
and `docs-spec/examples/` now holds one example of each: `docs-tree/`, what a
chapter author writes, and `html-backend/`, what a renderer implements. Neither
directory said it was an example before, and neither said of what.

**Reference tree moved and rewritten.** `docs/` becomes
`docs-spec/examples/docs-tree/`, joining the rules it exemplifies, the second
backend and the contract check — so `docs-spec/` reads as one document directory, the
shape `spec/` and `01-ranke-graph/` already have, and the confusable pair of
`docs/` beside `docs-spec/` is gone.

Its prose is now Typst's `lorem`. It read as an excerpt of the papers, restating
the node fields, identity and the integrity checks in its own words: the drift
`G-CITE` forbids, shipped as the thing every part repository copies. Placeholder
text cannot fall out of step. What the example demonstrates is the calls — the
labels, the ids, the signatures, the shape of the tree.

**`ranke-handbook.pdf` is no longer released.** It was the example tree
published as though it were documentation. The example is compiled by the gate,
both ways, and never attached. `make handbook` and `make handbook-html` are now
`make example` and `make example-html`.

## v0.21.0 — 2026-08-31

**Documentation format.** A new companion document,
`docs-format/ranke-docs-format.typ`, released as `ranke-docs-format.pdf`
alongside the specification. It fixes the rules a repository's `docs/` tree
follows so one chapter file renders to both PDF and HTML: the tree layout
(`G-DIR`, `G-ROOT`, `G-CHAPTER`), the import-path contract (`G-IMPORT`,
`G-CLOSURE`, `G-COMPILE`), what each construct means (`G-CONSTRUCTS`), the
rule that a chapter may not reach past the vocabulary into raw layout
(`G-NOLAYOUT`), assets and cross-references (`G-ASSETS`, `G-XREF`,
`G-XREF-B`), terminology (`G-GLS`, `G-GLOSSARY`, `G-CITE`), what a backend
owes (`G-BACKEND`), and the build (`G-SUPPLIED`, `G-FETCH`, `G-VERSION`,
`G-RELEASE`).

**Vocabulary split.** The constructs a document writes with move from
`shared/template.typ` into `shared/vocabulary.typ`, which carries no
page-level layout, so a second renderer can bind the same names.
`shared/typography.typ` holds the look both roots draw on, and
`shared/template.typ` re-exports everything, leaving the papers unchanged —
they render identically. `shared/constructs.typ` names the contract in one
place, and `docs-format/check-backends.typ` fails the build on a name either
backend leaves unbound.

**New constructs.** `diagram(path, caption)`, a captioned picture named by a
project-absolute path; it is the branch point an HTML backend needs, since
`image()` under HTML export inlines a base64 data URI.

**Handbook root.** `shared/handbook.typ`, the docs root: paper typography, its
own front matter, a version from `--input version=`, and a glossary appendix
after the body. The appendix is what makes `#gls()` resolve, since glossarium
creates a term's label where the glossary is printed.

**Reference tree.** `docs/` holds a documentation tree in the format, covering
the foundation part, released as `ranke-handbook.pdf`. Every construct appears
in it at least once, and `make verify` builds it through both backends.

**Documents bundle.** `ranke-docs.tar.gz`, a new release asset at a stable URL:
the papers, the spec, the glossary and `shared/`, stamped with the commit they
came from, for a build that cannot clone. The fetcher packs it and the fetcher
clones, from one definition of what a document is, so the tarball and the clone
give the same tree.

**Smaller fetched copy.** Figure sources, working notes and built PDFs are no
longer copied into a consumer: no gate read them, and `02-ranke-db/drawio`
alone was 968 KB of the 976 KB a full copy carried. The set is now 120 KB.

**Shared fetcher.** `scripts/fetch-ranke-docs.sh` — the fetcher ranke-go carried
as `scripts/fetch-papers.sh`, moved here so four consumers run one script. It
keeps the stamp and `--if-moved`, gains a `--place` mode and a `DOCS_DIR` that
puts the vocabulary where a chapter's import resolves, and documents its
interface: `RANKE_GRAPH_REPO`, `RANKE_GRAPH_REF`, `PAPERS_DIR`, `DOCS_DIR`,
`SHARED_DIR`, `RANKE_DOCS_OFFLINE`.

## v0.20.3 — 2026-08-28

Generated new testdata using latest ranke-go v0.26.0

## v0.20.2 — 2026-08-28

Moved the website to it's own repo at github.com/rankegraph/ranke-website

## v0.20.1 — 2026-08-27

**Conformance vectors.** Regenerated from ranke-go v0.25.0-rc.1: a
`rejected-dated-form` case, so `V-DATED` has a case rather than sitting
uncovered.

**Website.** An early draft under `website/`: index, papers, build and use
pages.

## v0.20.0 — 2026-08-27

**Papers.** 01: archival practice dates an artifact twice, the day it entered
the archive and the time it is held to stem from (§Provenance). A node may
carry `dated`, and §Nodes now states which fields every node carries.

**Specification.** `V-DATED` added: an optional `dated` holding a valid EDTF
value at Level 1, outside `V-TIME` and unconstrained by `V-MONO`. Level 1
covers intervals, uncertainty, unspecified digits, and open bounds; Level 2's
sets and exponential years are not part of the language, so every
implementation accepts the same one. `R-QTEMPORAL` added: `compare: temporal`
orders by a span's midpoint in milliseconds, one value per claim that a layer
can store and sort on natively, with equal midpoints falling to `R-QSORT`'s
tie-break. `R-QSORT` gains `temporal`; @tbl:keys gains key 14.

**Schema.** `compare` accepts `temporal`.

## v0.19.1 — 2026-08-25

**Papers.** 01 §Primitives: the envelope is a triplet of scheme, signature and
serialized claim, stated as a verification relation rather than a construction.
`Sign` no longer needs to be self-describing, the scheme having a field of its
own.

**Specification.** `V-ENV` pins the envelope's headers: `alg` alone in the
protected header, the unprotected header empty. Anything further would give one
claim two ids across implementations.

## v0.19.0 — 2026-08-25

**Papers.** 01 §Universe and 02 §Universe: the Universe holds envelopes under
ids and content under hashes, one keyspace, where both said "serialized claims".

**Conformance vectors.** Regenerated from ranke-go v0.22.0 for the envelope, so
every id changes. New refusal cases for edge order, timestamp form, both content
slots at once, and a claim stored without an envelope.

## v0.18.3 — 2026-08-25

**Papers.** 01 §Universe: the Universe contains envelopes, not serialized claims.

## v0.18.2 — 2026-08-25

**Vocabulary.** "Serialized claim" replaces "claim record" throughout the
specification. The glossary gains `envelope` and `serialized claim`; its `id`
entry carried the retired `Sign(H(S(v)))`, and its `universe` entry claimed ids
and hashes never collide, which one keyspace makes moot.

**Convention.** Papers 01 and 02, the specification and CLAUDE.md now each state
that a term introduced, renamed or redefined is updated in the glossary in the
same change.

## v0.18.1 — 2026-08-25

**Specification.** `V-EORDER` added: a node's edges serialize ascending by
`id(e)`, an order nothing previously fixed although it is part of every claim
id. `detail: envelope` added, returning the stored bytes a client can hash
against an id; `R-QCANON` had promised that of `S(v)`, which the envelope made
false. `R-QDETAIL`, `R-QENCODING` and `R-QSTREAM` follow.

**Schema.** `detail` accepts `envelope`.

## v0.18.0 — 2026-08-25

A claim's id is now `H(S(env(v)))`, the hash of a stored envelope, where it was
`Sign(H(S(v)))`, a signature. Every id in every archive changes. Recomputing an
id now takes the bytes and a hash function alone, so any store can check what it
holds; establishing authorship is a second, separate step.

**Papers.** 01: the envelope enters §Primitives, §Verifiability separates
integrity from authenticity, and the identity signature is retired, so every
contributor carries a key. §Relations scopes reification to relations between
entities, which readers had taken to mean every edge. 06 Ranke Cryptography is
removed: its material is covered by 01, 02 and the specification.

**Specification.** `V-ENV` added. `V-ID`, `V-SIG`, `V-SIGN` and `V-SER` follow
the envelope; the identity signature option is retired.

**Build.** A quality gate runs `make verify` in a fresh checkout; `make help`
lists the targets.
