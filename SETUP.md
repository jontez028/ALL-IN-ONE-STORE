# All In One Store: setup notes

The store runs on GitHub Pages. Accounts, products, photos and orders live in Supabase.

Email confirmation is on. Customers sign up with an email, a phone number and a password,
then tap the link in the email we send before they can sign in.

Supabase settings needed (dashboard only):
1. Authentication > URL Configuration: set Site URL to the store address and add it under Redirect URLs.
2. Project Settings > Authentication > SMTP: switch on custom SMTP with a sender such as Brevo.
   Supabase's built-in email only reaches your own team and is limited to a few emails per hour.
3. Authentication > Sign In / Providers > Email: keep "Confirm email" on.

Making yourself admin: create your account, confirm the email, then run supabase/make-admin.sql with your email.
