-- Sélections sans plafond : un joueur peut recruter plus de 15 Miss (ou
-- choisir plus de 5 finalistes) ; l'huissier (mf_figer) exige toujours
-- le compte exact pour classer le dossier.
-- À exécuter une fois dans Supabase → SQL Editor (déjà inclus dans
-- miss-france.sql).
create or replace function public.mf_definir_statut(p_jeton uuid, p_candidate bigint, p_statut text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  v_j bigint;
  v_phase text;
begin
  select id into v_j from mf_joueurs where jeton = p_jeton;
  if v_j is null then raise exception 'Session invalide, reconnecte-toi.'; end if;
  if p_statut not in ('top15', 'top5', 'aucun') then
    raise exception 'Statut inconnu.';
  end if;
  select phase into v_phase from mf_config where id = 1;
  if exists (select 1 from mf_validations v where v.joueur_id = v_j and v.phase = v_phase) then
    raise exception 'Ton dossier est scellé chez l''huissier ! Récupère-le pour modifier.';
  end if;

  if v_phase = 'selection15' then
    if p_statut = 'top15' then
      -- Pas de plafond : on peut dépasser 15, l'huissier exige 15 pile.
      insert into mf_pronostics (joueur_id, candidate_id, statut)
        values (v_j, p_candidate, 'top15')
      on conflict (joueur_id, candidate_id) do update
        set statut = 'top15', modifie_le = now();
    elsif p_statut = 'aucun' then
      update mf_pronostics set statut = null, modifie_le = now()
        where joueur_id = v_j and candidate_id = p_candidate;
    else
      raise exception 'En phase 1, on compose son équipe de 15 !';
    end if;

  elsif v_phase = 'top5' then
    if p_statut = 'top5' then
      if not exists (select 1 from mf_candidates c where c.id = p_candidate and c.dans_top15) then
        raise exception 'Cette Miss n''est plus en lice — choisis parmi les 15 encore en course !';
      end if;
      -- Pas de plafond : on peut dépasser 5, l'huissier exige 5 pile.
      insert into mf_pronostics (joueur_id, candidate_id, top5)
        values (v_j, p_candidate, true)
      on conflict (joueur_id, candidate_id) do update
        set top5 = true, modifie_le = now();
    elsif p_statut = 'aucun' then
      update mf_pronostics set top5 = false, modifie_le = now()
        where joueur_id = v_j and candidate_id = p_candidate;
    else
      raise exception 'En phase 2, on choisit ses 5 parmi les 15 en lice !';
    end if;

  else
    raise exception 'Les sélections sont fermées dans la phase actuelle.';
  end if;

  delete from mf_pronostics
    where joueur_id = v_j and candidate_id = p_candidate
      and statut is null and not top5 and rang is null and essai is null;
end;
$$;
