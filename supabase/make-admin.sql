-- Run this AFTER you have created your account on the store and confirmed your email.
-- Replace the address below with the email you used, then press Run.
update public.profiles
set is_admin = true
where id = (select id from auth.users where lower(email) = lower('YOUR-EMAIL@example.com'));

select name, email, is_admin from public.profiles where is_admin;
