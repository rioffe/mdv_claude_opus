# Diagrams

A flowchart with two subgraphs claiming `PD` (E-01), a sequence with `<br>` labels and autonumber, math in a node, and an unsupported type that falls back (E-02).

```mermaid
flowchart TD
  subgraph X
    A --> PD
  end
  subgraph Y
    PD --> B
  end
```

```mermaid
sequenceDiagram
  autonumber
  participant A as Alice<br>Wonderland
  participant B as Bob
  A->>B: single line
  B->>A: first line<br>second line<br>third line
  loop retries
    A->>B: quick
    Note over B: final note<br>with two lines
  end
```

```mermaid
flowchart LR
  A["$$E = mc^2$$"] -->|"$\alpha$ edge"| B["mixed $\pi$ text"]
```

```mermaid
timeline
  title History
  2020 : one
```

Prose after the diagrams.
