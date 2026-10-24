# All In One Store: admin setup

The store runs on GitHub Pages. Accounts, products, photos and orders live in Supabase.
You log in on the store itself. Your account opens the admin panel. Customers never see it.

1. Create a free project at supabase.com. Save the database password.
2. Open SQL Editor, paste all of `supabase/schema.sql`, press Run.
3. Open Authentication, then Sign In / Providers, then Email. Turn OFF "Confirm email". Save.
4. Open Project Settings, then API. Copy the Project URL and the anon public key into `config.js`.
5. Open the store, tap Account, create your own account with your phone number and a strong password.
6. Back in SQL Editor, paste `supabase/make-admin.sql` and press Run. This makes your account the admin.
7. Sign in on the store again. You land in the admin panel.

The anon key is meant to be public. The database rules decide who may change anything.
