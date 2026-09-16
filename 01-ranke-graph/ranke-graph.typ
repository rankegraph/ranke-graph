#import "../shared/template.typ": *
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge

// ─────────────────────────────────────────────────────────────────────
// Language conventions (not rendered)
//
// British English throughout (writer-style PASSES.md, Pass 1).
//
// Kept as US / CS-conventional forms by deliberate exception:
//   - "artifact" (not "artefact"): established usage across CS and
//     digital-archival literature; both spellings co-exist in BrE
//     academic writing, the US form dominates the field.
//   - "serialization" (not "serialisation"): CS technical term;
//     standard libraries, RFCs, and CS academic literature use -ize.
//
// First-level quotation marks: single ('…'); double for nested ("…").
//
// Terminology: shared/glossary.typ is the single source of truth for the
// series' vocabulary. A term this paper introduces, renames, or redefines
// is updated there in the same change.
// ─────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────
// Notation. U is a content-addressed k/v store. U(k) is the claim envelope at
// id k = H(S(env(v))); U(h) is the external content at hash h = H(c). 
//   RG_k := closure(k, U)  — the graph rooted at head id k
//   RA_k                    — the Ranke-Archive rooted at k; tuple (U, k)
// A later archive is a new tuple (U', k'); nothing is mutated in place.
// "branch-table header (BTH)" is just the head claim U(k) of an archive.
//   id_seq(i, s) := H(i, s) — second address scheme; s a per-list seed,
//     carried in every bookmark, so any bookmark's id opens the list and is
//     self-describing as to hash algo (§Bookmarks).
//   U_hist — the bookmark store, keyed by id_seq(i, s); defined apart from U,
//     freely co-located with it physically (§Bookmarks).
// ─────────────────────────────────────────────────────────────────────

#show: paper.with(
  title:    "Ranke-Graph: A Provenance-First Data Structure",
  author:   "Florian Metzger-Noel",
  date:     "2026-05-03",
  status:   "draft",
  abstract: [Whenever a database updates a record, a knowledge base resolves its sources into one accepted version, or a model folds a corpus into its weights, the effect is the same: statements from various times and origins are consolidated into a single current truth. The provenance, the history of each datum as it is added or merged, is discarded or set aside as 'metadata', and the earlier values are often lost to the reader as well.
Drawing on the archival tradition, the *Ranke-Graph* takes the opposite stance: what consolidation discards, data and provenance alike, was itself knowledge, and it preserves both, the data unaltered and its provenance part of the record itself.
The Ranke-Graph is a Merkle DAG (directed acyclic graph) of *claims*: each a node attributed to a named author at a stated time, with edges citing the earlier claims it draws on as sources or subjects.
This paper defines the Ranke-Graph as an abstract data type, the minimum contract for preserving a graph of such claims, built on established cryptographic primitives: content-addressed storage, a Merkle DAG of derivations, and signatures as proof of authorship. From that small definition the rest follows: the structure is verifiable, queryable, filterable, and cacheable, and it merges, replicates, and distributes without conflict.
The structural form is old, refined over centuries of archival practice; what is new is its realisation in the digital substrate, where systems consolidate by default and provenance is the first thing dropped. Reference implementations in Go and TypeScript accompany the paper, with a binary conformance suite that makes conformance decidable.],
)

= Introduction <sec:introduction>

Consider three statements:

+ _Alice likes apples._
+ _Alice wrote Bob an email saying she likes apples._
+ _A file exists, attributed to Alice by its headers, that appears to be a copy of an email to Bob in which Alice claims to like apples._

The first is a claim about the world. The second adds an attribution. The third is an observation of existence: a file is present, with the stated bytes, metadata, and content.

Storing at the first layer is the classic goal of database design.
Schemas, integrity constraints, and transactions are built to maintain a consistent model of the world; the caller is expected to have applied sound epistemology before writing data.
When facts change, or sources disagree, the database is edited to align; its earlier states, and thus the disagreement itself, are discarded.
In database discipline this is called _destructive consolidation_ or _last-write-wins_; it is commonly considered _data cleaning_, and treated as consistency, not loss. The cleaned value is an artifact of the algorithm; the ambiguity it discarded was itself information.

This is the ordinary condition of the enterprise data store. It works so long as the caller supplies correct facts about the world.

The Ranke-Graph takes the opposite stance.
It stores only at the third layer: attributed claims.
Every node is an observation-of-existence: this artifact, with these bytes, this attribution, added to the graph at this moment, appearing to make the claim its content carries.
The graph does not record whether Alice likes apples, or whether she wrote the email.
It records that a file is present, its metadata is as given, and the record has not been altered since it was written.
The guarantee is narrower than a conventional database's, and therefore keepable.

A _claim_ in the Ranke-Graph is an attributed record: a piece of content added by a contributor at a specified moment. Source claims are external artifacts captured into the graph; derived claims are built from existing claims, citing their references. Formal definition: @sec:claims.

This paper defines the Ranke-Graph as an abstract data type (ADT): the minimum contract an implementation must satisfy to preserve a graph of attributed claims.#footnote[A companion glossary collects this series' terminology for reference (@rankeglossary).]

= The Problem and the Position

== Knowledge Systems: Machines Reading and Writing

Classical knowledge stores (wikis, knowledge graphs, structured databases, plain-text notes) consolidate sources into _current truth_, updating in place or creating new versions as understanding evolves. Creating and maintaining this highly structured information requires permanent effort. Large language models (LLMs) consolidate sources statistically into model weights, with no record of where claims originated or whether they were ever made, producing fuzziness and hallucinations.

Merging the two approaches is an active research area, with many designs proposed. To understand what such a merge should preserve, we turn to the disciplines that have studied knowledge creation and preservation longest: historical science, archival theory, librarianship.

== Provenance: The Archival Tradition

The historian Leopold von Ranke (1795–1886) insisted that every historical claim must trace back to a primary source. His phrase (history _'wie es eigentlich gewesen'_, 'as it actually was') has been criticised for assuming unmediated access to past reality, but the underlying discipline survives: every claim has its derivation, every derivation has its sources. The archival principle _respect des fonds_ (1841) reached the same conclusion independently: records must be kept in the order and context of their origin. Suzanne Briet's 1951 _Qu'est-ce que la documentation?_ added a third angle: attribution is what transforms raw existence into evidence: an antelope in the wild is not a document; an antelope captured, classified, and recorded becomes one. Archival practice dates an artifact twice: the day it entered the archive and the time it is held to stem from. The Library of Congress developed the Extended Date/Time Format (EDTF) to record such assumed dates together with their uncertainty. 

Across these traditions, three conclusions converge: contradictions in the evidence base are themselves evidence; provenance is the knowledge itself; consensus (what to ultimately believe) is downstream from attribution, left to readers and time.

For a comprehensive treatment of provenance across 180 years (from _respect des fonds_ through the Semantic Web to the LLM era), we refer the reader to Talisman's essay (@talisman2026provenance). Following its framing, a modern interpretation treats artifacts (messages, documents, recordings) as sources of subjective views, and derives knowledge by correlation across them.

Centuries of archival practice converged on a small set of principles (provenance, immutability, attribution, dated existence, tolerance for contradiction), not because they were elegant, but because they proved the only stable ground for knowledge under uncertainty, dissent, and change. Digital systems have largely abandoned this ground in favour of current truth and consolidation. The Ranke-Graph is an attempt to bring the proven form into the digital substrate.

Throughout this paper we use *provenance* for the chain of derivation back to sources and contributors, *semantics* for the relations between entities, and *knowledge* for the union of both.

== Two Traditions <sec:two-traditions>

Computer Science treats data and information as primary objects. Bits, structures, algorithms: meaning emerges at the consumer. Knowledge is external to the data.

Historical science and archival theory treat knowledge itself as primary: what is claimed, who claims it, on what basis, in contradiction to what. Data is the carrier; knowledge is the object of study.

The Ranke-Graph operates in the intersection. It uses computer-science primitives (hashes, DAGs, signatures, content-addressing) as substrate for the archival discipline of knowledge.

== The Ranke-Graph

The Ranke-Graph is the data structure for this discipline: a graph of _claims_, each carrying its full derivation chain. Each node is both a statement and the record of how that statement came to be.

=== Everything Is Knowledge <sec:everything-is-knowledge>

The Ranke-Graph makes no distinction between data, metadata, and provenance.
Every claim made _about_ the graph is itself a node in the graph, with its own provenance:

- a classification ('this node belongs to domain X'),
- a summary ('this is a condensed version of the conversation at node X'),
- an alias ('this node refers to the same person as node Y'),
- a creation record ('this node was added by contributor X with configuration Y').

The first three describe meaning; the last records creation. Each is a claim with its own provenance.

*Provenance _is_ knowledge.*

This is compatible with W3C PROV-DM's Entity/Activity/Agent vocabulary (@moreau2013provdm), with the stronger commitment that provenance is stored in the same graph as content, queryable through the same interface, and subject to the same invariants.

=== Provenance and Consensus

The Ranke-Graph handles provenance: who said what, when, on what basis. Consensus (resolving contradictions into a single statement) is built downstream from the claims the graph preserves.

=== Immutability and Accumulation

The Ranke-Graph is append-only: claims accumulate; existing ones are never modified or deleted, since they represent historical artifacts which by the nature of time do not change. A knowledge extraction system (for example an LLM-based agent) thus has more to draw on: it can traverse the full derivation history of a belief, including contradictions, revisions, and competing interpretations. The fuller basis should yield better reasoning than a consolidated summary that lacks provenance and uncertainty.

=== Levels of Distillation

This depth can overwhelm an extraction algorithm, flooding it with contradicting claims and long provenance traces. The Ranke-Graph supports _levels of detail_, realised through a class taxonomy (@sec:types). Summary nodes condense complex clusters; the semantic abstraction layer expresses the distilled claims extracted from sources. The full provenance trace back to the source remains available on request.

Levels of distillation make the Ranke-Graph tractable for any agent or user operating under finite context: every agent has bounded context, every human reader has bounded attention. The pattern is iterative: fetch at high abstraction (just the relation types, say), narrow to the interesting candidates, request more detail on those (conviction values, reasoning content, then provenance edges, then source content), repeat. Each round is bounded; the full graph is reachable but never demanded all at once. A short answer at a coarse level is the right slice for a query that doesn't need finer grain. The agent or user decides when to descend.

=== Taxonomy

Five concepts populate the graph. On the provenance side: *sources* (artifacts captured from outside the graph), *contributors* (humans, programs, or LLM agents that add nodes), and *derivations* (interpretations of existing nodes: classifications, summaries, fact extractions, entity resolutions). On the semantic side: *entities* (identifiable things in the world) and *relations* (assertions about how entities relate, each held as a claim of its own; @sec:semantic-claims).

Contributors and entities are deliberately separate. A *contributor* is operational, the actor whose work brought a claim into the graph. An *entity* is semantic, a thing the graph holds claims about. The same real-world person may appear in both roles: as a contributor who adds claims, and as an entity referenced by relations. They *can* be linked by a claim asserting the connection, but they never share a node.


== A Vision

The two traditions of @sec:two-traditions meet in the ADT; what is built above it is their application. Because the substrate keeps every claim with its full derivation (the archival discipline realised on the computer-science primitives of @sec:primitives), systems built on it inherit provenance rather than reconstruct it: AI assistants whose answers trace back to source records, agents that revisit and revise their reasoning chains, archives that stand up to external scrutiny. These are the oldest archival demands (cite the sources, keep the record, tolerate contradiction), carried into settings that had abandoned them. The ADT is deliberately _under-prescribed_: it preserves claims and their derivation and leaves retrieval, reasoning, and synthesis to the layer above.

Such systems evolve on the same data: selecting views that fit, contributing new derivations, marking, criticising, or disproving earlier contributions. The graph accumulates; the history stays complete, yet filterable and queryable. Retrieval systems select what they deem most useful.

= Desiderata <sec:desiderata>

From the two traditions of @sec:two-traditions, the Ranke-Graph inherits two kinds of obligations: what archival practice has long required of evidence, and what a modern data structure must support. Together they characterise the contract. Additional emergent properties (idempotency of writes, the set algebra, and the bijection between structural and semantic readings) follow as consequences (see @sec:emergent).

The first five concern how knowledge is gathered: the source-criticism methods historians and archivists have refined for centuries. D6 is how knowledge can be captured, D7 how it can be organised. D8 is an operational concern of computer science: distributed use.

*D1. Provenance: every claim references what it's based on and has a path back to its sources.*

*D2. Immutability: no claim is ever modified or deleted.*

*D3. Identity and Authenticity: every claim has a named author whose authorship is verifiable.*

*D4. Temporality: every claim's time of existence is provably bounded.*

*D5. Verifiability: integrity is independently verifiable.*

*D6. Semantic Relations: relations between entities can be expressed.*

*D7. Open Vocabulary: applications can define their own categories and content schemas.*

*D8. Distributability: the structure supports distributed use.*

= The Data Structure <sec:structure>

The Ranke-Graph is a Merkle DAG and a semantic graph, with a single node type (@sec:nodes) and a single edge type (@sec:edges): acyclic by the atomic creation rule (@sec:claims), Merkle by content-addressed hashing, semantic by the direction tag on edges (@sec:semantic-claims), provenance-and-knowledge by a small fixed content-class taxonomy (@sec:types). From this definition, the structural consequences emerge (@sec:emerges).

== Primitives <sec:primitives>

Let $S$ be a canonical serialization mapping any object (node or edge) to bytes. It must be deterministic (same record → same bytes), complete (every field contributes), and self-delimiting (parsing recovers the record exactly).

Let $H$ be a cryptographic hash function. It must be collision-resistant and self-describing.

Let $"Sign"$ be an asymmetric signature function.

Let $"env"$ be the *envelope*, a claim as it is stored: the scheme, the signature, and the serialized claim, $"env"(v) = (a, sigma, S(v))$, where $sigma$ verifies $S(v)$ under scheme $a$ against the contributor's public key.

Any satisfying choice is acceptable. We propose CBOR Deterministic (RFC 8949 §4.2) for $S$, IPFS multihash for $H$, Ed25519 (RFC 8032) or ECDSA for $"Sign"$, and COSE_Sign1 (@rfc9052) for $"env"$, each fixed exactly in the normative specification (@rankespec).

Let $op("id")(v) = H(S("env"(v)))$ be a claim's *identity*: the hash of its stored record. As edges are fully contained in the `edges` field of the node, `S(v)` includes all edges. The signing key is the private key corresponding to the pubkey in $v$'s `contribution/contributor` (or in $v$'s own content, when $v$ is an initial claim).

Let $op("id")_"seq"(i, s) := H(i, s)$ be a second address scheme, keyed on a step $i$ and a seed $s$ rather than on any record's bytes (@sec:bookmarks).

== Content <sec:content>

Having *content* is optional for both nodes and edges. 
The actual content bytes can be either *inline*, in the `content` field, or *external* bytes in the Universe referenced by `content_hash`. 
Content being present requires the fields `content_size`, its byte length, and `encoding`, its media type (a MIME type, @freed2013rfc6838, e.g.~`text/plain`, `image/png`, `message/rfc822`). 

== Nodes <sec:nodes>

#grid(
    columns: (1fr, 1fr),
    column-gutter: 0.8em,
    align: top,
    ```
    node = {
      type
      encoding
      created_at
      dated?
      content_size
      content
      edges
      height
      ...
    }
    ```,
    ```
    node = {
      type
      encoding
      created_at
      dated?
      content_size
      content_hash
      edges
      height
      ...
    }
    ```,
)

- `type` follows the convention in @sec:types: `class` is from a fixed set, `subtype` open vocabulary.
- `created_at` is the UTC timestamp the claim was added, the moment the archive witnessed.
- `dated` is the time the claim's subject is assumed to stem from, in EDTF (@edtf).
- `content_size`, `content`/`content_hash`, and `encoding` follow the content rules of @sec:content.
- `height` is the longest path from the claim along its references, $max({"height"(u) + 1 : u in "refs"(v)} union {0})$, so an initial claim carries 0 and every reference sits strictly lower than the claim citing it. A set of claims bounded by height is therefore closed under references.
- Extension fields participate in $S$ like any other field, so proofs (@sec:verifiability and onward) apply uniformly.

Every node carries `type`, `created_at`, and `height`. `dated` is optional, and the content fields follow @sec:content.

== Edges <sec:edges>

#grid(
    columns: (1fr, 1fr),
    column-gutter: 0.8em,
    align: top,
    ```
    edge = {
      reference
      type
      encoding
      content_size
      content
      ...
    }
    ```,
    ```
    edge = {
      reference
      type
      encoding
      content_size
      content_hash
      ...
    }
    ```,
)

Edges point from the claim owning the edge to the `reference` claim. For types see @sec:types. 

== Claims <sec:claims>

A *claim* is a node together with its content and the edges in its `edges` set. Each node or edge belongs to exactly one claim. A claim is created in a single atomic transaction; nothing can be added afterwards. The node's hash covers every edge created with it, so $op("id")(v)$ is final at creation time. Atomic creation also requires monotonicity: $"created_at"(v) >= max("created_at"(u))$ over $v$'s references $u$, so a claim cannot predate what it references.

A claim may overlay another: carrying a `contribution/diff` edge (@sec:types), it restates only what differs from the predecessor it references, its full contents *materialised* by applying that delta over the predecessor, recursively to a base claim. Restatement adds and replaces; dropping an inherited field or edge needs naming it in a field of its own, which the normative specification fixes (@rankespec).

== Relations (Semantic Claims) <sec:semantic-claims>

Provenance requires acyclicity: content addressing has no fixed point in a graph with cycles. But knowledge typically lives in a *semantic graph* where cycles are common: _Alice — knows → Bob_, paired with _Bob — ignores → Alice_.

A relation *between entities* is a claim of its own: a `relation/*` node with `relation/*` edges to the `entity/*` claims it binds.#footnote[This is the pattern known as *reification*; see RDF 1.0's `rdf:Statement` (@lassila1999rdf). The schema in @sec:edges constrains an edge's `reference` to a claim, never another edge, so an assertion that later claims cite is held as a claim.] Its edges have a `relation_direction` field with values `from=1` or `to=-1`. All-`from` or all-`to` expresses a symmetric relation between the referenced entities, e.g., `are_friends`.

The claim form gives the assertion an author, a time, and provenance of its own; a direction the semantic reading may invert; any number of participants; and the citability that lets later claims summarise, qualify, or contradict it. 

The *semantic reading* of a graph inverts each `relation/*` edge's direction if `relation_direction = -1`. The *structural reading* is acyclic; the _semantic reading_ admits cycles (formalised in @sec:bijection).

== Ranke-Graph <sec:ranke-graph>

A *Ranke-Graph* (RG) is a set of claims forming a graph. An RG is _valid_ if every claim either has no references (making it an *initial claim*) or carries a `contribution/contributor` edge whose closure resolves to one or more initial claims (@sec:types).

== Universe <sec:universe>

$cal(U)$, the *Universe*, is a content-addressed key/value store: an envelope is stored under its id $k$ (retrieved as $cal(U)(k)$), and *externalised content* (@sec:content) under its hash $h = H(c)$ (as $cal(U)(h)$). Both keys are hashes over the bytes they name, so one keyspace serves both and identical bytes are one entry.
A *Ranke-Graph instance* $"RG"_k$, addressed by a head id $k$ (@sec:head), is a subset $"RG"_k subset.eq cal(U)$, and other archives may share the same $cal(U)$.

== Closures <sec:head>

Given $cal(U)$ and an id $k$, the instance $"RG"_k := "closure"(k, cal(U))$ is the transitive closure of claims reachable from the head claim $cal(U)(k)$ by following each edge to its reference. The id alone suffices to recover it.

== Branches <sec:branches>

A *branch* is a name resolving to a closure, anchored by its current head claim. A *branch table* is a `contribution/branches` claim whose `contribution/branch` edges name all contained branches, each referencing its current head. A revision need not restate them all: as a `contribution/diff` over the previous table (@sec:claims) it records only the changed entries, the full table being materialised by overlaying the diff chain back to the initial empty table (@sec:archive). All are stored in $cal(U)$; the id of the current branch table heads its archive (@sec:archive).

== Ranke-Archive <sec:archive>

A *Ranke-Archive* $"RA"_k$ is a Ranke-Graph $"RG"_k$ whose head $cal(U)(k)$ is a branch-table claim, with the previous branch tables in its provenance, the tuple $(cal(U), k)$ of the Universe and its head id $k$. From it all branches, their history, and all their graphs derive. Adding to the archive yields a new tuple $(cal(U)', k')$ with $cal(U) subset.eq cal(U)'$: the head id $k$ is not mutated but superseded, the earlier $"RA"_k$ remaining recoverable. Multiple archives can share $cal(U)$; each with its own head id.

A new archive is created by writing the initial claim and an empty `contribution/branches` claim, whose id is the archive's head $k$.

== Bookmarks <sec:bookmarks>

Each contribution to a Ranke-Archive advances $k arrow.r k'$. Without the latest $k$ the archive is unreachable: the DAG resolves only backwards, and a store that retrieves by key offers no enumeration to search. The locator for the moving head is a *bookmark*, a signed record (@sec:primitives) of three fields: the *bookmark seed* $s$, fixed once per list; its *index* $i$ in the list; and its *reference*, the head id $k$ it records. The signature proves the authorship of the bookmark's creator (@sec:authenticity).
$cal(U)_"hist"$, the *bookmark store*, holds all bookmarks under $op("id")_"seq"(i, s)$, sequentially addressed and possibly mutable. Every bookmark carries $s$, so the full list is reachable from any one of them.
A list is gapless: its present indices form one contiguous range. The latest entry is thus found in $O(log n)$ lookups: doubling from a known index until a miss, then binary search between the last hit and the first miss.

= Discharging the Desiderata <sec:emerges>

== Validity <sec:validity>

An $"RG"_k$ is *valid* when it satisfies the construction rules of @sec:ranke-graph. Every $"RG"_k$ produced via those rules is therefore valid by construction. An invalid graph (broken construction, missing initial claim, unresolved references) is structurally just an arbitrary graph $G$, not a Ranke-Graph.

== Consolidation <sec:consolidate>

When an RG has multiple open heads (after independent appends, scoping, or set operations), a single new head can consolidate them. Define
$ "consolidate"("RG") := "closure"(k_("new"), cal(U)) $
where $k_("new")$ is a new `contribution/head` claim with `contribution/head` edges to every currently-open head of RG, contributed by the operator. If RG already has a single open head, $"consolidate"("RG") = "RG"$.

An RG is *consolidated* when it already has a single head:
$ op("isConsolidated")("RG") <=> "RG" = "consolidate"("RG"). $

== Merkle DAG <sec:merkle>

Every valid $"RG"_k$ is a *Merkle DAG* (@bftcrdtmerkle, @ipfs): the atomic creation rule (@sec:claims) makes edges run from earlier claims to later ones, and identity $op("id")(v) = H(S("env"(v)))$ makes each claim's id recursive over the ids of every claim in its closure (@sec:primitives).

*Standing assumption.* The structure rests on *collision-resistance of $H$*: no two distinct byte sequences hash to the same value. Standard cryptographic hash functions (SHA-256, SHA-3, BLAKE3) are widely treated as collision-resistant in practice; mitigation is the implementer's choice of $H$.

Under this assumption, standard Merkle-DAG properties hold without further proof: the structure is acyclic; manipulation of any ancestor changes the descendant's id; identical claims produce identical ids. Later sections invoke these as established.

== Provenance <sec:provenance>

By the Merkle-DAG structure (@sec:merkle), reference traversal from any claim in $"RG"_k$ is acyclic and finite, terminating at an *initial claim* (@sec:ranke-graph) per path. Querying a node's provenance is therefore in $O(n)$.

Traversal terminates at *one or more* initial claims: a graph grown from a single contributor line resolves to one, while a graph that federates two merged archives (@sec:distributability) resolves to the initial claim of each, the multi-root case @sec:validity admits.

#dref[D1, this section]

== Immutability <sec:immutability>

Closure from $k$ is deterministic (@sec:head); under collision-resistance of $H$ (@sec:merkle), modifying $S(v)$ produces a different claim. With $cal(U)$'s content-addressed keys never changing once written (@sec:universe), recovery from $k$ yields the same $"RG"_k$ forever.

#dref[D2, this section]

== Idempotency <sec:idempotency>

By the Merkle-DAG structure, identical claims produce identical ids; under collision-resistance, identical ids imply identical claims. Writes are idempotent; deduplication is free.

#dref[D2, this section]

== Identity and Authenticity <sec:authenticity>

Every claim's envelope carries a signature over $S(v)$, made under the private key corresponding to the pubkey in $v$'s `contribution/contributor` (@sec:primitives). For the initial claim, the pubkey lives in $v$'s own content. Authenticity is structural: extract the pubkey, verify the envelope's signature against $S(v)$. Every contributor carries a pubkey, so every claim is signed.

The `contribution/contributor` edge names a claim's author and the signature proves that authorship. Key management and usage policies are application-layer patterns; the graph documents them as ordinary claims.

#dref[D3, this section]

== Anchoring <sec:anchoring>

Publishing $k$ to an RFC 3161 time-stamp authority (@rfc3161) witnesses $"closure"(k, cal(U))$ at the moment of publication. Combined with monotone $"created_at"$ (@sec:claims), two anchors at heads $k_1, k_2$ with publication times $t_1 < t_2$ bound every claim between them to the interval $[t_1, t_2]$ regardless of its self-reported timestamp.

Anchoring bounds `created_at`, the time the archive witnessed. 

#dref[D4, this section]

== Verifiability <sec:verifiability>

The Merkle-DAG id chain (@sec:merkle) witnesses *record integrity*: since $op("id")(v) = H(S("env"(v)))$, recomputing the hash over a stored record checks it against the id that names it. *Authenticity* is proved by checking the envelope's signature against the contributor's pubkey (@sec:authenticity). Each record's `content_hash` witnesses any external content bytes. Checking all three over the closure verifies the full Ranke-Graph.

#dref[D5, this section]

== Semantic Relations <sec:bijection>

A Ranke-Graph admits two readings of the same $V$ and $E$:

- *Structural reading*: edges run reference $arrow.r$ owner (older $arrow.r$ newer). Acyclic; Merkle-secured.
- *Semantic reading*: same $V$ and $E$, with `relation/*` edges directed by their `relation_direction`: `from` runs entity $arrow.r$ relation, `to` runs relation $arrow.r$ entity.

Provenance traversal (`derivation/*`, `contribution/*`) is identical in both. The structural reading is acyclic; the semantic admits cycles (e.g. _Alice knows Bob_, _Bob ignores Alice_).

#dref[D6, this section]

== Open-Ended Vocabulary <sec:vocabulary>

`class/*` is open vocabulary: applications add subtypes (`relation/family`, `source/conversation`, `derivation/transcription`, …) without modifying the ADT. Content schemas and extension fields are likewise application-defined; tools pass through what they do not recognise.

#dref[D7, this section]

== Scoping <sec:scoping>

Scoping selects a sub-RG of $"RG"_k$ via an indicator $sigma : "RG"_k -> {0, 1}$. A claim $v$ is in scope when $sigma(v) = 1$ and every claim $v$ references is in scope; σ propagates through the closure. This produces a valid, consolidated subgraph of $"RG"_k$, for example claims derived from one contributor's contributions, or claims related to one project.

The in-scope claims form a set closed under references; consolidate them (@sec:consolidate) into $"RG"_(k_s)$. The result is a valid Ranke-Graph (@sec:validity): every reference path reaches an initial claim, full provenance. Incremental updates are cheap: apply $sigma$ to claims appended to the main line _after_ the timestamp of $"RG"_(k_s)$, merge with the previous selection, create a new head.

== Set Algebra <sec:set-algebra>

Two set operations over RG node-id sets produce valid sub-RGs by virtue of content-determined ids (@sec:merkle): matching ids ARE the same claim, so set membership is well-defined and decidable by hash equality.

=== Union ($A union B$) <sec:union>

Every claim in either RG. Both inputs are closed under references, so the union is closed. Consolidate (@sec:consolidate) → valid sub-RG. 

=== Intersection ($A inter B$) <sec:intersection>

Claims in both RGs. Both inputs are valid (@sec:validity), so each contains every claim's full provenance. If $v in A inter B$, $v$'s provenance is in both $A$ and $B$ (hence in $A inter B$), so the intersection is closed under references. No removed claim can be a provenance ancestor of a claim that stays. Consolidate (@sec:consolidate) → valid sub-RG.

== Distributability <sec:distributability>

Two replicas of a Ranke-Archive converge by union (@sec:set-algebra), the join-semilattice condition for Conflict-Free Replicated Data Types (CRDTs, @shapiro2011crdt). Replicas can write independently and reconcile by exchanging claim ids; every replica reaches the same state regardless of partition order.

#dref[D8, this section]

= Additional Emergent Properties <sec:emergent>

Properties that follow from the structure beyond the desiderata.

== Forks <sec:forks>

*Emerges from @sec:branches.* Forking is a new branch entry pointing at $k$ ($O(1)$).

== Backup <sec:hash-backup>

*Emerges from @sec:merkle + @sec:verifiability.* A single head id $k$ recovers and verifies $"RG"_k$ from any replica of $cal(U)$. One bookmark id (@sec:bookmarks) recovers the latest recorded head, and through the archive's provenance every state before it.

== Composing the Universe <sec:composable>

*Emerges from @sec:universe + @sec:merkle.* Because $cal(U)$'s keys are fixed independent of storage location, its physical form is free. Entries may be layered across storage backends, partitioned among them, or replicated many times, and any $"RG"_k$ still resolves against whatever composition holds its closure; id and closure stay fixed regardless of where the bytes live. The same freedom covers $cal(U)_"hist"$ (@sec:bookmarks): both stores key by fixed-size hashes, so one physical store can hold both,#footnote[One key can serve both stores at once: external content whose bytes equal $S([i, s])$ is stored at $H(c) = op("id")_"seq"(i, s)$, a bookmark's slot. Writing such bytes requires knowing $s$; a composition that separates the two keyspaces by a prefix rules the case out.] and since an advance appends at the next free index, an append-only store suffices.

= Relation to Prior Work <sec:related-work>

== Temporal Knowledge Graphs: Graphiti / Zep

Graphiti (@rasmussen2025graphiti; @zep2025temporal, 2024–2025) is the closest existing system to the Ranke-Graph in the LLM context-management field.
It builds temporal, provenance-aware knowledge graphs using FalkorDB or Neo4j, with bidirectional episode indices and temporal validity windows.
Facts are invalidated rather than deleted.

However, Graphiti performs destructive entity-summary updates, has no content-addressable source archive comparable to the Ranke-Graph, and embeds provenance as annotation on the knowledge graph rather than treating it as the content itself.
The Ranke-Graph can be understood as an extension of Graphiti's philosophy, adding immutability, sources preserved within the graph itself, and the architectural inversion that makes provenance the substrate rather than an annotation.

== Versioned Knowledge Bases: TerminusDB

TerminusDB (@terminusdb) provides Git-like versioning (branch, merge, time-travel) over an RDF knowledge graph using append-only delta encoding.
It captures _what_ changed across versions but not _why_: no derivation chain, no source archive, no concept of contributors as provenance-tracked agents.
Its foundational structure is a versioned graph, not a provenance DAG.

== Immutable Databases: Datomic and Fluree

Datomic (@hickey2012datomic) implements Pat Helland's 'Immutability Changes Everything' thesis (@helland2015immutability) as an append-only database of immutable datoms.
Fluree (@fluree) combines an append-only ledger with a semantic graph database.
Both capture temporal history but not _epistemic_ history: they record _when_ facts changed but not _how knowledge was derived from sources through processing chains_.

== Merkle Structures and Content Addressing

Merkle trees, content-addressed stores such as IPFS (@ipfs), and Trusty URIs (@kuhn2014trustyuris) all hash-address immutable content, so a name verifies what it names. The Ranke-Graph rests on this foundation but generalises its shape. A Merkle tree hashes a tree of content blobs and IPFS a DAG of storage chunks; in the Ranke-Graph the Merkle links _are_ the provenance edges (@sec:merkle). The hash-linked structure is therefore not a storage detail beneath the data but carries the derivation itself: each id commits to the full closure of claims a record was built from, so content addressing and provenance coincide rather than sit in separate layers (@bftcrdtmerkle).

== Signature and Timestamping Infrastructure

Identity in the Ranke-Graph is a hash over a signed record (@sec:primitives), and its temporal guarantees rest on external anchoring (@sec:anchoring); both draw on established infrastructure rather than new primitives. Signature-based identity systems, PGP's web of trust and more recently Sigstore (@newman2022sigstore), bind keys to identities and sign artifacts, but treat the signature as a detached attestation _about_ content; the Ranke-Graph instead folds the signature into the record its address names, so a claim's address commits to its author as well as to its content. The envelope is standard practice: a C2PA claim signature (@c2pa) and an IETF SCITT signed statement (@scitt) are each a COSE_Sign1 (@rfc9052). For time, hash-chain timestamping (@haber1991), RFC 3161 time-stamp authorities (@rfc3161), and ledger anchoring (@gipp2015) witness that data existed at a moment; the Ranke-Graph adopts these directly for anchoring rather than reinventing them. Merkle-tree signing and transparency logs such as Certificate Transparency (@rfc6962) share its use of hash-linked structure for tamper-evidence, but over append-only logs of certificates rather than a provenance DAG of derivations. The contribution here is again composition, not a new mechanism: the hash _is_ the address, the signature it covers _is_ the proof, and a single anchor fixes the whole closure in time.

== W3C PROV-DM

The W3C PROV Data Model (@moreau2013provdm) provides a formal vocabulary for provenance (Entity, Activity, Agent, wasGeneratedBy, wasDerivedFrom, used).
The Ranke-Graph is semantically compatible with PROV-DM (nodes map to Entities, contributor activities to Activities, contributors to Agents), but does not depend on or implement the W3C stack (RDF, SPARQL, OWL).
PROV-DM compatibility exists at the conceptual level, allowing export or interoperability without architectural coupling.

== Nanopublications

Nanopublications (@kuhn2014trustyuris; @nanopubs2025knowledgeprov) are immutable, content-addressable scholarly assertions with embedded provenance.
They share the Ranke-Graph's commitment to immutability and provenance-per-assertion but are a flat collection of independent assertions: they do not form a derivation DAG connecting assertions through chains of processing, and they do not support a semantic graph layer.

== CRDTs and Distributed Provenance

An append-only, monotonically growing DAG is a Conflict-Free Replicated Data Type (@shapiro2011crdt): its merge is set union, which is associative, commutative, and idempotent, so replicas converge to the same state regardless of the order or grouping in which they exchange claims (@sec:distributability). CRDTs are well studied for registers, counters, and sequences; their realisation as a provenance DAG, where content-addressed ids make union deduplicating by construction, appears little explored. Coordination-free replication then follows: no merge resolver is needed, because identical claims carry identical ids and distinct claims never collide.

== The Identified Gap

No existing system combines all of: (a) a content-addressable immutable source archive, (b) an append-only Provenance DAG as the primary data structure, (c) a semantic graph as a materialised view with per-edge provenance, (d) CRDT-compatible merge of independent replicas, and (e) natural-language relations with emergent ontology.
Each component has mature prior art; the architectural composition is novel.

= Conclusion

We began with three statements and chose the third: to record not that Alice likes apples, but that a file exists claiming she does. That narrowing (observations of existence, not facts about the world) is what makes everything here keepable.

The structural form we present is not new. Centuries of archival practice have refined it under conditions of uncertainty, contradiction, and revision. What is new is its full realisation in the digital substrate.

The computer science tools used here are all established: Merkle trees from 1979, hashchain timestamping from Haber and Stornetta 1991, RFC 3161 from 2001, Ed25519 from 2011. The discipline they serve is older still. We invent nothing; we compose.

One line draws the boundary of that composition: _the Ranke-Graph documents; it does not decide._ Signatures document who signed, not who may sign; validity documents structural well-formedness, not what is true. Everything that would _decide_ (policy, governance, consensus, which claims must reach which views) belongs above the ADT, in the systems built upon it.

Reference implementations of the ADT in Go (@rankego) and TypeScript (@rankets) accompany this paper. A binary conformance suite of example graphs and operations with expected hashes is published with this paper, so conformance to the ADT is decidable for any implementation.

= Type Vocabulary <sec:types>

The five concepts of @sec:everything-is-knowledge are encoded as five node classes and three edge classes; subtype vocabulary is open.

*Node classes:*

- *`source/*`*: an external data artifact.
- *`derivation/*`*: a claim built from other claims as inputs.
- *`entity/*`*: an identifiable thing in the world.
- *`relation/*`*: a node representing a relation among entities.
- *`contribution/*`*: a claim about contributors or their actions on the RG.
- *`contribution/contributor`*: an actor that adds claims, carrying the `pubkey` its claims are signed under (see @sec:primitives)
- *`contribution/head`*: consolidates currently-open content claims (see @sec:head)
- *`contribution/branches`*: a branch-table claim indexing the archive's branches (see @sec:branches)
- *`contribution/expiry`*: a claim that carries nothing but an expiry against a contributor's key
- *`contribution/delete`*: a claim documenting that a referenced claim's bytes were physically removed

*Edge classes:*

- *`derivation/*`*: provenance edges that cite the inputs a claim was derived from.
- *`relation/*`*: relation edges of a relation node (carry `relation_direction`).
- *`contribution/*`*: edges referencing a contribution that shaped the owning claim. The ADT defines seven subtypes:
  - *`contribution/contributor`*: names the contributor of a claim
  - *`contribution/head`*: consolidates currently-open content claims (see @sec:head)
  - *`contribution/branch`*: edge-only; from a branch table, names one active branch in a `name` field and references its current head (see @sec:branches)
  - *`contribution/branches`*: points at the previous branch table where a revision restates every entry instead of diffing over it (see @sec:branches)
  - *`contribution/diff`*: points at a claim the owning claim overlays, restating only the delta; the full claim is materialised by applying the diff chain, a storage optimisation carrying full provenance
  - *`contribution/delete`*: points at a claim whose bytes were physically removed, documenting the gap
  - *`contribution/expiry`*: points at a contributor claim, naming the last time its key is valid; it expires after that time

== Encoding Aliases <sec:aliases>

To optimise the encoding $S$ (@sec:primitives) for size, we allow aliases for the predefined field names and types. An alias carries a leading `.`, marking the reserved namespace: a field name, a type class, a type subtype, and an encoding class or subtype each abbreviate to the dot and one character (`content_size` → `.s`, `contribution` → `.c`, `contributor` → `.c`). Class and subtype are each carried in their own field, so `contribution/contributor` serializes as the pair `.c`, `.c`. The full table is fixed in the normative specification (@rankespec).
An alias is semantically identical to its long form; the reference implementation applies aliases automatically and presents the long form through a common interface.

#v(1em)
#text(size: 0.92em)[*Acknowledgements.* This paper was prepared with the assistance of AI tools (Claude Opus 4.6–4.8, Anthropic).]

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
