-- RIF RDC 2026 — table et règles d'accès Supabase
-- À exécuter une seule fois dans Supabase > SQL Editor.
-- ATTENTION : ce tableau de bord fonctionne sans authentification.
-- Toute personne possédant l'adresse de dbc.html peut lire les inscriptions
-- et modifier leur statut de paiement avec la clé publique du projet.

create extension if not exists pgcrypto;

create table if not exists public.inscriptions (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  nom text not null check (char_length(btrim(nom)) between 2 and 120),
  fonction text not null check (char_length(btrim(fonction)) between 2 and 120),
  sexe text not null check (sexe in ('Homme', 'Femme')),
  telephone text not null check (char_length(btrim(telephone)) between 7 and 30),
  email text not null check (
    char_length(btrim(email)) between 3 and 150
    and btrim(email) ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ),
  paiement text not null default 'Non payé' check (paiement in ('Payé', 'Non payé')),
  status text not null default 'En attente' check (status in ('En attente', 'Confirmé')),
  created_at timestamptz not null default now()
);

alter table public.inscriptions enable row level security;

revoke all on table public.inscriptions from anon, authenticated;
grant insert, select on table public.inscriptions to anon, authenticated;
grant update (paiement, status) on table public.inscriptions to anon, authenticated;

-- Une adresse e-mail ne peut inscrire qu'une seule personne.
create unique index if not exists inscriptions_email_unique_idx
on public.inscriptions (lower(btrim(email)));

-- Normalise les textes avant validation et stockage.
create or replace function public.normalize_inscription()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.reference := upper(btrim(new.reference));
  new.nom := btrim(new.nom);
  new.fonction := btrim(new.fonction);
  new.telephone := btrim(new.telephone);
  new.email := lower(btrim(new.email));
  return new;
end;
$$;

drop trigger if exists normalize_inscription_before_write on public.inscriptions;
create trigger normalize_inscription_before_write
before insert or update on public.inscriptions
for each row execute function public.normalize_inscription();

-- Limite stricte et sûre même si plusieurs personnes s'inscrivent simultanément.
create or replace function public.enforce_inscription_capacity()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  perform pg_advisory_xact_lock(hashtext('rif-rdc-2026-inscription-capacity'));
  if (select count(*) from public.inscriptions) >= 2000 then
    raise exception using
      errcode = 'P0001',
      message = 'RIF_CAPACITY_REACHED';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_inscription_capacity_before_insert on public.inscriptions;
create trigger enforce_inscription_capacity_before_insert
before insert on public.inscriptions
for each row execute function public.enforce_inscription_capacity();

drop policy if exists "Inscription publique" on public.inscriptions;
create policy "Inscription publique"
on public.inscriptions
for insert
to anon
with check (paiement = 'Non payé' and status = 'En attente');

drop policy if exists "Administration lecture" on public.inscriptions;
create policy "Administration lecture"
on public.inscriptions
for select
to anon, authenticated
using (true);

drop policy if exists "Administration paiement" on public.inscriptions;
create policy "Administration paiement"
on public.inscriptions
for update
to anon, authenticated
using (true)
with check (
  paiement in ('Payé', 'Non payé')
  and status in ('En attente', 'Confirmé')
);

create index if not exists inscriptions_created_at_idx
on public.inscriptions (created_at desc);
