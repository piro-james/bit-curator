;; BitCurator Protocol - Decentralized Content Curation & Reputation System
;; 
;; Title: BitCurator - Community-Driven Content Discovery Platform
;; 
;; Summary: A decentralized content curation protocol that leverages community wisdom 
;; to discover, rank, and reward high-quality content across multiple categories while 
;; building participant reputation through transparent voting mechanisms.
;;
;; Description: BitCurator transforms content discovery by creating a trustless, 
;; community-governed platform where users submit, evaluate, and reward valuable content.
;; The protocol implements a sophisticated reputation system that rewards quality 
;; contributors while enabling community-driven moderation. Built on Stacks for Bitcoin's
;; security with STX-powered incentive mechanisms, BitCurator creates a sustainable 
;; ecosystem where quality content rises to the top through collective intelligence.
;;
;; Key Features:
;; - Decentralized content submission and curation
;; - Reputation-based voting system with stake-weighted influence  
;; - Direct creator monetization through community rewards
;; - Multi-category content organization
;; - Community-driven content moderation
;; - Bitcoin-secured, transparent governance

;; CORE CONSTANTS & CONFIGURATION

(define-constant PROTOCOL_ADMINISTRATOR tx-sender)

;; Error Code Definitions
(define-constant ERR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERR_INVALID_SUBMISSION (err u101))
(define-constant ERR_DUPLICATE_ENTRY (err u102))
(define-constant ERR_NONEXISTENT_ITEM (err u103))
(define-constant ERR_INADEQUATE_BALANCE (err u104))
(define-constant ERR_INVALID_TOPIC (err u105))
(define-constant ERR_INVALID_FLAG (err u106))
(define-constant ERR_OVERFLOW (err u107))
(define-constant ERR_INVALID_APPRAISAL (err u108))
(define-constant ERR_INVALID_ITEM_ID (err u109))

;; Protocol Configuration Parameters
(define-constant MIN_HYPERLINK_LENGTH u10)
(define-constant MAX_UINT u340282366920938463463374607431768211455)

;; STATE VARIABLES

(define-data-var submission-charge uint u10)
(define-data-var aggregate-submissions uint u0)
(define-data-var content-topics (list 10 (string-ascii 20)) 
  (list "Technology" "Science" "Art" "Politics" "Sports"))

;; DATA STORAGE MAPS

;; Primary content storage with comprehensive metadata
(define-map curated-items 
  { item-identifier: uint } 
  { 
    originator: principal, 
    headline: (string-ascii 100), 
    hyperlink: (string-ascii 200), 
    topic: (string-ascii 20),
    publication-epoch: uint, 
    appraisals: int,
    gratuities: uint,
    flags: uint
  }
)

;; Track individual user votes on content items
(define-map participant-appraisals 
  { participant: principal, item-identifier: uint } 
  { appraisal: int }
)

;; Community reputation tracking system
(define-map participant-credibility
  { participant: principal }
  { metric: int }
)

;; PRIVATE HELPER FUNCTIONS

;; Verify if content item exists in the curation database
(define-private (item-exists (item-identifier uint))
  (is-some (map-get? curated-items { item-identifier: item-identifier }))
)

;; Filter function for retrieving valid content items
(define-private (not-none (item (optional {
    originator: principal, 
    headline: (string-ascii 100), 
    hyperlink: (string-ascii 200), 
    topic: (string-ascii 20),
    publication-epoch: uint, 
    appraisals: int,
    gratuities: uint,
    flags: uint
  })))
  (is-some item)
)

;; Retrieve content only if it meets quality threshold (non-negative appraisals)
(define-private (retrieve-item-if-valid (id uint))
  (match (map-get? curated-items { item-identifier: id })
    item (if (>= (get appraisals item) 0) (some item) none)
    none
  )
)

;; Generate sequential number list for pagination (max 10 items)
(define-private (enumerate (n uint))
  (let ((limit (if (> n u10) u10 n)))
    (list
      (if (>= limit u1) u1 u0)
      (if (>= limit u2) u2 u0)
      (if (>= limit u3) u3 u0)
      (if (>= limit u4) u4 u0)
      (if (>= limit u5) u5 u0)
      (if (>= limit u6) u6 u0)
      (if (>= limit u7) u7 u0)
      (if (>= limit u8) u8 u0)
      (if (>= limit u9) u9 u0)
      (if (>= limit u10) u10 u0)
    )
  )
)

;; Filter out zero values from enumerated lists
(define-private (is-non-zero (n uint))
  (not (is-eq n u0))
)

;; PUBLIC CONTENT CURATION FUNCTIONS

;; Submit new content for community evaluation and curation
(define-public (contribute-item (headline (string-ascii 100)) (hyperlink (string-ascii 200)) (topic (string-ascii 20)))
  (let
    (
      (item-identifier (+ (var-get aggregate-submissions) u1))
    )
    ;; Validate submission parameters
    (asserts! (and 
                (>= (len headline) u1)
                (>= (len hyperlink) MIN_HYPERLINK_LENGTH)
                (>= (len topic) u1)
              ) ERR_INVALID_SUBMISSION)
    
    ;; Check for overflow protection
    (asserts! (> item-identifier (var-get aggregate-submissions)) ERR_OVERFLOW)
    
    ;; Validate topic exists in approved categories
    (asserts! (is-some (index-of (var-get content-topics) topic)) ERR_INVALID_TOPIC)
    
    ;; Verify user can afford submission fee
    (asserts! (>= (stx-get-balance tx-sender) (var-get submission-charge)) ERR_INADEQUATE_BALANCE)
    
    ;; Process submission fee payment
    (try! (stx-transfer? (var-get submission-charge) tx-sender PROTOCOL_ADMINISTRATOR))
    
    ;; Store content item with metadata
    (map-set curated-items
      { item-identifier: item-identifier }
      {
        originator: tx-sender,
        headline: headline,
        hyperlink: hyperlink,
        topic: topic,
        publication-epoch: stacks-block-height,
        appraisals: 0,
        gratuities: u0,
        flags: u0
      }
    )
    
    ;; Update submission counter
    (var-set aggregate-submissions item-identifier)
    
    ;; Emit event for indexing
    (print { type: "new-item", item-identifier: item-identifier, originator: tx-sender })
    (ok item-identifier)
  )
)

;; Community voting mechanism with reputation impact
(define-public (appraise-item (item-identifier uint) (appraisal int))
  (let
    (
      (previous-appraisal (default-to 0 (get appraisal (map-get? participant-appraisals { participant: tx-sender, item-identifier: item-identifier }))))
      (target-item (unwrap! (map-get? curated-items { item-identifier: item-identifier }) ERR_NONEXISTENT_ITEM))
      (appraiser-standing (default-to { metric: 0 } (map-get? participant-credibility { participant: tx-sender })))
    )
    ;; Validate item exists
    (asserts! (item-exists item-identifier) ERR_NONEXISTENT_ITEM)
    
    ;; Validate appraisal value (only +1 or -1 allowed)
    (asserts! (or (is-eq appraisal 1) (is-eq appraisal -1)) ERR_INVALID_APPRAISAL)
    
    ;; Record user's vote
    (map-set participant-appraisals
      { participant: tx-sender, item-identifier: item-identifier }
      { appraisal: appraisal }
    )
    
    ;; Update content item's total appraisal score
    (map-set curated-items
      { item-identifier: item-identifier }
      (merge target-item { appraisals: (+ (get appraisals target-item) (- appraisal previous-appraisal)) })
    )
    
    ;; Update user's reputation based on participation
    (map-set participant-credibility
      { participant: tx-sender }
      { metric: (+ (get metric appraiser-standing) appraisal) }
    )
    
    ;; Emit appraisal event
    (print { type: "appraisal", item-identifier: item-identifier, appraiser: tx-sender, appraisal: appraisal })
    (ok true)
  )
)

;; Direct creator monetization through community rewards
(define-public (reward-originator (item-identifier uint) (gratuity-amount uint))
  (let
    (
      (target-item (unwrap! (map-get? curated-items { item-identifier: item-identifier }) ERR_NONEXISTENT_ITEM))
    )
    ;; Validate item exists
    (asserts! (item-exists item-identifier) ERR_NONEXISTENT_ITEM)
    
    ;; Verify sender has sufficient balance
    (asserts! (>= (stx-get-balance tx-sender) gratuity-amount) ERR_INADEQUATE_BALANCE)
    
    ;; Update gratuity counter before transfer (security best practice)
    (map-set curated-items
      { item-identifier: item-identifier }
      (merge target-item { gratuities: (+ (get gratuities target-item) gratuity-amount) })
    )
    
    ;; Execute STX transfer to content creator
    (try! (stx-transfer? gratuity-amount tx-sender (get originator target-item)))
    
    ;; Emit reward event
    (print { type: "reward", item-identifier: item-identifier, from: tx-sender, to: (get originator target-item), amount: gratuity-amount })
    (ok true)
  )
)

;; Community-driven content moderation system
(define-public (flag-item (item-identifier uint))
  (let
    (
      (target-item (unwrap! (map-get? curated-items { item-identifier: item-identifier }) ERR_NONEXISTENT_ITEM))
    )
    ;; Validate item exists
    (asserts! (item-exists item-identifier) ERR_NONEXISTENT_ITEM)
    
    ;; Prevent self-flagging
    (asserts! (not (is-eq (get originator target-item) tx-sender)) ERR_INVALID_FLAG)
    
    ;; Increment flag counter
    (map-set curated-items
      { item-identifier: item-identifier }
      (merge target-item { flags: (+ (get flags target-item) u1) })
    )
    
    ;; Emit flag event
    (print { type: "flag", item-identifier: item-identifier, flagger: tx-sender })
    (ok true)
  )
)

;; READ-ONLY QUERY FUNCTIONS

;; Retrieve complete content item metadata
(define-read-only (retrieve-item-details (item-identifier uint))
  (map-get? curated-items { item-identifier: item-identifier })
)

;; Get user's vote on specific content
(define-read-only (retrieve-participant-appraisal (participant principal) (item-identifier uint))
  (get appraisal (map-get? participant-appraisals { participant: participant, item-identifier: item-identifier }))
)

;; Get total content submissions in the system
(define-read-only (retrieve-aggregate-submissions)
  (var-get aggregate-submissions)
)

;; Retrieve user's reputation score
(define-read-only (retrieve-participant-credibility (participant principal))
  (default-to { metric: 0 } (map-get? participant-credibility { participant: participant }))
)

;; Generate list of valid item IDs for pagination
(define-read-only (get-item-ids (count uint))
  (filter is-non-zero (enumerate count))
)

;; Retrieve top-quality content based on community appraisals
(define-read-only (retrieve-top-items (limit uint))
  (let
    (
      (item-count (var-get aggregate-submissions))
      (actual-limit (if (> limit item-count) item-count limit))
    )
    (filter not-none
      (map retrieve-item-if-valid (get-item-ids actual-limit))
    )
  )
)

;; ADMINISTRATIVE FUNCTIONS

;; Protocol fee adjustment mechanism
(define-public (adjust-submission-charge (new-charge uint))
  (begin
    (asserts! (is-eq tx-sender PROTOCOL_ADMINISTRATOR) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (<= new-charge MAX_UINT) ERR_OVERFLOW)
    (var-set submission-charge new-charge)
    (print { type: "fee-change", new-charge: new-charge })
    (ok true)
  )
)

;; Emergency content removal for policy violations
(define-public (expunge-item (item-identifier uint))
  (begin
    (asserts! (is-eq tx-sender PROTOCOL_ADMINISTRATOR) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (item-exists item-identifier) ERR_NONEXISTENT_ITEM)
    (map-delete curated-items { item-identifier: item-identifier })
    (print { type: "item-expunged", item-identifier: item-identifier })
    (ok true)
  )
)

;; Expand content categorization system
(define-public (introduce-topic (new-topic (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender PROTOCOL_ADMINISTRATOR) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (< (len (var-get content-topics)) u10) ERR_INVALID_TOPIC)
    (asserts! (>= (len new-topic) u1) ERR_INVALID_TOPIC)
    (var-set content-topics (unwrap-panic (as-max-len? (append (var-get content-topics) new-topic) u10)))
    (print { type: "new-topic", topic: new-topic })
    (ok true)
  )
)