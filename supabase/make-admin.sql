-- Run this AFTER you have created your own account on the store (phone number and password).
-- It makes that account the admin. Change the number if yours is different.
update public.profiles
set is_admin = true
where regexp_replace(phone, '\D', '', 'g') like '%745384430';

select name, phone, is_admin from public.profiles where is_admin;
