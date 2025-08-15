;; Seed2Sale: Autonomous Agriculture Supply Chain Management Protocol
;; Implements comprehensive crop lifecycle tracking, quality assurance, and ecosystem participant governance

;; Protocol Constants
(define-constant protocol-sovereign tx-sender)
(define-constant ERROR-UNAUTHORIZED-ENTITY (err u1))
(define-constant ERROR-HARVEST-NOT-FOUND (err u2))
(define-constant ERROR-INVALID-LIFECYCLE-TRANSITION (err u3))
(define-constant ERROR-DUPLICATE-HARVEST-REGISTRY (err u4))
(define-constant ERROR-MALFORMED-INPUT (err u5))

;; Protocol Configuration
(define-data-var minimum-excellence-threshold uint u60)

;; Ecosystem Participant Registry
(define-map ecosystem-participants
    principal
    {
        entity-classification: (string-ascii 20),
        operational-status: bool,
        reputation-index: uint
    }
)

;; Harvest Asset Registry
(define-map harvest-manifest
    uint  ;; harvest-identifier
    {
        commodity-designation: (string-ascii 50),
        genesis-cultivator: principal,
        current-custodian: principal,
        lifecycle-stage: (string-ascii 20),
        excellence-rating: uint,
        genesis-block: uint,
        geographical-coordinates: (string-ascii 100),
        market-valuation: uint,
        quality-certification: bool
    }
)

;; Provenance Chain Registry
(define-map provenance-ledger
    {harvest-identifier: uint, ledger-entry-id: uint}
    {
        origin-entity: principal,
        destination-entity: principal,
        interaction-type: (string-ascii 20),
        timestamp-block: uint,
        metadata-payload: (string-ascii 200)
    }
)

;; Ledger Entry Sequence Generator
(define-data-var ledger-sequence-counter uint u0)

;; Query Interface Functions
(define-read-only (retrieve-harvest-metadata (harvest-identifier uint))
    (map-get? harvest-manifest harvest-identifier)
)

(define-read-only (retrieve-participant-profile (entity-address principal))
    (map-get? ecosystem-participants entity-address)
)

(define-read-only (retrieve-provenance-entry (harvest-identifier uint) (ledger-entry-id uint))
    (map-get? provenance-ledger {harvest-identifier: harvest-identifier, ledger-entry-id: ledger-entry-id})
)

;; Internal Validation Mechanisms
(define-private (verify-ecosystem-participation (entity-address principal))
    (let ((participant-profile (unwrap! (map-get? ecosystem-participants entity-address) false)))
        (get operational-status participant-profile)
    )
)

(define-private (generate-next-ledger-id)
    (begin
        (var-set ledger-sequence-counter (+ (var-get ledger-sequence-counter) u1))
        (var-get ledger-sequence-counter)
    )
)

;; Input Sanitization Framework
(define-private (validate-compact-string (input-data (string-ascii 20)))
    (and (>= (len input-data) u1) (<= (len input-data) u20))
)

(define-private (validate-standard-string (input-data (string-ascii 50)))
    (and (>= (len input-data) u1) (<= (len input-data) u50))
)

(define-private (validate-extended-string (input-data (string-ascii 100)))
    (and (>= (len input-data) u1) (<= (len input-data) u100))
)

(define-private (validate-verbose-string (input-data (string-ascii 200)))
    (and (>= (len input-data) u1) (<= (len input-data) u200))
)

(define-private (validate-numeric-input (input-value uint))
    (< input-value u340282366920938463463374607431768211455)  ;; Maximum uint boundary
)

;; Protocol Governance Functions
(define-public (onboard-ecosystem-participant (entity-address principal) (entity-classification (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender protocol-sovereign) ERROR-UNAUTHORIZED-ENTITY)
        (asserts! (is-none (map-get? ecosystem-participants entity-address)) ERROR-DUPLICATE-HARVEST-REGISTRY)
        (asserts! (validate-compact-string entity-classification) ERROR-MALFORMED-INPUT)
        (ok (map-set ecosystem-participants 
            entity-address
            {
                entity-classification: entity-classification,
                operational-status: true,
                reputation-index: u100
            }
        ))
    )
)

(define-public (modify-participant-status (entity-address principal) (active-status bool))
    (begin
        (asserts! (is-eq tx-sender protocol-sovereign) ERROR-UNAUTHORIZED-ENTITY)
        (asserts! (is-some (map-get? ecosystem-participants entity-address)) ERROR-UNAUTHORIZED-ENTITY)
        (ok (map-set ecosystem-participants 
            entity-address
            (merge (unwrap-panic (map-get? ecosystem-participants entity-address))
                  {operational-status: active-status})
        ))
    )
)

;; Harvest Lifecycle Management
(define-public (initialize-harvest-registry 
    (harvest-identifier uint)
    (commodity-designation (string-ascii 50))
    (geographical-coordinates (string-ascii 100))
    (market-valuation uint))
    (let ((registering-cultivator tx-sender))
        (begin
            (asserts! (verify-ecosystem-participation registering-cultivator) ERROR-UNAUTHORIZED-ENTITY)
            (asserts! (is-none (map-get? harvest-manifest harvest-identifier)) ERROR-DUPLICATE-HARVEST-REGISTRY)
            (asserts! (validate-numeric-input harvest-identifier) ERROR-MALFORMED-INPUT)
            (asserts! (validate-standard-string commodity-designation) ERROR-MALFORMED-INPUT)
            (asserts! (validate-extended-string geographical-coordinates) ERROR-MALFORMED-INPUT)
            (asserts! (validate-numeric-input market-valuation) ERROR-MALFORMED-INPUT)
            (ok (map-set harvest-manifest
                harvest-identifier
                {
                    commodity-designation: commodity-designation,
                    genesis-cultivator: registering-cultivator,
                    current-custodian: registering-cultivator,
                    lifecycle-stage: "genesis",
                    excellence-rating: u100,
                    genesis-block: block-height,
                    geographical-coordinates: geographical-coordinates,
                    market-valuation: market-valuation,
                    quality-certification: false
                }
            ))
        )
    )
)

(define-public (advance-lifecycle-stage 
    (harvest-identifier uint)
    (next-stage (string-ascii 20))
    (stage-annotations (string-ascii 200)))
    (let (
        (stage-coordinator tx-sender)
        (harvest-metadata (unwrap! (map-get? harvest-manifest harvest-identifier) ERROR-HARVEST-NOT-FOUND))
        )
        (begin
            (asserts! (verify-ecosystem-participation stage-coordinator) ERROR-UNAUTHORIZED-ENTITY)
            (asserts! (is-eq (get current-custodian harvest-metadata) stage-coordinator) ERROR-UNAUTHORIZED-ENTITY)
            (asserts! (validate-numeric-input harvest-identifier) ERROR-MALFORMED-INPUT)
            (asserts! (validate-compact-string next-stage) ERROR-MALFORMED-INPUT)
            (asserts! (validate-verbose-string stage-annotations) ERROR-MALFORMED-INPUT)
            (map-set harvest-manifest
                harvest-identifier
                (merge harvest-metadata {lifecycle-stage: next-stage})
            )
            (map-set provenance-ledger
                {harvest-identifier: harvest-identifier, ledger-entry-id: (generate-next-ledger-id)}
                {
                    origin-entity: stage-coordinator,
                    destination-entity: stage-coordinator,
                    interaction-type: next-stage,
                    timestamp-block: block-height,
                    metadata-payload: stage-annotations
                }
            )
            (ok true)
        )
    )
)

(define-public (execute-custodial-transfer
    (harvest-identifier uint)
    (successor-custodian principal)
    (transfer-metadata (string-ascii 200)))
    (let (
        (current-custodian tx-sender)
        (harvest-metadata (unwrap! (map-get? harvest-manifest harvest-identifier) ERROR-HARVEST-NOT-FOUND))
        )
        (begin
            (asserts! (verify-ecosystem-participation current-custodian) ERROR-UNAUTHORIZED-ENTITY)
            (asserts! (verify-ecosystem-participation successor-custodian) ERROR-UNAUTHORIZED-ENTITY)
            (asserts! (is-eq (get current-custodian harvest-metadata) current-custodian) ERROR-UNAUTHORIZED-ENTITY)
            (asserts! (validate-numeric-input harvest-identifier) ERROR-MALFORMED-INPUT)
            (asserts! (validate-verbose-string transfer-metadata) ERROR-MALFORMED-INPUT)
            (map-set harvest-manifest
                harvest-identifier
                (merge harvest-metadata {
                    current-custodian: successor-custodian,
                    lifecycle-stage: "custody-transferred"
                })
            )
            (map-set provenance-ledger
                {harvest-identifier: harvest-identifier, ledger-entry-id: (generate-next-ledger-id)}
                {
                    origin-entity: current-custodian,
                    destination-entity: successor-custodian,
                    interaction-type: "custodial-transfer",
                    timestamp-block: block-height,
                    metadata-payload: transfer-metadata
                }
            )
            (ok true)
        )
    )
)

(define-public (certify-excellence-rating
    (harvest-identifier uint)
    (excellence-score uint)
    (certification-notes (string-ascii 200)))
    (let (
        (quality-auditor tx-sender)
        (harvest-metadata (unwrap! (map-get? harvest-manifest harvest-identifier) ERROR-HARVEST-NOT-FOUND))
        )
        (begin
            (asserts! (verify-ecosystem-participation quality-auditor) ERROR-UNAUTHORIZED-ENTITY)
            (asserts! (validate-numeric-input harvest-identifier) ERROR-MALFORMED-INPUT)
            (asserts! (<= excellence-score u100) ERROR-MALFORMED-INPUT)
            (asserts! (validate-verbose-string certification-notes) ERROR-MALFORMED-INPUT)
            (map-set harvest-manifest
                harvest-identifier
                (merge harvest-metadata {
                    excellence-rating: excellence-score,
                    quality-certification: (>= excellence-score (var-get minimum-excellence-threshold))
                })
            )
            (map-set provenance-ledger
                {harvest-identifier: harvest-identifier, ledger-entry-id: (generate-next-ledger-id)}
                {
                    origin-entity: quality-auditor,
                    destination-entity: quality-auditor,
                    interaction-type: "excellence-audit",
                    timestamp-block: block-height,
                    metadata-payload: certification-notes
                }
            )
            (ok true)
        )
    )
)

(define-public (update-geographical-coordinates
    (harvest-identifier uint)
    (updated-coordinates (string-ascii 100))
    (location-metadata (string-ascii 200)))
    (let (
        (location-coordinator tx-sender)
        (harvest-metadata (unwrap! (map-get? harvest-manifest harvest-identifier) ERROR-HARVEST-NOT-FOUND))
        )
        (begin
            (asserts! (verify-ecosystem-participation location-coordinator) ERROR-UNAUTHORIZED-ENTITY)
            (asserts! (is-eq (get current-custodian harvest-metadata) location-coordinator) ERROR-UNAUTHORIZED-ENTITY)
            (asserts! (validate-numeric-input harvest-identifier) ERROR-MALFORMED-INPUT)
            (asserts! (validate-extended-string updated-coordinates) ERROR-MALFORMED-INPUT)
            (asserts! (validate-verbose-string location-metadata) ERROR-MALFORMED-INPUT)
            (map-set harvest-manifest
                harvest-identifier
                (merge harvest-metadata {geographical-coordinates: updated-coordinates})
            )
            (map-set provenance-ledger
                {harvest-identifier: harvest-identifier, ledger-entry-id: (generate-next-ledger-id)}
                {
                    origin-entity: location-coordinator,
                    destination-entity: location-coordinator,
                    interaction-type: "geolocation-update",
                    timestamp-block: block-height,
                    metadata-payload: location-metadata
                }
            )
            (ok true)
        )
    )
)