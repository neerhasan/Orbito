# M0 setup and test guide

This guide is for the founder. It covers the steps that only you can do, and the exact test that proves M0 works. Do the parts in order. Claude Code can run every command for you. The commands are listed so you can also run them yourself.

Menu names on the Supabase and PowerSync websites change from time to time. If a name here does not match what you see, stop and ask Claude Code.

**A rule for the whole guide:** never paste a key or a password into the chat. Type them only into the website or the file named in the step.

## Part 1: Supabase (the server database and sign-in)

1. Go to https://supabase.com and sign in. Click **New project**. Name it `orbito`. Choose the region closest to you. Let Supabase generate the database password and save it in your password manager. Click **Create new project** and wait until it is ready.
2. Switch off email confirmation for the friends test: in the left menu click **Authentication**, then **Sign In / Providers**, then **Email**. Turn **Confirm email** off. Click **Save**.
3. Create the test table: in the left menu click **SQL Editor**, then **New query**. Open the file `supabase/001_sync_test.sql` from this project, copy all of it, paste it into the editor and click **Run**. You should see "Success. No rows returned".
4. Create the login that PowerSync uses: click **New query** again. Open `supabase/002_powersync_role.sql`, copy all of it and paste it into the editor. In the editor, replace `REPLACE_WITH_A_LONG_PASSWORD` with a long password that you make up (30 or more letters and numbers). Save that password in your password manager. Click **Run**.

## Part 2: PowerSync (the sync service)

1. Go to https://www.powersync.com and create a free account. Create a project and an instance. Name the instance `orbito`. Choose the region closest to your Supabase region.
2. Connect it to the database. PowerSync asks for a database connection. Fill in:
   - **Host, port and database name:** in Supabase click **Connect** at the top of the page. Use the values shown under **Direct connection**.
   - **Username:** `powersync_role`
   - **Password:** the password you made up in Part 1, step 4.
   
   Click **Test connection**, then save.
3. Turn on Supabase sign-in: in the instance settings open **Client Auth**. Tick **Use Supabase Auth**. Leave the "JWT Secret" box empty. Save and deploy.
4. Add the sync config: open the sync config editor of the instance (it may be called **Sync Streams** or **Sync Rules**). Delete what is there. Open the file `powersync/sync-config.yaml` from this project, copy all of it, paste it in, then click **Validate** and **Deploy**.
5. Copy the **Instance URL** of your instance (the **Connect** button shows it). It looks like `https://something.powersync.journeyapps.com`. You need it in Part 3.

## Part 3: the `.env` file (the app's three public settings)

1. In the project folder there is a file named `.env`. Open it in VS Code. (If it does not exist, copy `env.example` and name the copy `.env`.)
2. Fill in the three values:
   - `SUPABASE_URL`: in Supabase click **Project Settings**, then **Data API**. Copy the **Project URL**.
   - `SUPABASE_PUBLISHABLE_KEY`: in Supabase click **Project Settings**, then **API Keys**. Copy the **Publishable key**. It starts with `sb_publishable_`. Do **not** copy the key called "secret" or "service_role".
   - `POWERSYNC_URL`: the Instance URL from Part 2, step 5.
3. Save the file. Git ignores `.env`, so it never leaves your PC.

## Part 4: run the app on Windows

In a terminal in the project folder:

```
flutter run -d windows
```

The first start takes a few minutes. A window named **Orbito** opens with a sign-in screen. If it says "Orbito is not set up yet", a value in `.env` is still missing. The screen names it.

## Part 5: run the app on your Android phone

1. On the phone open **Settings**, then **About phone**. Tap **Build number** seven times until it says "You are now a developer".
2. Go back to **Settings**, then **System**, then **Developer options**. Turn **USB debugging** on.
3. Connect the phone to the PC with a USB cable. On the phone tap **Allow** when it asks "Allow USB debugging?".
4. In a second terminal in the project folder:

```
flutter run -d android
```

The first build takes several minutes. The app opens on the phone. Keep the Windows app open too.

## Part 6: the M0 test

Do every step. Write the result in `docs/TEST-NOTES-TEMPLATE.md`.

**Test 1: the same account on both devices**
1. On the PC, type an email and a password and click **Create account**. The test screen opens and the status line says **Sync: Synced**.
2. On the phone, type the same email and password and tap **Sign in**.
3. Pass if both devices show "Signed in as" with the same email.

**Test 2: a row travels between devices**
1. On the PC, type `from pc` in the box and click **Add**.
2. Pass if `from pc` appears on the phone within a few seconds.
3. On the phone, add `from phone`.
4. Pass if `from phone` appears on the PC within a few seconds.

**Test 3: offline, then reconnect**
1. On the phone, turn on **Airplane mode** (swipe down from the top of the screen and tap the plane).
2. Wait until the status line on the phone says **Sync: Offline**.
3. On the phone, add `added offline`. The row shows on the phone at once, and the status line says "1 change waiting to upload". It must **not** be on the PC yet.
4. On the phone, turn Airplane mode off.
5. Pass if, within about a minute, the phone says **Sync: Synced** and `added offline` appears on the PC.
6. Repeat the other way round: on the PC turn Wi-Fi off (click the network icon at the bottom right of the screen), add `pc offline`, turn Wi-Fi on again. Pass if the row appears on the phone.

**Test 4: a second account cannot see the first account's rows**
1. On the phone, tap **Sign out**. Then create a second account with a different email.
2. Pass if the list is empty on the phone, while the PC (still on the first account) still shows its rows.
3. On the phone, add `second account only`. Pass if it does **not** appear on the PC.
4. The automatic proof: copy `env.test.example`, name the copy `.env.test`, and fill in the emails and passwords of the two test accounts. Then ask Claude Code to run:

```
flutter test test/integration/rls_test.dart
```

   Pass if it prints "All tests passed!". If it prints "Skipped", the `.env.test` file is not filled in.

**Test 5: data survives a restart**
1. Close the Windows app and start it again with `flutter run -d windows`.
2. Pass if you are still signed in and the rows are still there.

If any test fails, stop and tell Claude Code which step failed and what the status line says. The build plan says we change the plan before building more.

## Part 7: GitHub (automatic builds)

1. The project lives in the private repository https://github.com/neerhasan/Orbito. Claude Code pushes each saved version to it.
2. Fill in `.env` first (Part 3), so you have the three values at hand.
3. On GitHub open the repository, then **Settings**, then **Secrets and variables**, then **Actions**, then the **Variables** tab. Click **New repository variable** three times and add `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and `POWERSYNC_URL` with the same values as in `.env`. These three are public values, so "Variables" is the right place. Never add a secret key here.
4. Open the **Actions** tab. Pass if the **Build** run turns green and offers two downloads: `orbito-windows` and `orbito-android-apk`.
