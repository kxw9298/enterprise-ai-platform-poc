# AI platform live validation — 2026-10-25

## Deployment and repair

GitHub apply [40254387175](https://github.com/kxw9298/enterprise-ai-platform-poc/actions/runs/40254387175)
succeeded. Foundry, internal APIM, telemetry, Bastion Basic and the private test VM
are deployed. Container Apps/ACR and AKS remain disabled. Paid resources remain
running; successful tests do not tear them down automatically.

Initial model calls failed with 401 because the API-scoped subscriptions used
`/apis/model;rev=1`, the revision-qualified Terraform API resource ID. Correction
`5cfd80e` uses the logical `/apis/model` scope. User explicitly approved replacing
the two test subscriptions, which regenerated their keys. A local saved-plan apply
completed **2 added, 1 changed, 2 destroyed** after checking the exact changes with
`scripts/ci/check-model-subscription-repair.sh`. The generic replacement guard was
not weakened. Four regression tests protect the dedicated repair check.

## Verified runtime results

Tests ran through Azure VM Run Command on the private VM without adding NAT or
changing public access. Secrets were omitted from command output and Git.

| Test | Observed result |
| --- | --- |
| Private APIM hostname | Resolves to `10.42.4.4` |
| Private connectivity probe | HTTP 200, private/internal-apim/ok |
| No subscription key | 401 |
| Invalid subscription key | 401 |
| Valid subscription key without Entra token | 401 |
| Client A token with client B subscription key | 403 |
| Client A token and matching key | 200, 13 input + 1 output token |
| Client B token and matching key | 200, 13 input + 1 output token |
| Streaming request | 400 |
| Client A secondary key | 200, 13 input + 1 output token |
| Bounded burst from client A | 429 observed, including gateway rate-limit message |
| Client B after initial A burst | Also 429 due to shared Foundry throughput |
| Isolation with temporary 1 request/minute | A first 200; A second 429; B 200 |
| Daily quota with temporary 1 token | Subsequent A/B requests rejected with 403 |
| Regenerated primary key, after propagation | Old key 401; new key 200 |
| Synthetic self-harm prompt | 400, backend error code `content_filter` |

Dependency telemetry confirmed 10 Foundry backend 429s; gateway exceptions
confirmed another 3 rate-limit rejections. The shared backend limit prevented
client B from succeeding after the initial burst. A follow-up test lowered APIM
to one request/minute per subscription using a guarded Terraform policy update.
A's first call succeeded, A's second got an explicit gateway 429 with Retry-After
60, and B immediately succeeded. This verifies independent request counters.
Normal limits were then restored through Terraform.

The daily quota test lowered the quota to one token. With prompt estimation
disabled, a request can succeed before actual usage is recorded; subsequent A/B
calls returned 403 with `Token quota is exceeded`. This is not a hard prepaid
spending limit. Normal 10,000-token quota was restored through Terraform.

The successful requests deliberately supplied spoofed `x-client-id` and
`x-subscription-id` headers. AppTraces showed actual validated identities and
subscription IDs. The committed cost query returned:

| Subscription | Successful calls | Input tokens | Output tokens | Missing usage |
| --- | ---: | ---: | ---: | ---: |
| model-client-a | 2 (primary + secondary key) | 26 | 2 | 0 |
| model-client-b | 1 | 13 | 1 | 0 |

Primary and secondary keys share attribution; separate clients have separate
usage rows. Spoofed headers did not change reporting. Traces took several
minutes to ingest.

## Dated retail estimate

Official Azure Retail Prices API meters for East US / GlobalStandard were verified
on 2026-10-25: $0.40 input, $0.10 cached input, $1.60 output per million tokens.
See `pricing/gpt-4.1-mini-global-2026-10-25.json` for meter IDs, retail units,
effective dates and source URL. The current KQL prices only the matching model
and version during the observed America/New_York day; unmatched data stays null.

An intermediate query snapshot after six successful calls returned:

| Subscription | Calls | Input / output tokens | Estimated model USD |
| --- | ---: | --- | ---: |
| model-client-a | 4 | 52 / 4 | 0.0000272 |
| model-client-b | 2 | 26 / 2 | 0.0000136 |

MissingUsageRequests and UnpricedRequests were zero. This snapshot precedes
later key/safety tests and is not the final bill. Estimates exclude infrastructure,
discounts and taxes. Refresh rates and the pricing window for future tests.

## Primary-key rotation

Client A's primary key was regenerated through the APIM management API. The first
immediate probe still accepted the old key and rejected the new key. After gateway
propagation, the old key returned 401 and the new primary key returned 200. The
secondary key continued to authenticate during the transition (initially 200;
later it reached Foundry and encountered the shared backend 429). Allow for
propagation and use the secondary key for a controlled rotation. Subscription ID
remained `model-client-a`; reporting identity did not rotate with the key.

## Content filtering

A synthetic self-harm test returned HTTP 400 with backend error code
`content_filter`, verifying the configured blocking policy through APIM. No
generated harmful content was printed or committed. An earlier weapons-themed
request returned 200 and did not demonstrate a filter block; content filters
classify specific harm categories and are not a guarantee to reject every
undesired request. The recorded self-harm result is the verified blocking case.

## Remaining checks

Request isolation, key regeneration, blocked safety and daily-quota rejection are verified;
independent per-minute token-limit isolation was not separately exercised.
