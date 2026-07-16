# Medride

A non-emergency medical transportation (NEMT) marketplace, modeled after
services like Roundtrip Health. Care organizations (hospitals, health plans)
book rides on behalf of patients; transport providers claim and fulfill
them. Built as a domain-modeling exercise — boring, idiomatic Rails, no
unnecessary gems.

## Domain model

- **Patient** — demographics, home address, optional link to a FHIR patient
  id and benefit plan.
- **CareOrganization** / **Coordinator** — a hospital or health plan, and the
  staff who book rides on behalf of patients.
- **TransportProvider** — a transport company with a zip-code service area
  and a set of vehicle capabilities (rideshare, medical sedan, wheelchair
  van, stretcher van, BLS ambulance), modeled as a join table.
- **Ride** — belongs to a patient and coordinator; a state machine
  (`requested → claimed → in_progress → completed`, plus `cancelled` and
  `release` back to `requested`) enforced by guard methods on the model,
  with every transition recorded as a `RideStatusEvent` audit row.
- **RideClaim** — which provider holds the active claim on a ride. Only one
  provider can hold an active claim at a time, enforced with a Postgres
  partial unique index (not just an app-level check) — see
  `test/models/ride_claim_race_test.rb` for a real concurrent-thread test of
  the race condition.

## Marketplace logic

- `MatchRide` — given a ride, finds transport providers whose service area
  covers the pickup zip and whose capabilities match the requested level of
  service.
- `RightSizingCheck` — a table-driven rule rejecting bookings where the
  requested level of service exceeds what the patient's `mobility_needs`
  require (mirrors real NEMT utilization management, which exists to
  prevent over-ordering expensive transport).

## FHIR integration

- `Fhir::Client` wraps the [`fhir_client`](https://github.com/fhir-crucible/fhir_client)
  gem, talking to the public [HAPI FHIR R4 test server](https://hapi.fhir.org/baseR4).
  Results are translated into plain `Fhir::Patient` / `Fhir::Appointment`
  structs rather than passed around as typed FHIR resources.
- **Import from EHR** (`/ehr_import`): given a FHIR patient id, fetches the
  patient and any upcoming appointment, upserts a local `Patient`, and
  starts a pre-filled ride booking.
- `EligibilityCheck` stubs a `CoverageEligibilityRequest`/`Response` round
  trip against local `BenefitPlan`/`BenefitCoverageRule` tables — returns
  covered/remaining trips/prior-auth-required. A ride whose level of service
  needs prior auth still books (status `requested`) but is flagged
  `needs_authorization`.

## Webhooks

`POST /webhooks/ride_status` simulates a transport vendor pushing status
updates (the way a rideshare API would). Requests are HMAC-signed
(`X-Medride-Signature`), idempotent on `event_id` (a unique DB index, not
just application logic), and processed asynchronously via
`RideStatusWebhookJob`.

Fire a fake event from the command line:

```
bin/rails "webhooks:fire_ride_status[RIDE_ID,STATUS,TRANSPORT_PROVIDER_ID]"
# STATUS is one of: in_progress, completed, cancelled
```

## Setup

Requires Ruby 3.4.5 and PostgreSQL.

```
bundle install
bin/rails db:setup   # create, migrate, and seed
bin/dev               # rails server + tailwindcss watcher
```

No login system (out of scope for this project) — visit `/` and pick a
coordinator or transport provider to act as; the choice is remembered in
the session.

## Tests

```
bin/rails test
```

Covers the ride state machine's guard methods, the claim race condition
(genuine concurrent threads against separate DB connections, not just a
sequential check), `MatchRide`/`RightSizingCheck`/`EligibilityCheck`, and
the webhook endpoint's signature verification and idempotency.

## End-to-end verification

```
bin/rails db:seed
bin/ride_lifecycle_demo
```

Walks one ride through the entire flow against real services — imports a
real patient from the live HAPI FHIR test server, runs the eligibility
check, books and matches the ride, claims it, drives it through
`in_progress` → `completed` via signed webhook calls, and prints the full
status audit trail.
