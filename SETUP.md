# All In One Store: admin setup

The store runs on GitHub Pages. Accounts, products, photos and orders live in Supabase.
The database and its security rules are already set up in the all-in-one-store project.

1. In Supabase, open Authentication, then Sign In / Providers, then Email. Turn OFF "Confirm email". Save.
2. Open the store, tap Account, create your own account with your phone number and a strong password.
3. In Supabase SQL Editor, run `supabase/make-admin.sql`. This makes your account the admin.
4. Sign in on the store again. You land in the admin panel.

Customers sign up the same way and only ever see the store.
