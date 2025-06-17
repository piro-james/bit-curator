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