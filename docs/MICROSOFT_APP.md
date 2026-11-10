# Registering betternotes with Microsoft (for OneDrive sync)

To sync with OneDrive, Microsoft wants to know which app is asking. You register betternotes
once and get an **Application (client) ID**. That ID is not a secret (it only names the app),
so it is stored in this repository afterwards. There is **no password or client secret**
involved; never create one.

Your friends do not have to do this. They use the same ID and sign in with their own account.

Menu names in Microsoft's portal change often. If a name here does not match, look for the
closest one; the order of the steps stays the same.

## Step 1: get into the portal

Open <https://entra.microsoft.com> and sign in. Which account?

| Try in this order | Why | Downside |
|---|---|---|
| A. A **private** Microsoft account (outlook.com, hotmail.com, or any e-mail you registered with Microsoft) | The registration belongs to you and survives leaving school | Microsoft requires a "directory". If the portal shows an error or an empty page, do step 1b |
| B. Your **school** account | No sign-up needed; many schools allow it | The registration disappears with the school account. Only as a stopgap |

### Step 1b: only if the private account has no directory

A directory is Microsoft's word for an organisation. A private account does not have one
until you create an Azure account. Options, cheapest first:

1. **Azure for Students**: <https://azure.microsoft.com/free/students>. No credit card, but
   it wants a school e-mail address to prove you are a student. Sign in with the private
   account and verify with the school address.
2. **Free Azure account**: <https://azure.microsoft.com/free>. Asks for a phone number and a
   credit or debit card to check your identity. Registering an app costs nothing, and nothing
   in this guide creates anything that costs money.

After that, open <https://entra.microsoft.com> again.

## Step 2: register the app

1. In the left menu: **Entra ID** (or **Identity**) > **App registrations**.
2. Click **New registration**.
3. **Name**: `betternotes`
4. **Supported account types**: choose
   **Accounts in any organizational directory and personal Microsoft accounts**.
   (This is what lets school accounts and private accounts sign in.)
5. **Redirect URI**: in the drop-down choose **Single-page application (SPA)** and enter
   exactly:

   ```
   https://friederichvonstoeren.github.io/betternotes/spikes/onedrive/
   ```

6. Click **Register**.

If **New registration** is greyed out or you get "You do not have permission": this account
may not register apps. Go back to step 1 and use the other kind of account.

## Step 3: copy the ID

On the page that opens (Overview), copy **Application (client) ID**. It looks like
`1a2b3c4d-1234-5678-9abc-1a2b3c4d5e6f`.

Do **not** open "Certificates & secrets". Nothing there is needed.

## Step 4: run the test

1. Open <https://friederichvonstoeren.github.io/betternotes/spikes/onedrive/>.
2. Paste the ID and click **Sign in and run the test**.
3. Sign in with the account whose OneDrive you want to use (**your school account**).
4. Microsoft asks whether betternotes may "access its own app folder". Accept.
5. The page runs eight checks and shows a report. Click **Copy report** and send it back.
   The report contains no password and no token.

What can happen at step 3 or 4:

| You see | Meaning |
|---|---|
| The eight checks, all OK | Sync can be built as planned |
| "Need admin approval" | Your school does not let students approve apps. Only the school's IT admin can allow it. Run the test once more with a private Microsoft account so we know the app itself works |
| Sign-in works but "App folder" fails | School OneDrive does not support the app-folder permission. Send the report; we then decide about asking for full OneDrive access instead |
| "AADSTS50011 ... redirect URI" | The address in step 2.5 was typed differently. Fix it under **Authentication** in the app registration |

## Later (not now)

When sync is built, two more redirect addresses are added under **Authentication**: one for
the web app and one for the iPad app. The steps will be added here at that time.
