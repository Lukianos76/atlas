-- Triggers et droits (docs/schema.md, §1, §5.3 à §5.13 et §8.5). Toutes les fonctions
-- sont SECURITY INVOKER : `current_user` reste le rôle de connexion du contributeur.
-- Les refus portent un nom de contrainte (USING CONSTRAINT) pour être identifiés sans
-- ambiguïté par les appelants et les tests.

-- migrate:up

SET ROLE atlas_owner;

-- ---------------------------------------------------------------------------
-- Contributeur et contexte de la transaction (§5.11, §5.13)
-- ---------------------------------------------------------------------------

-- Le contributeur est celui du rôle de connexion, jamais une valeur déclarée.
CREATE FUNCTION current_contributor() RETURNS integer
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_id integer;
BEGIN
  SELECT id INTO v_id FROM contributor WHERE db_role = current_user;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'aucun contributeur pour le rôle %', current_user
      USING ERRCODE = 'insufficient_privilege', CONSTRAINT = 'contributor_required';
  END IF;
  RETURN v_id;
END
$$;

-- Variables déclaratives `SET LOCAL atlas.*` : elles ne confèrent aucun droit.
CREATE FUNCTION context_setting(p_name text) RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT nullif(current_setting('atlas.' || p_name, true), '')
$$;

-- ---------------------------------------------------------------------------
-- Rien n'est effacé (P7, §1) ; contenus immuables (§5.1, §5.2, §5.4, §5.9, §5.11)
-- ---------------------------------------------------------------------------

CREATE FUNCTION refuse_delete() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'suppression refusée sur % : rien n''est effacé (P7)', TG_TABLE_NAME
    USING ERRCODE = 'restrict_violation', CONSTRAINT = 'no_delete';
END
$$;

-- Un lien de citation ne se supprime que dans une transaction révisée, qui renseigne
-- son motif (E7) ; le contrôle différé vérifie qu'il reste une citation.
CREATE FUNCTION assertion_citation_before_delete() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF context_setting('reason') IS NULL THEN
    RAISE EXCEPTION 'suppression d''un lien de citation sans motif (atlas.reason)'
      USING ERRCODE = 'restrict_violation', CONSTRAINT = 'no_delete';
  END IF;
  RETURN OLD;
END
$$;

CREATE FUNCTION refuse_update() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'modification refusée sur % : contenu immuable', TG_TABLE_NAME
    USING ERRCODE = 'restrict_violation', CONSTRAINT = 'immutable_row';
END
$$;

-- ---------------------------------------------------------------------------
-- Garde des statuts (§5.13, modèle §10.1 version 3.2)
-- ---------------------------------------------------------------------------

-- p_old NULL : création. p_correction : le contenu a changé (retour en relecture).
CREATE FUNCTION check_review_status_transition(
  p_old review_status,
  p_new review_status,
  p_correction boolean
) RETURNS void
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  IF p_old IS NULL THEN
    IF p_new = 'proposed' THEN
      RETURN;
    END IF;
  ELSIF p_old = p_new THEN
    RETURN;
  ELSIF (p_old = 'validated' AND p_new = 'contested')
    OR (p_old = 'withdrawn' AND p_new = 'proposed')
    OR (p_old = 'validated' AND p_new = 'proposed' AND p_correction) THEN
    RETURN;
  ELSIF p_old IN ('proposed', 'contested') AND p_new IN ('validated', 'withdrawn') THEN
    IF pg_has_role(current_user, 'atlas_review', 'MEMBER') THEN
      RETURN;
    END IF;
    RAISE EXCEPTION 'passage de % à % réservé au rôle de vérification', p_old, p_new
      USING ERRCODE = 'insufficient_privilege', CONSTRAINT = 'review_status_guard';
  END IF;
  RAISE EXCEPTION 'transition de statut refusée : % → %', coalesce(p_old::text, 'création'), p_new
    USING ERRCODE = 'check_violation', CONSTRAINT = 'review_status_transition';
END
$$;

CREATE FUNCTION assertion_before_insert() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM check_review_status_transition(NULL, NEW.review_status, false);
  RETURN NEW;
END
$$;

-- Une correction du tronc d'une assertion validée la ramène à `proposed`. Une
-- correction du contenu de type passe par `assertion_content_corrected`, qui met à
-- jour le tronc depuis un trigger (profondeur > 1).
CREATE FUNCTION assertion_before_update() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_corrected boolean;
BEGIN
  v_corrected := (
    NEW.assertion_type, NEW.subject_entity_id, NEW.subject_event_id,
    NEW.subject_division_system_id, NEW.start_kind, NEW.start_earliest, NEW.start_latest,
    NEW.start_date_id, NEW.end_kind, NEW.end_earliest, NEW.end_latest, NEW.end_date_id,
    NEW.authority_entity_id, NEW.certainty, NEW.margin, NEW.opening_event_id,
    NEW.closing_event_id
  ) IS DISTINCT FROM (
    OLD.assertion_type, OLD.subject_entity_id, OLD.subject_event_id,
    OLD.subject_division_system_id, OLD.start_kind, OLD.start_earliest, OLD.start_latest,
    OLD.start_date_id, OLD.end_kind, OLD.end_earliest, OLD.end_latest, OLD.end_date_id,
    OLD.authority_entity_id, OLD.certainty, OLD.margin, OLD.opening_event_id,
    OLD.closing_event_id
  );
  IF v_corrected AND OLD.review_status = 'validated' AND NEW.review_status = 'validated' THEN
    NEW.review_status := 'proposed';
  END IF;
  PERFORM check_review_status_transition(
    OLD.review_status, NEW.review_status, v_corrected OR pg_trigger_depth() > 1
  );
  RETURN NEW;
END
$$;

-- Colonnes d'une table de type qui ne sont pas du contenu : identité et copies du tronc.
CREATE FUNCTION assertion_content_of(p_row jsonb) RETURNS jsonb
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT p_row - ARRAY['id', 'assertion_type', 'subject_entity_id', 'core_range', 'review_status']
$$;

-- Correction du contenu de type ou des liens de citation : retour en relecture.
CREATE FUNCTION assertion_content_corrected() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_id bigint;
BEGIN
  IF TG_TABLE_NAME = 'assertion_citation' THEN
    v_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.assertion_id ELSE NEW.assertion_id END;
  ELSIF assertion_content_of(to_jsonb(NEW)) IS DISTINCT FROM assertion_content_of(to_jsonb(OLD))
  THEN
    v_id := NEW.id;
  END IF;
  IF v_id IS NOT NULL THEN
    UPDATE assertion SET review_status = 'proposed'
    WHERE id = v_id AND review_status = 'validated';
  END IF;
  RETURN NULL;
END
$$;

-- ---------------------------------------------------------------------------
-- Copies du tronc et des dates (§5.4, §5.5)
-- ---------------------------------------------------------------------------

CREATE FUNCTION external_id_assertion_fill() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  SELECT a.subject_entity_id, a.core_range, a.review_status
  INTO NEW.subject_entity_id, NEW.core_range, NEW.review_status
  FROM assertion AS a
  WHERE a.id = NEW.id;
  RETURN NEW;
END
$$;

CREATE FUNCTION event_date_assertion_fill() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  SELECT d.earliest, d.latest INTO NEW.earliest, NEW.latest
  FROM historical_date AS d
  WHERE d.id = NEW.date_id;
  SELECT d.earliest, d.latest INTO NEW.end_earliest, NEW.end_latest
  FROM historical_date AS d
  WHERE d.id = NEW.end_date_id;
  RETURN NEW;
END
$$;

-- ---------------------------------------------------------------------------
-- Contrôles différés des assertions et des événements (D3, §5.3 à §5.5)
-- ---------------------------------------------------------------------------

CREATE FUNCTION check_assertion(p_id bigint) RETURNS void
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_assertion assertion;
  v_has_content boolean;
BEGIN
  SELECT * INTO v_assertion FROM assertion WHERE id = p_id;

  EXECUTE format(
    'SELECT EXISTS (SELECT FROM %I WHERE id = $1)', v_assertion.assertion_type || '_assertion'
  ) INTO v_has_content USING p_id;
  IF NOT v_has_content THEN
    RAISE EXCEPTION 'assertion % sans ligne dans %_assertion', p_id, v_assertion.assertion_type
      USING ERRCODE = 'check_violation', CONSTRAINT = 'assertion_requires_content';
  END IF;

  -- P3 : au moins une citation.
  IF NOT EXISTS (SELECT FROM assertion_citation WHERE assertion_id = p_id) THEN
    RAISE EXCEPTION 'assertion % sans citation (P3)', p_id
      USING ERRCODE = 'check_violation', CONSTRAINT = 'assertion_requires_citation';
  END IF;

  -- Autorité selon le type (modèle §5.6, A15).
  IF v_assertion.authority_entity_id IS NULL AND (
    v_assertion.assertion_type = 'legal_status'
    OR (
      v_assertion.assertion_type = 'name'
      AND EXISTS (SELECT FROM name_assertion WHERE id = p_id AND name_type = 'official')
    )
  ) THEN
    RAISE EXCEPTION 'assertion % : autorité obligatoire', p_id
      USING ERRCODE = 'check_violation', CONSTRAINT = 'assertion_authority';
  END IF;
  IF v_assertion.authority_entity_id IS NOT NULL
    AND v_assertion.assertion_type = 'system_membership' THEN
    RAISE EXCEPTION 'assertion % : l''autorité d''une appartenance se lit sur le système', p_id
      USING ERRCODE = 'check_violation', CONSTRAINT = 'assertion_authority';
  END IF;

  -- Une part renseignée exige une citation de rôle `share` (§5.5).
  IF EXISTS (SELECT FROM transfer_assertion WHERE id = p_id AND share IS NOT NULL)
    AND NOT EXISTS (
      SELECT FROM assertion_citation WHERE assertion_id = p_id AND citation_role = 'share'
    ) THEN
    RAISE EXCEPTION 'transfert % : part sans citation de rôle share', p_id
      USING ERRCODE = 'check_violation', CONSTRAINT = 'transfer_share_citation';
  END IF;
END
$$;

-- Identifiant de l'assertion visée par la ligne d'un trigger sur le tronc, une table
-- de type ou un lien de citation.
CREATE FUNCTION trigger_assertion_id(p_table name, p_row jsonb) RETURNS bigint
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_table = 'assertion_citation' THEN (p_row ->> 'assertion_id')::bigint
    ELSE (p_row ->> 'id')::bigint
  END
$$;

CREATE FUNCTION assertion_check() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM check_assertion(trigger_assertion_id(
    TG_TABLE_NAME, CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END
  ));
  RETURN NULL;
END
$$;

-- Un événement a au moins une assertion de date, quel que soit son statut (A4, N10).
CREATE FUNCTION event_check() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM assertion WHERE subject_event_id = NEW.id AND assertion_type = 'event_date'
  ) THEN
    RAISE EXCEPTION 'événement % sans assertion de date (A4)', NEW.id
      USING ERRCODE = 'check_violation', CONSTRAINT = 'event_requires_date';
  END IF;
  RETURN NULL;
END
$$;

-- ---------------------------------------------------------------------------
-- Révisions des assertions (D4, §5.11)
-- ---------------------------------------------------------------------------

-- Instantané : tronc, contenu de type, liens de citation. La géométrie, immuable,
-- n'est pas recopiée : l'identifiant de l'assertion la référence.
CREATE FUNCTION assertion_snapshot(p_id bigint) RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_assertion assertion;
  v_content jsonb;
  v_citations jsonb;
BEGIN
  SELECT * INTO v_assertion FROM assertion WHERE id = p_id;
  EXECUTE format(
    'SELECT to_jsonb(t) FROM %I AS t WHERE t.id = $1', v_assertion.assertion_type || '_assertion'
  ) INTO v_content USING p_id;
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object('citation_id', citation_id, 'citation_role', citation_role)
      ORDER BY citation_id, citation_role
    ),
    '[]'::jsonb
  ) INTO v_citations
  FROM assertion_citation
  WHERE assertion_id = p_id;
  RETURN jsonb_build_object(
    'assertion', to_jsonb(v_assertion) - ARRAY['end_latest_dated', 'core_range', 'max_range'],
    'content', assertion_content_of(v_content) - 'shape',
    'citations', v_citations
  );
END
$$;

-- Un lot n'accueille de nouvelles données que tant qu'il est `proposed`, et seulement
-- de son responsable (E13). Sans lot, rien à contrôler.
CREATE FUNCTION batch_open_to_caller(p_batch_id integer) RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT p_batch_id IS NULL OR EXISTS (
    SELECT FROM import_batch
    WHERE id = p_batch_id AND batch_status = 'proposed' AND owner_id = current_contributor()
  )
$$;

-- Au plus une révision par assertion et par transaction, écrite au commit ;
-- l'opération se déduit de l'instantané précédent (N9).
CREATE FUNCTION write_assertion_revision(p_id bigint) RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_snapshot jsonb;
  v_previous jsonb;
  v_operation operation;
BEGIN
  IF EXISTS (SELECT FROM revision WHERE assertion_id = p_id AND recorded_at = now()) THEN
    RETURN;
  END IF;
  v_snapshot := assertion_snapshot(p_id);
  SELECT snapshot INTO v_previous
  FROM revision
  WHERE assertion_id = p_id
  ORDER BY recorded_at DESC, id DESC
  LIMIT 1;
  IF v_previous IS NULL THEN
    v_operation := 'create';
  ELSIF v_previous = v_snapshot THEN
    RETURN;
  ELSIF (v_previous #- '{assertion,review_status}') = (v_snapshot #- '{assertion,review_status}')
  THEN
    v_operation := 'review_status_change';
  ELSE
    v_operation := 'correct';
  END IF;
  -- La révision de création fait l'appartenance au lot (E10) : on ne rattache une
  -- assertion qu'à son propre lot encore ouvert (E13).
  IF v_operation = 'create' AND NOT batch_open_to_caller(
    context_setting('import_batch_id')::integer
  ) THEN
    RAISE EXCEPTION 'assertion % : lot % fermé ou d''un autre contributeur', p_id,
      context_setting('import_batch_id')
      USING ERRCODE = 'insufficient_privilege', CONSTRAINT = 'assertion_batch_owner';
  END IF;
  INSERT INTO revision (
    operation, review_status, reason, import_batch_id, assertion_id, snapshot
  ) VALUES (
    v_operation,
    (v_snapshot -> 'assertion' ->> 'review_status')::review_status,
    context_setting('reason'),
    context_setting('import_batch_id')::integer,
    p_id,
    v_snapshot
  );
END
$$;

CREATE FUNCTION assertion_revision() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM write_assertion_revision(trigger_assertion_id(
    TG_TABLE_NAME, CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END
  ));
  RETURN NULL;
END
$$;

-- ---------------------------------------------------------------------------
-- Observations (D3, §5.8, §5.11, E5)
-- ---------------------------------------------------------------------------

-- Hors lot : au moins une citation, ou une dérivation interne avec au moins une entrée.
CREATE FUNCTION observation_check() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM observation_citation
    WHERE variable_id = NEW.variable_id AND observation_id = NEW.id
  ) AND NOT (
    EXISTS (
      SELECT FROM derivation WHERE id = NEW.derivation_id AND derivation_kind = 'internal'
    )
    AND EXISTS (
      SELECT FROM derivation_input
      WHERE variable_id = NEW.variable_id AND observation_id = NEW.id
    )
  ) THEN
    RAISE EXCEPTION 'observation % hors lot sans citation ni entrée de dérivation (P3)', NEW.id
      USING ERRCODE = 'check_violation', CONSTRAINT = 'observation_requires_source';
  END IF;
  RETURN NULL;
END
$$;

CREATE FUNCTION observation_snapshot(p_variable_id integer, p_id bigint) RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT
    to_jsonb(o)
    - ARRAY['reference_end_latest_dated', 'reference_core_range', 'reference_max_range']
    || jsonb_build_object(
      'citations',
      coalesce(
        (
          SELECT jsonb_agg(
            jsonb_build_object('citation_id', c.citation_id, 'citation_role', c.citation_role)
            ORDER BY c.citation_id, c.citation_role
          )
          FROM observation_citation AS c
          WHERE c.variable_id = o.variable_id AND c.observation_id = o.id
        ),
        '[]'::jsonb
      )
    )
  FROM observation AS o
  WHERE o.variable_id = p_variable_id AND o.id = p_id
$$;

-- Révision individuelle d'une observation : à la création hors lot (au commit) et à
-- chaque mise à jour. Le statut demandé vient de `set_observation_review_status` ;
-- à défaut, une correction ramène une observation validée à `proposed`.
CREATE FUNCTION observation_revision() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_previous review_status;
  v_requested review_status;
  v_operation operation;
  v_status review_status;
BEGIN
  v_previous := observation_review_status(NEW.variable_id, NEW.id);
  IF TG_OP = 'INSERT' THEN
    IF EXISTS (
      SELECT FROM revision
      WHERE observation_variable_id = NEW.variable_id AND observation_id = NEW.id
    ) THEN
      RETURN NULL;
    END IF;
    v_operation := 'create';
    v_status := 'proposed';
  ELSE
    v_requested := context_setting('review_status')::review_status;
    IF v_previous IS NULL THEN
      v_operation := 'create';
      v_status := coalesce(v_requested, 'proposed');
    ELSIF to_jsonb(NEW) = to_jsonb(OLD) THEN
      IF v_requested IS NULL THEN
        RETURN NULL;
      END IF;
      v_operation := 'review_status_change';
      v_status := v_requested;
    ELSE
      v_operation := 'correct';
      v_status := coalesce(
        v_requested,
        CASE WHEN v_previous = 'validated' THEN 'proposed'::review_status ELSE v_previous END
      );
    END IF;
  END IF;
  INSERT INTO revision (
    operation, review_status, reason, import_batch_id, observation_variable_id, observation_id,
    snapshot
  ) VALUES (
    v_operation,
    v_status,
    context_setting('reason'),
    context_setting('import_batch_id')::integer,
    NEW.variable_id,
    NEW.id,
    observation_snapshot(NEW.variable_id, NEW.id)
  );
  RETURN NULL;
END
$$;

-- Appartenance d'une observation à un lot (E13) : à l'insertion, son propre lot encore
-- ouvert ; ensuite, figée. Contrôle par instruction, sur les tables de transition :
-- une insertion par lot n'appelle aucune fonction ligne par ligne (ADR 0003).
CREATE FUNCTION observation_batch_guard() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_batch_id integer;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF EXISTS (
      SELECT FROM old_rows AS o JOIN new_rows AS n USING (variable_id, id)
      WHERE n.import_batch_id IS DISTINCT FROM o.import_batch_id
    ) THEN
      RAISE EXCEPTION 'le lot d''une observation est figé'
        USING ERRCODE = 'restrict_violation', CONSTRAINT = 'observation_batch_frozen';
    END IF;
    RETURN NULL;
  END IF;
  FOR v_batch_id IN
    SELECT DISTINCT import_batch_id FROM new_rows WHERE import_batch_id IS NOT NULL
  LOOP
    IF NOT batch_open_to_caller(v_batch_id) THEN
      RAISE EXCEPTION 'lot % fermé ou d''un autre contributeur', v_batch_id
        USING ERRCODE = 'insufficient_privilege', CONSTRAINT = 'observation_batch_owner';
    END IF;
  END LOOP;
  RETURN NULL;
END
$$;

-- Changement de statut d'une observation sans changement de contenu (E5). La mise à
-- jour sans effet reste interne à la fonction ; la garde s'applique à la révision.
CREATE FUNCTION set_observation_review_status(
  p_variable_id integer,
  p_observation_id bigint,
  p_review_status review_status,
  p_reason text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('atlas.review_status', p_review_status::text, true);
  IF p_reason IS NOT NULL THEN
    PERFORM set_config('atlas.reason', p_reason, true);
  END IF;
  UPDATE observation SET value = value
  WHERE variable_id = p_variable_id AND id = p_observation_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'observation (%, %) introuvable', p_variable_id, p_observation_id
      USING ERRCODE = 'no_data_found';
  END IF;
  PERFORM set_config('atlas.review_status', '', true);
END
$$;

-- ---------------------------------------------------------------------------
-- Lots d'import (§5.10, E4, E10)
-- ---------------------------------------------------------------------------

CREATE FUNCTION import_batch_before_insert() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.owner_id := current_contributor();
  NEW.recorded_at := now();
  NEW.reviewer_id := NULL;
  NEW.reviewer_kind := NULL;
  IF NEW.batch_status <> 'proposed' THEN
    RAISE EXCEPTION 'un lot est créé au statut proposed'
      USING ERRCODE = 'check_violation', CONSTRAINT = 'batch_status_transition';
  END IF;
  RETURN NEW;
END
$$;

-- Procédure et périmètre figés à la création ; rapport figé à la décision ; décision
-- réservée au rôle de vérification, qui devient le vérificateur.
CREATE FUNCTION import_batch_before_update() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (NEW.citation_id, NEW.owner_id, NEW.recorded_at, NEW.procedure, NEW.scope)
    IS DISTINCT FROM (OLD.citation_id, OLD.owner_id, OLD.recorded_at, OLD.procedure, OLD.scope)
  THEN
    RAISE EXCEPTION 'lot % : citation, responsable, procédure et périmètre sont figés', OLD.id
      USING ERRCODE = 'restrict_violation', CONSTRAINT = 'batch_frozen';
  END IF;
  IF OLD.batch_status <> 'proposed'
    AND NEW.validation_report IS DISTINCT FROM OLD.validation_report THEN
    RAISE EXCEPTION 'lot % : rapport de validation figé après la décision', OLD.id
      USING ERRCODE = 'restrict_violation', CONSTRAINT = 'batch_frozen';
  END IF;
  IF NEW.batch_status IS DISTINCT FROM OLD.batch_status THEN
    IF OLD.batch_status <> 'proposed' OR NEW.batch_status = 'proposed' THEN
      RAISE EXCEPTION 'lot % : transition refusée : % → %', OLD.id, OLD.batch_status,
        NEW.batch_status
        USING ERRCODE = 'check_violation', CONSTRAINT = 'batch_status_transition';
    END IF;
    IF NOT pg_has_role(current_user, 'atlas_review', 'MEMBER') THEN
      RAISE EXCEPTION 'lot % : décision réservée au rôle de vérification', OLD.id
        USING ERRCODE = 'insufficient_privilege', CONSTRAINT = 'batch_status_guard';
    END IF;
    NEW.reviewer_id := current_contributor();
    SELECT contributor_kind INTO NEW.reviewer_kind FROM contributor WHERE id = NEW.reviewer_id;
  ELSE
    NEW.reviewer_id := OLD.reviewer_id;
    NEW.reviewer_kind := OLD.reviewer_kind;
  END IF;
  RETURN NEW;
END
$$;

-- Révision du lot ; la validation passe à `validated` les assertions du lot encore
-- proposées, retrouvées par leur révision de création (E10).
CREATE FUNCTION import_batch_after_write() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.batch_status = OLD.batch_status THEN
    RETURN NULL;
  END IF;
  INSERT INTO revision (operation, batch_status, reason, import_batch_id)
  VALUES (
    CASE WHEN TG_OP = 'INSERT' THEN 'create' ELSE 'review_status_change' END::operation,
    NEW.batch_status,
    context_setting('reason'),
    NEW.id
  );
  IF NEW.batch_status = 'validated' THEN
    PERFORM set_config('atlas.import_batch_id', NEW.id::text, true);
    UPDATE assertion SET review_status = 'validated'
    WHERE review_status = 'proposed'
      AND id IN (
        SELECT assertion_id FROM revision
        WHERE import_batch_id = NEW.id AND operation = 'create' AND assertion_id IS NOT NULL
      );
  END IF;
  RETURN NULL;
END
$$;

-- ---------------------------------------------------------------------------
-- Horodatage et contributeur fixés (§5.9, §5.11)
-- ---------------------------------------------------------------------------

CREATE FUNCTION derivation_before_insert() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.contributor_id := current_contributor();
  NEW.recorded_at := now();
  RETURN NEW;
END
$$;

-- `revision` ne reçoit que des lignes écrites par les triggers ; garde des statuts
-- des observations (§5.13).
CREATE FUNCTION revision_before_insert() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF pg_trigger_depth() < 2 THEN
    RAISE EXCEPTION 'insertion directe dans revision refusée : les révisions sont écrites par les triggers'
      USING ERRCODE = 'insufficient_privilege', CONSTRAINT = 'revision_trigger_only';
  END IF;
  NEW.contributor_id := current_contributor();
  NEW.recorded_at := now();
  IF NEW.observation_id IS NOT NULL THEN
    PERFORM check_review_status_transition(
      observation_review_status(NEW.observation_variable_id, NEW.observation_id),
      NEW.review_status,
      NEW.operation = 'correct'
    );
  END IF;
  RETURN NEW;
END
$$;

-- ---------------------------------------------------------------------------
-- Déclaration des triggers
-- ---------------------------------------------------------------------------

-- Refus de suppression et de troncature sur toutes les tables du schéma (§1, E8). Les
-- triggers de ligne d'une table partitionnée sont clonés sur ses partitions ; ceux de
-- troncature, par instruction, sont posés sur chaque table.
DO $$
DECLARE
  v_table record;
BEGIN
  FOR v_table IN
    SELECT c.relname, c.relispartition
    FROM pg_class AS c
    JOIN pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p')
      AND c.relowner = 'atlas_owner'::regrole
  LOOP
    IF NOT v_table.relispartition AND v_table.relname <> 'assertion_citation' THEN
      EXECUTE format(
        'CREATE TRIGGER no_delete BEFORE DELETE ON %I FOR EACH ROW EXECUTE FUNCTION refuse_delete()',
        v_table.relname
      );
    END IF;
    EXECUTE format(
      'CREATE TRIGGER no_truncate BEFORE TRUNCATE ON %I '
      'FOR EACH STATEMENT EXECUTE FUNCTION refuse_delete()',
      v_table.relname
    );
  END LOOP;
END
$$;

CREATE TRIGGER no_delete BEFORE DELETE ON assertion_citation
  FOR EACH ROW EXECUTE FUNCTION assertion_citation_before_delete();

-- Contenus immuables.
DO $$
DECLARE
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'entity', 'event', 'historical_date', 'citation', 'geometry_assertion', 'derivation',
    'derivation_input', 'crosswalk', 'crosswalk_transfer', 'revision'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER immutable BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION refuse_update()',
      v_table
    );
  END LOOP;
END
$$;

-- Tronc des assertions.
CREATE TRIGGER status_guard_insert BEFORE INSERT ON assertion
  FOR EACH ROW EXECUTE FUNCTION assertion_before_insert();
CREATE TRIGGER status_guard_update BEFORE UPDATE ON assertion
  FOR EACH ROW EXECUTE FUNCTION assertion_before_update();

-- Copies.
CREATE TRIGGER fill_trunk_copy BEFORE INSERT ON external_id_assertion
  FOR EACH ROW EXECUTE FUNCTION external_id_assertion_fill();
CREATE TRIGGER fill_date_copy BEFORE INSERT OR UPDATE OF date_id, end_date_id
  ON event_date_assertion
  FOR EACH ROW EXECUTE FUNCTION event_date_assertion_fill();

-- Contrôle différé et révision au commit, sur le tronc, les tables de type et les liens
-- de citation ; retour en relecture quand le contenu ou les citations changent.
CREATE CONSTRAINT TRIGGER assertion_check AFTER INSERT OR UPDATE ON assertion
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION assertion_check();
CREATE CONSTRAINT TRIGGER assertion_revision AFTER INSERT OR UPDATE ON assertion
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION assertion_revision();

CREATE CONSTRAINT TRIGGER assertion_check AFTER INSERT OR DELETE ON assertion_citation
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION assertion_check();
CREATE CONSTRAINT TRIGGER assertion_revision AFTER INSERT OR DELETE ON assertion_citation
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION assertion_revision();
CREATE TRIGGER content_corrected AFTER INSERT OR DELETE ON assertion_citation
  FOR EACH ROW EXECUTE FUNCTION assertion_content_corrected();

DO $$
DECLARE
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'name_assertion', 'external_id_assertion', 'legal_status_assertion',
    'system_membership_assertion', 'relation_assertion', 'geometry_assertion',
    'system_validity_assertion', 'event_type_assertion', 'event_date_assertion',
    'participation_assertion', 'transfer_assertion'
  ] LOOP
    EXECUTE format(
      'CREATE CONSTRAINT TRIGGER assertion_check AFTER INSERT OR UPDATE ON %I '
      'DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION assertion_check()',
      v_table
    );
    EXECUTE format(
      'CREATE CONSTRAINT TRIGGER assertion_revision AFTER INSERT OR UPDATE ON %I '
      'DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION assertion_revision()',
      v_table
    );
    EXECUTE format(
      'CREATE TRIGGER content_corrected AFTER UPDATE ON %I '
      'FOR EACH ROW EXECUTE FUNCTION assertion_content_corrected()',
      v_table
    );
  END LOOP;
END
$$;

-- Événements.
CREATE CONSTRAINT TRIGGER event_check AFTER INSERT ON event
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION event_check();

-- Observations : contrôle et révision de création hors lot seulement ; une insertion
-- par lot n'appelle aucune fonction ligne par ligne (ADR 0003).
CREATE CONSTRAINT TRIGGER observation_check AFTER INSERT OR UPDATE ON observation
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW WHEN (NEW.import_batch_id IS NULL)
  EXECUTE FUNCTION observation_check();
CREATE CONSTRAINT TRIGGER observation_revision_insert AFTER INSERT ON observation
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW WHEN (NEW.import_batch_id IS NULL)
  EXECUTE FUNCTION observation_revision();
CREATE TRIGGER observation_revision_update AFTER UPDATE ON observation
  FOR EACH ROW EXECUTE FUNCTION observation_revision();
CREATE TRIGGER batch_guard_insert AFTER INSERT ON observation
  REFERENCING NEW TABLE AS new_rows
  FOR EACH STATEMENT EXECUTE FUNCTION observation_batch_guard();
CREATE TRIGGER batch_guard_update AFTER UPDATE ON observation
  REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
  FOR EACH STATEMENT EXECUTE FUNCTION observation_batch_guard();

-- Lots.
CREATE TRIGGER fixed_columns BEFORE INSERT ON import_batch
  FOR EACH ROW EXECUTE FUNCTION import_batch_before_insert();
CREATE TRIGGER status_guard BEFORE UPDATE ON import_batch
  FOR EACH ROW EXECUTE FUNCTION import_batch_before_update();
CREATE TRIGGER batch_revision AFTER INSERT OR UPDATE OF batch_status ON import_batch
  FOR EACH ROW EXECUTE FUNCTION import_batch_after_write();

-- Dérivations et révisions.
CREATE TRIGGER fixed_columns BEFORE INSERT ON derivation
  FOR EACH ROW EXECUTE FUNCTION derivation_before_insert();
CREATE TRIGGER fixed_columns BEFORE INSERT ON revision
  FOR EACH ROW EXECUTE FUNCTION revision_before_insert();

-- ---------------------------------------------------------------------------
-- Droits des rôles de groupe (§5.13)
-- ---------------------------------------------------------------------------

-- Lecture de tout.
DO $$
DECLARE
  v_relation text;
BEGIN
  FOR v_relation IN
    SELECT c.relname
    FROM pg_class AS c
    JOIN pg_namespace AS n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind IN ('r', 'p', 'v')
      AND c.relowner = 'atlas_owner'::regrole
  LOOP
    EXECUTE format('GRANT SELECT ON %I TO atlas_import', v_relation);
  END LOOP;
END
$$;

-- Insertion des entités, événements, assertions, citations, dates, œuvres,
-- observations, dérivations, lots ; `revision` ne reçoit que les écritures des
-- triggers, qui s'exécutent avec les droits du contributeur.
GRANT INSERT ON
  entity, event, historical_date, source_work, citation,
  assertion, assertion_citation,
  name_assertion, external_id_assertion, legal_status_assertion, system_membership_assertion,
  relation_assertion, geometry_assertion, system_validity_assertion,
  event_type_assertion, event_date_assertion, participation_assertion, transfer_assertion,
  observation, observation_citation, derivation, derivation_input, crosswalk, crosswalk_transfer,
  import_batch, revision
TO atlas_import;

-- Correction et contestation ; les contenus immuables sont refusés par leurs triggers.
GRANT UPDATE ON
  assertion,
  name_assertion, external_id_assertion, legal_status_assertion, system_membership_assertion,
  relation_assertion, geometry_assertion, system_validity_assertion,
  event_type_assertion, event_date_assertion, participation_assertion, transfer_assertion,
  observation, import_batch
TO atlas_import;

-- Seule exception au refus des suppressions : un lien de citation, dans une
-- transaction révisée (§5.3, E7).
GRANT DELETE ON assertion_citation TO atlas_import;

RESET ROLE;

-- Le rôle de vérification a les droits du rôle d'import ; ses décisions sont
-- contrôlées par la garde des statuts. Accorder l'appartenance à un rôle exige le
-- superutilisateur.
GRANT atlas_import TO atlas_review;

-- migrate:down
-- Migrations en avant uniquement (ADR 0010) : cette section reste vide.
