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
| Client B after A burst | Also 429; independent success not established |

Dependency telemetry confirmed 10 Foundry backend 429s; gateway exceptions
confirmed another 3 rate-limit rejections. The shared backend limit prevented
client B from succeeding after A's burst. This proves throttling but not full
per-subscription limit isolation. Do not claim client B isolation passed.

The successful requests deliberately supplied spoofed `x-client-id` and
`x-subscription-id` headers. AppTraces showed actual validated identities and
subscription IDs. The committed cost query returned:

| Subscription | Successful calls | Input tokens | Output tokens | Missing usage |
| --- | ---: | ---: | ---: | ---: |
| model-client-a | 2 (primary + secondary key) | 26 | 2 | 0 |
| model-client-b | 1 | 13 | 1 | 0 |

Primary and secondary keys share attribution; separate clients have separate
usage rows. Spoofed headers did not change reporting. Traces took several
minutes to ingest. Dollar estimates remain null with unset prices.

## Remaining checks

Full rate-limit isolation, key regeneration/rotation after successful use,
token-quota enforcement and a blocked content-safety case need explicit recorded
results. Cost calculation requires dated prices;
the KQL defaults to null costs until prices are supplied. Token accounting is not
an invoice or an exact spending cap. Do not report remaining checks as passed.
