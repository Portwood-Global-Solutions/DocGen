# Demo script — replacing SDocs for project documents & e-signature

**Audience:** Kathy and her team.
**Length:** 15 minutes of demo, 10 of discussion.
**Org:** `portwood-sdocs` (`sf org open --target-org portwood-sdocs`), Portwood **v3.54.0** installed as a real managed-package install.

---

## What Kathy actually said

> We are currently using SDocs to generate project-related documents to send to the client for e-signature. Some of them are simple approval emails, some are more dynamic as they pull data from related lists off the project. Users however have to attach the e-sig template when sending to the client and they forget many times. So, I built a flow to auto-attach it but that comes with some complexity as well.

There are three separate asks buried in that paragraph. Address them in this order, because the third one is the one that hurts:

| #   | Her words                                      | What she is really asking              |
| --- | ---------------------------------------------- | -------------------------------------- |
| 1   | "simple approval emails"                       | Can you do the easy documents?         |
| 2   | "pull data from related lists off the project" | Can you do the hard ones?              |
| 3   | "users forget… so I built a flow"              | Can you make the failure mode go away? |

**The thesis, in one sentence:** in Portwood the e-signature fields live inside the template, so there is no second artifact to attach — which means there is nothing to forget, and the Flow she built to compensate collapses into a single action.

Say that sentence early. Everything after it is evidence.

---

## Before you present

```bash
# 1. Put the org back to a clean pre-demo state (do this every time)
sf apex run --target-org portwood-sdocs -f scripts/demo/sdocs/reset.apex

# 2. Open the org
sf org open --target-org portwood-sdocs
```

Then in the browser: **App Launcher → Portwood Projects → Demo Projects tab → P-2041 Patient Portal Modernization** (Meridian Health Systems). Leave that tab open.

**Have a second browser window ready in incognito.** That is where the client signs.

### The one thing that will bite you

A fresh scratch org has **no Org-Wide Email Address**, so Portwood creates the signature request and the signing links but does not send the invitation email. You will see this on the request record:

> Emails not sent — no Org-Wide Email Address configured. Set one in Portwood > Signatures settings.

The signing experience is completely intact. Get the link directly:

```bash
sf apex run --target-org portwood-sdocs -f scripts/demo/sdocs/print-signing-url.apex
```

Paste the `SIGN-URL open` line into the incognito window. Do not hand-edit the URL — the script picks the correct signing page for you.

If you want real email on stage, configure an Org-Wide Email Address **before** the meeting (it needs a verification click) and then delete the `requireEmailVerification` input from the Flow to bring back the one-time PIN step.

---

## The demo

### Beat 1 — "Here is the project you already have" (1 min)

Land on **P-2041 Patient Portal Modernization**. Scroll the related lists.

> "This is a project record with the three related lists you described — milestones, deliverables, change orders. Nothing here is Portwood. This is just your data. Portwood is the panel on the right."

Point at **Generate Document** in the sidebar. Three templates listed.

---

### Beat 2 — The simple one (2 min)

Pick **Project Approval Request** → Generate.

A one-page approval letter comes back: the client's name and address, the project summary, the scope paragraph, the approval statement. Open it.

> "That is your 'simple approval email.' Merge fields off the project and up through the Client lookup to the account. Ninety seconds of authoring."

**Now the important part.** Scroll to the bottom of the PDF and point at the empty signature block.

> "Look at what is already in this document — a signature field and a date field. That is not a second file. It is one tag in the template body: `{@Signature_Client:1:Full}`. The document that just generated is already signable. There is nothing to attach to it."

Let that sit. This is the whole meeting.

---

### Beat 3 — The dynamic one (4 min)

Back on the record, pick **Project Acceptance Certificate** → Generate.

Three pages come back. Walk them:

- **Milestone Schedule** — 6 rows, each with its acceptance criteria, a status, and a value; total row reads **$486,000.00 · 6 milestones**.
- **Deliverables** — 7 rows across five categories with delivery dates and who accepted each.
- **Approved Change Orders** — 3 rows totalling **$64,500.00**.
- **Contract Summary** — $486,000 original + $64,500 approved changes = **$550,500 revised**.
- Two signature blocks: Client and Provider.

> "Three related lists, running totals, in one document. Zero lines of code — the tables are `{#Milestones__r}…{/Milestones__r}` loops and the totals are `{SUM:Milestones__r.Value__c:currency}`."

**Then the detail that sells it.** Open the Change Orders related list on the record: there are **four**, and the fourth (the deferred mobile wrapper, $22,000) is still `Requested`.

> "The certificate showed three, not four. The template filters to approved change orders only — that rule lives in the template's query, not in the body and not in code. Which is why the table and the revised contract value can never disagree with each other."

If someone asks about scale: the same mechanism handles thousands of child rows; past ~2,000 Portwood switches to a different query strategy automatically and keeps repeating table headers across pages.

---

### Beat 3.5 — Two signers, in order (4 min, optional but strong)

Do this one if signatures are the sticking point. It shows the part of the signature engine that a simple "one signature at the bottom" tool cannot do.

On **P-2041**, scroll to the **Documents / Send for Signature** panel and pick **Project Acceptance Certificate**.

**Stop and point at the Signers list before you type anything.** Two rows have already appeared, pre-filled with **Client** and **Provider**.

> "I didn't add those. The component read the signature tags out of the template and worked out that this document has two roles. The template is the source of truth for who signs — not a checklist somebody has to remember."

Set **Signing Order** to **One at a time (sequential)**, then fill in:

| Role     | Name           | Email                          |
| -------- | -------------- | ------------------------------ |
| Client   | Dana Whitfield | `davemoudy+meridian@gmail.com` |
| Provider | Alan Reyes     | `davemoudy+pm@gmail.com`       |

Click **Generate Signature Links**.

Get Dana's link (`scripts/demo/sdocs/print-signing-url.apex` prints the newest pending signer — with sequential ordering that is always whoever's turn it is) and open it in incognito.

This path leaves **email PIN verification ON**, so you will hit "Verify your email to continue". That is a good thing to show — just plant a code you know:

```bash
# 1. type the signer's email on the page → Send Verification Code
# 2. then:
sf apex run --target-org portwood-sdocs -f scripts/demo/sdocs/set-known-pin.apex
# 3. enter 123456 on screen.  Do NOT click Resend afterwards.
```

> "In production that code goes to the signer's inbox. It is one of the reasons this holds up legally — you can prove the person who signed controls that email address."

Sign as Dana. Notice she is shown **2 fields, not 4** — only her role's placements. Then check the record: the request is now **In Progress**, Dana is **Signed**, and Alan has become the active signer. Sign as Alan the same way.

When both are done, open the PDF on the record:

- Both stamps sit in their own cells — _Signed by Dana Whitfield · Portwood_ on the left, _Signed by Alan Reyes · Portwood_ on the right
- The Certificate of Completion lists **both** signers with their roles, emails, timestamps, IP addresses and consent records

> "Sequential ordering, per-role fields, one certificate covering both parties. That is all declared by four tags in the template."

---

### Beat 4 — Making the failure mode disappear (6 min) ← the point

> "Now the part you actually wrote a Flow for."

Open **Setup → Flows → Project — Auto-Send for Approval**. Show the canvas. It is five elements:

1. Start — when a project's Status changes to _Pending Client Approval_
2. Get the client contact
3. Build the signer
4. **Portwood — Create Signature Request**
5. Stamp the project (audit)

> "Compare this to what you have today. There is no 'generate the document' step. There is no file lookup, no ContentDocumentLink, no 'find the e-sig template and attach it' branch. That one action generates the document from the template and requests the signature — because the signature fields were in the template the whole time. Your users cannot forget to attach something that was never a separate thing."

Point at the template input:

> "And it references the template by API name, not by record Id — so this Flow survives the move from sandbox to production."

**Now run it.** Go to **P-2088 Warehouse Automation Rollout**, change **Status** to **Pending Client Approval**, Save.

Refresh. The record now shows **Approval Sent On** = today and a **Last Signature Request Id**. Open the related Signature Request: status **Sent**, one signer — Marcus Ellery — with a signing link.

> "Nobody generated anything. Nobody attached anything. A status change did it."

**Then sign it.** Get the link:

```bash
sf apex run --target-org portwood-sdocs -f scripts/demo/sdocs/print-signing-url.apex
```

Paste into incognito. The client sees the fully merged document with **SIGN HERE** and **DATE** markers. Click **Start Signing** → type or draw the name → **Save & Next** → the date auto-fills → **Finish & Submit** with the ESIGN consent checkbox.

Back in Salesforce, refresh P-2088:

- Signature Request status → **Signed**
- A PDF named _Approval Request - P-2088 - Northwind Logistics Group_ is now on the project's Files
- Open it: the signature is stamped in place ("Signed by Marcus Ellery · Portwood"), and there is a **Certificate of Completion** page with the signer's email, timestamp, IP address, consent record, an ESIGN/UETA attestation, and a SHA-256 hash of the signed PDF for tamper evidence.

> "That certificate is generated for you. It is the thing your legal team will ask about."

---

### Beat 5 — Close (2 min)

> "One template, authored once, does the generation and the signature. The automation you maintain drops from a Flow that compensates for a missing attachment to a single action that cannot miss it. And it is 100% native — no external service, no callouts, nothing leaves your org."

---

## Questions you should expect

**"Can we keep authoring in Word?"**
Yes — Word, HTML, PowerPoint and Excel templates all work. Both templates in this demo are HTML because HTML is the most reliable for PDF output and the easiest to restyle. If their SDocs templates are Word, that is the migration path.

**"How do our SDocs templates come across?"**
There is no automatic converter. The merge-field syntax differs, so a template is re-authored rather than imported. Realistically that is an afternoon per document, and the related-list documents get simpler because the loops are declarative. Be straight about this — it is the honest cost of the switch.

**"What about multiple signers, or a signing order?"**
Supported and demonstrable — that is Beat 3.5. The acceptance certificate carries two roles (Client order 1, Provider order 2); the sender reads them straight off the template, offers parallel or sequential ordering, shows each signer only their own fields, and produces one Certificate of Completion covering both. Initials, auto-dates and user-picked dates are additional tag types. To automate it, add a second `DocGenSigner` to the Flow's collection — same mechanism.

**"Is this the same signature engine as the old version?"**
The tags are v3: `{@Signature_Role:Order:Type}` — role, signing order and field type, versus the older bare `{@Signature_Role}` which only ever meant "one typed signature here". v3 is what makes per-role field scoping, sequential ordering, initials and date fields possible. Old-style tags still work unchanged, so nothing has to be rewritten to upgrade.

**"Do the client's signers need Salesforce licenses?"**
No. They get a tokenised link.

**"What if the document changes after we send it?"**
The request freezes a copy of the document at send time, and the certificate records a hash of what was actually signed.

**"Can it fire from something other than a status change?"**
Anything that can run a Flow — a button, an approval process, a scheduled path, a platform event.

---

## Known rough edges (say these before they find them)

- **Emails need an Org-Wide Email Address.** In this scratch org there isn't one, so links are generated but not emailed. In their org this is a one-time setup.
- **Email PIN verification is OFF in the Flow, ON in the record-page sender.** The Flow turns it off (`requireEmailVerification = false`) because a Flow run cannot pause for someone to read a code; the sender component leaves it on. Neither can deliver the code without an OWA, so use `set-known-pin.apex` to plant `123456` when you want to walk through the verification step. In their org, with an OWA configured, both send for real.
- **v3.54.0 bug, already fixed in the repo, not yet in a released build:** the classic typed-name signing page (`/apex/portwoodglobal__DocGenSignature`) cannot complete a signature — it hangs on "Saving your signature…" because its `saveSignature` remoting call passes five arguments to a six-argument method (regression from #161). **This demo does not touch that page** — the Create Signature Request action sets `Source_Document_Id__c`, which routes signers to the guided PDF viewer, and that path is verified working end to end. Ship the fix before any customer lands on the classic path.

---

## What this org contains

| Thing                                                                     | Where                                                   |
| ------------------------------------------------------------------------- | ------------------------------------------------------- |
| 3 projects, 14 milestones, 14 deliverables, 7 change orders               | Portwood Projects app                                   |
| `Project Approval Request` — 1 page, 1 signature                          | Portwood Templates                                      |
| `Project Acceptance Certificate` — 3 pages, 3 related lists, 2 signatures | Portwood Templates                                      |
| `Project — Auto-Send for Approval`                                        | Setup → Flows                                           |
| Template bodies                                                           | `DEMO TEMPLATES/html/prof-services/project-*.html`      |
| Rebuild from scratch                                                      | `./scripts/demo/sdocs/setup.sh portwood-sdocs --create` |
| Reset between rehearsals                                                  | `scripts/demo/sdocs/reset.apex`                         |
| Get the current signing link                                              | `scripts/demo/sdocs/print-signing-url.apex`             |
| Plant a known email PIN (`123456`)                                        | `scripts/demo/sdocs/set-known-pin.apex`                 |

**Showcase record:** P-2041 (Meridian Health Systems) — richest related lists, use it for Beats 2 and 3.
**Automation record:** P-2088 (Northwind Logistics Group) — used by Beat 4 so P-2041 stays clean.
