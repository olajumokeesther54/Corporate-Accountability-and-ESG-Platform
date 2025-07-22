;; Corporate Lobbying Disclosure Contract
;; Tracks corporate political influence and lobbying expenditures

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-COMPANY-NOT-FOUND (err u501))
(define-constant ERR-INVALID-INPUT (err u502))
(define-constant ERR-EXPENDITURE-NOT-FOUND (err u503))
(define-constant ERR-ALREADY-REPORTED (err u504))

;; Data Variables
(define-data-var next-company-id uint u1)
(define-data-var next-expenditure-id uint u1)
(define-data-var next-contact-id uint u1)

;; Data Maps
(define-map companies
  { company-id: uint }
  {
    name: (string-ascii 100),
    admin: principal,
    total-lobbying-spend: uint,
    total-political-donations: uint,
    pac-contributions: uint,
    transparency-score: uint,
    active: bool,
    created-at: uint
  }
)

(define-map lobbying-expenditures
  { expenditure-id: uint }
  {
    company-id: uint,
    quarter: uint,
    year: uint,
    total-amount: uint,
    federal-lobbying: uint,
    state-lobbying: uint,
    local-lobbying: uint,
    issue-areas: (string-ascii 200),
    lobbyist-firms: (string-ascii 200),
    government-officials: (string-ascii 200),
    reported-at: uint,
    verified: bool
  }
)

(define-map political-donations
  {
    company-id: uint,
    recipient: (string-ascii 100),
    election-cycle: uint
  }
  {
    donation-type: (string-ascii 30),
    amount: uint,
    donation-date: uint,
    purpose: (string-ascii 100),
    reported-by: principal,
    verified: bool
  }
)

(define-map pac-activities
  {
    company-id: uint,
    pac-name: (string-ascii 100)
  }
  {
    pac-type: (string-ascii 20),
    total-raised: uint,
    total-spent: uint,
    employee-contributions: uint,
    corporate-contributions: uint,
    election-cycle: uint,
    active: bool
  }
)

(define-map government-contacts
  { contact-id: uint }
  {
    company-id: uint,
    official-name: (string-ascii 100),
    official-title: (string-ascii 100),
    agency: (string-ascii 100),
    contact-type: (string-ascii 30),
    meeting-date: uint,
    topics-discussed: (string-ascii 300),
    outcome: (string-ascii 200),
    follow-up-required: bool,
    reported-by: principal,
    contact-frequency: uint
  }
)

(define-map regulatory-positions
  {
    company-id: uint,
    regulation-id: (string-ascii 50)
  }
  {
    regulation-title: (string-ascii 200),
    agency: (string-ascii 100),
    position: (string-ascii 20),
    public-comment: (string-ascii 500),
    lobbying-spend: uint,
    outcome: (string-ascii 100),
    filed-at: uint
  }
)

(define-map revolving-door
  {
    company-id: uint,
    individual: (string-ascii 100)
  }
  {
    previous-role: (string-ascii 100),
    government-agency: (string-ascii 100),
    current-role: (string-ascii 100),
    transition-date: uint,
    cooling-off-period: uint,
    potential-conflicts: (string-ascii 300),
    disclosed: bool
  }
)

(define-map company-admins
  { admin: principal }
  { company-id: uint }
)

(define-map authorized-reporters
  {
    company-id: uint,
    reporter: principal
  }
  { active: bool }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-company-admin (company-id uint))
  (match (map-get? companies { company-id: company-id })
    company (is-eq tx-sender (get admin company))
    false
  )
)

(define-private (is-authorized-reporter (company-id uint))
  (or
    (is-company-admin company-id)
    (default-to false (get active (map-get? authorized-reporters { company-id: company-id, reporter: tx-sender })))
  )
)

;; Company Management Functions
(define-public (register-company (name (string-ascii 100)) (admin principal))
  (let
    (
      (company-id (var-get next-company-id))
    )
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (map-set companies
      { company-id: company-id }
      {
        name: name,
        admin: admin,
        total-lobbying-spend: u0,
        total-political-donations: u0,
        pac-contributions: u0,
        transparency-score: u0,
        active: true,
        created-at: block-height
      }
    )
    (map-set company-admins
      { admin: admin }
      { company-id: company-id }
    )
    (var-set next-company-id (+ company-id u1))
    (ok company-id)
  )
)

(define-public (add-authorized-reporter (company-id uint) (reporter principal))
  (begin
    (asserts! (is-company-admin company-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? companies { company-id: company-id })) ERR-COMPANY-NOT-FOUND)

    (map-set authorized-reporters
      { company-id: company-id, reporter: reporter }
      { active: true }
    )
    (ok true)
  )
)

(define-public (report-lobbying-expenditure
  (company-id uint)
  (quarter uint)
  (year uint)
  (total-amount uint)
  (federal-lobbying uint)
  (state-lobbying uint)
  (local-lobbying uint)
  (issue-areas (string-ascii 200))
  (lobbyist-firms (string-ascii 200))
  (government-officials (string-ascii 200))
)
  (let
    (
      (expenditure-id (var-get next-expenditure-id))
    )
    (asserts! (is-authorized-reporter company-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? companies { company-id: company-id })) ERR-COMPANY-NOT-FOUND)
    (asserts! (and (>= quarter u1) (<= quarter u4)) ERR-INVALID-INPUT)
    (asserts! (> year u2020) ERR-INVALID-INPUT)
    (asserts! (is-eq total-amount (+ federal-lobbying (+ state-lobbying local-lobbying))) ERR-INVALID-INPUT)

    (map-set lobbying-expenditures
      { expenditure-id: expenditure-id }
      {
        company-id: company-id,
        quarter: quarter,
        year: year,
        total-amount: total-amount,
        federal-lobbying: federal-lobbying,
        state-lobbying: state-lobbying,
        local-lobbying: local-lobbying,
        issue-areas: issue-areas,
        lobbyist-firms: lobbyist-firms,
        government-officials: government-officials,
        reported-at: block-height,
        verified: false
      }
    )

    ;; Update company total lobbying spend
    (match (map-get? companies { company-id: company-id })
      company (map-set companies
        { company-id: company-id }
        (merge company { total-lobbying-spend: (+ (get total-lobbying-spend company) total-amount) })
      )
      false
    )

    (var-set next-expenditure-id (+ expenditure-id u1))
    (ok expenditure-id)
  )
)

(define-public (report-political-donation
  (company-id uint)
  (recipient (string-ascii 100))
  (election-cycle uint)
  (donation-type (string-ascii 30))
  (amount uint)
  (purpose (string-ascii 100))
)
  (begin
    (asserts! (is-authorized-reporter company-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? companies { company-id: company-id })) ERR-COMPANY-NOT-FOUND)
    (asserts! (> (len recipient) u0) ERR-INVALID-INPUT)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> election-cycle u2020) ERR-INVALID-INPUT)

    (map-set political-donations
      { company-id: company-id, recipient: recipient, election-cycle: election-cycle }
      {
        donation-type: donation-type,
        amount: amount,
        donation-date: block-height,
        purpose: purpose,
        reported-by: tx-sender,
        verified: false
      }
    )

    ;; Update company total political donations
    (match (map-get? companies { company-id: company-id })
      company (map-set companies
        { company-id: company-id }
        (merge company { total-political-donations: (+ (get total-political-donations company) amount) })
      )
      false
    )
    (ok true)
  )
)

(define-public (register-pac-activity
  (company-id uint)
  (pac-name (string-ascii 100))
  (pac-type (string-ascii 20))
  (total-raised uint)
  (total-spent uint)
  (employee-contributions uint)
  (corporate-contributions uint)
  (election-cycle uint)
)
  (begin
    (asserts! (is-authorized-reporter company-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? companies { company-id: company-id })) ERR-COMPANY-NOT-FOUND)
    (asserts! (> (len pac-name) u0) ERR-INVALID-INPUT)
    (asserts! (> election-cycle u2020) ERR-INVALID-INPUT)
    (asserts! (is-eq total-raised (+ employee-contributions corporate-contributions)) ERR-INVALID-INPUT)

    (map-set pac-activities
      { company-id: company-id, pac-name: pac-name }
      {
        pac-type: pac-type,
        total-raised: total-raised,
        total-spent: total-spent,
        employee-contributions: employee-contributions,
        corporate-contributions: corporate-contributions,
        election-cycle: election-cycle,
        active: true
      }
    )

    ;; Update company PAC contributions
    (match (map-get? companies { company-id: company-id })
      company (map-set companies
        { company-id: company-id }
        (merge company { pac-contributions: (+ (get pac-contributions company) corporate-contributions) })
      )
      false
    )
    (ok true)
  )
)

(define-public (log-government-contact
  (company-id uint)
  (official-name (string-ascii 100))
  (official-title (string-ascii 100))
  (agency (string-ascii 100))
  (contact-type (string-ascii 30))
  (topics-discussed (string-ascii 300))
  (outcome (string-ascii 200))
  (follow-up-required bool)
)
  (let
    (
      (contact-id (var-get next-contact-id))
    )
    (asserts! (is-authorized-reporter company-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? companies { company-id: company-id })) ERR-COMPANY-NOT-FOUND)
    (asserts! (> (len official-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len topics-discussed) u0) ERR-INVALID-INPUT)

    (map-set government-contacts
      { contact-id: contact-id }
      {
        company-id: company-id,
        official-name: official-name,
        official-title: official-title,
        agency: agency,
        contact-type: contact-type,
        meeting-date: block-height,
        topics-discussed: topics-discussed,
        outcome: outcome,
        follow-up-required: follow-up-required,
        reported-by: tx-sender,
        contact-frequency: u1
      }
    )

    (var-set next-contact-id (+ contact-id u1))
    (ok contact-id)
  )
)

(define-public (file-regulatory-position
  (company-id uint)
  (regulation-id (string-ascii 50))
  (regulation-title (string-ascii 200))
  (agency (string-ascii 100))
  (position (string-ascii 20))
  (public-comment (string-ascii 500))
  (lobbying-spend uint)
)
  (begin
    (asserts! (is-authorized-reporter company-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? companies { company-id: company-id })) ERR-COMPANY-NOT-FOUND)
    (asserts! (> (len regulation-id) u0) ERR-INVALID-INPUT)
    (asserts! (> (len regulation-title) u0) ERR-INVALID-INPUT)
    (asserts! (or (is-eq position "support") (or (is-eq position "oppose") (is-eq position "neutral"))) ERR-INVALID-INPUT)

    (map-set regulatory-positions
      { company-id: company-id, regulation-id: regulation-id }
      {
        regulation-title: regulation-title,
        agency: agency,
        position: position,
        public-comment: public-comment,
        lobbying-spend: lobbying-spend,
        outcome: "",
        filed-at: block-height
      }
    )
    (ok true)
  )
)

(define-public (report-revolving-door
  (company-id uint)
  (individual (string-ascii 100))
  (previous-role (string-ascii 100))
  (government-agency (string-ascii 100))
  (current-role (string-ascii 100))
  (transition-date uint)
  (cooling-off-period uint)
  (potential-conflicts (string-ascii 300))
)
  (begin
    (asserts! (is-authorized-reporter company-id) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? companies { company-id: company-id })) ERR-COMPANY-NOT-FOUND)
    (asserts! (> (len individual) u0) ERR-INVALID-INPUT)
    (asserts! (> (len previous-role) u0) ERR-INVALID-INPUT)
    (asserts! (> (len current-role) u0) ERR-INVALID-INPUT)

    (map-set revolving-door
      { company-id: company-id, individual: individual }
      {
        previous-role: previous-role,
        government-agency: government-agency,
        current-role: current-role,
        transition-date: transition-date,
        cooling-off-period: cooling-off-period,
        potential-conflicts: potential-conflicts,
        disclosed: true
      }
    )
    (ok true)
  )
)

(define-public (verify-expenditure (expenditure-id uint))
  (match (map-get? lobbying-expenditures { expenditure-id: expenditure-id })
    expenditure
    (begin
      (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
      (map-set lobbying-expenditures
        { expenditure-id: expenditure-id }
        (merge expenditure { verified: true })
      )
      (ok true)
    )
    ERR-EXPENDITURE-NOT-FOUND
  )
)

;; Read-only Functions
(define-read-only (get-company-info (company-id uint))
  (map-get? companies { company-id: company-id })
)

(define-read-only (get-lobbying-expenditure (expenditure-id uint))
  (map-get? lobbying-expenditures { expenditure-id: expenditure-id })
)

(define-read-only (get-political-donation (company-id uint) (recipient (string-ascii 100)) (election-cycle uint))
  (map-get? political-donations { company-id: company-id, recipient: recipient, election-cycle: election-cycle })
)

(define-read-only (get-pac-activity (company-id uint) (pac-name (string-ascii 100)))
  (map-get? pac-activities { company-id: company-id, pac-name: pac-name })
)

(define-read-only (get-government-contact (contact-id uint))
  (map-get? government-contacts { contact-id: contact-id })
)

(define-read-only (get-regulatory-position (company-id uint) (regulation-id (string-ascii 50)))
  (map-get? regulatory-positions { company-id: company-id, regulation-id: regulation-id })
)

(define-read-only (get-revolving-door-info (company-id uint) (individual (string-ascii 100)))
  (map-get? revolving-door { company-id: company-id, individual: individual })
)

(define-read-only (calculate-transparency-score (company-id uint))
  (match (map-get? companies { company-id: company-id })
    company
    (let
      (
        (base-score u30)
        (lobbying-disclosure-bonus u25)
        (donation-disclosure-bonus u25)
        (contact-disclosure-bonus u20)
      )
      (+ base-score (+ lobbying-disclosure-bonus (+ donation-disclosure-bonus contact-disclosure-bonus)))
    )
    u0
  )
)

(define-read-only (get-total-political-influence (company-id uint))
  (match (map-get? companies { company-id: company-id })
    company
    (+ (get total-lobbying-spend company) (+ (get total-political-donations company) (get pac-contributions company)))
    u0
  )
)
