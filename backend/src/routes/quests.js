const { Router } = require('express');
const multer = require('multer');

const supabase = require('../lib/supabase');
const requireAdmin = require('../middleware/requireAdmin');
const { distanceInMeters, isValidLatitude, isValidLongitude } = require('../lib/distance');
const { detectImageType } = require('../lib/imageType');

const router = Router();

const QUEST_SELECT_WITH_STEPS = '*, steps:quest_steps(id, position, description)';
const PROOF_PHOTO_BUCKET = 'quest-proofs';
const PROOF_PHOTO_MAX_SIZE_IN_BYTES = 5 * 1024 * 1024;

// Codes d'erreur Postgres renvoyés par Supabase.
const POSTGRES_INVALID_TEXT_REPRESENTATION = '22P02'; // id qui n'est pas un UUID
const POSTGRES_NO_DATA_FOUND = 'P0002'; // levé par insert_quest_step / delete_quest_step
const POSTGRES_INVALID_PARAMETER_VALUE = '22023'; // position d'étape hors bornes

function isInvalidIdError(supabaseError) {
  return supabaseError?.code === POSTGRES_INVALID_TEXT_REPRESENTATION;
}

function sortStepsByPosition(steps) {
  return [...(steps ?? [])].sort((firstStep, secondStep) => firstStep.position - secondStep.position);
}

// Ajoute à chaque quête son statut pour le joueur connecté
// (available, location_verified ou completed) et trie ses étapes.
async function withUserProgress(quests, userId) {
  const { data: completions, error } = await supabase
    .from('quest_completions')
    .select('quest_id, status')
    .eq('user_id', userId);
  if (error) throw error;

  const statusByQuestId = new Map(completions.map((completion) => [completion.quest_id, completion.status]));
  return quests.map((quest) => ({
    ...quest,
    steps: sortStepsByPosition(quest.steps),
    status: statusByQuestId.get(quest.id) ?? 'available',
  }));
}

async function findUserCompletion(userId, questId) {
  return supabase
    .from('quest_completions')
    .select('id, status')
    .eq('user_id', userId)
    .eq('quest_id', questId)
    .maybeSingle();
}

// ============================================================================
// Lecture des quêtes
// ============================================================================

// GET /api/quests
// Supports optional viewport/category filtering for the interactive map:
//   ?minLat=&maxLat=&minLng=&maxLng=  -> only quests inside the map bounding box
//   ?category=histoire                -> only quests of that category
router.get('/', async (req, res) => {
  const { minLat, maxLat, minLng, maxLng, category } = req.query;

  let query = supabase.from('quests').select(QUEST_SELECT_WITH_STEPS);

  if (minLat) query = query.gte('lat', Number(minLat));
  if (maxLat) query = query.lte('lat', Number(maxLat));
  if (minLng) query = query.gte('lng', Number(minLng));
  if (maxLng) query = query.lte('lng', Number(maxLng));
  if (category) query = query.eq('category', category);

  try {
    const { data: quests, error } = await query;
    if (error) throw error;
    res.json(await withUserProgress(quests, req.user.id));
  } catch (error) {
    res.status(500).json({ error: 'Impossible de charger les quêtes' });
  }
});

router.post('/', requireAdmin, async (req, res) => {
  const { data, error } = await supabase.from('quests').insert(req.body).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json(data);
});

router.get('/:id', async (req, res) => {
  try {
    const { data: quest, error } = await supabase
      .from('quests')
      .select(QUEST_SELECT_WITH_STEPS)
      .eq('id', req.params.id)
      .maybeSingle();
    if (error && !isInvalidIdError(error)) throw error;
    if (!quest) return res.status(404).json({ error: 'Quête introuvable' });

    const [questWithProgress] = await withUserProgress([quest], req.user.id);
    res.json(questWithProgress);
  } catch (error) {
    res.status(500).json({ error: 'Impossible de charger la quête' });
  }
});

router.patch('/:id', requireAdmin, async (req, res) => {
  const { data, error } = await supabase.from('quests').update(req.body).eq('id', req.params.id).select().single();
  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
});

router.delete('/:id', requireAdmin, async (req, res) => {
  const { error } = await supabase.from('quests').delete().eq('id', req.params.id);
  if (error) return res.status(400).json({ error: error.message });
  res.status(204).send();
});

// ============================================================================
// Roadmap : étapes d'une quête (admin)
// ============================================================================

function isNonEmptyText(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function sendStepFunctionError(res, error) {
  if (error.code === POSTGRES_NO_DATA_FOUND || isInvalidIdError(error)) {
    return res.status(404).json({ error: 'Quête ou étape introuvable' });
  }
  if (error.code === POSTGRES_INVALID_PARAMETER_VALUE) {
    return res.status(400).json({ error: 'Position d\'étape invalide' });
  }
  return res.status(500).json({ error: 'Impossible de modifier la roadmap' });
}

// POST /api/quests/:id/steps  { description, position? }
// Sans position, l'étape est ajoutée à la fin ; sinon les étapes suivantes sont décalées.
router.post('/:id/steps', requireAdmin, async (req, res) => {
  const { description, position } = req.body ?? {};
  if (!isNonEmptyText(description)) {
    return res.status(400).json({ error: 'La description de l\'étape est obligatoire' });
  }
  if (position !== undefined && !Number.isInteger(position)) {
    return res.status(400).json({ error: 'La position doit être un nombre entier' });
  }

  try {
    const { data: insertedStep, error } = await supabase.rpc('insert_quest_step', {
      target_quest_id: req.params.id,
      step_description: description,
      requested_position: position ?? null,
    });
    if (error) return sendStepFunctionError(res, error);
    res.status(201).json(insertedStep);
  } catch (error) {
    res.status(500).json({ error: 'Impossible de modifier la roadmap' });
  }
});

// PATCH /api/quests/:id/steps/:stepId  { description }
router.patch('/:id/steps/:stepId', requireAdmin, async (req, res) => {
  const { description } = req.body ?? {};
  if (!isNonEmptyText(description)) {
    return res.status(400).json({ error: 'La description de l\'étape est obligatoire' });
  }

  try {
    const { data: updatedStep, error } = await supabase
      .from('quest_steps')
      .update({ description: description.trim() })
      .eq('id', req.params.stepId)
      .eq('quest_id', req.params.id)
      .select()
      .maybeSingle();
    if (error && !isInvalidIdError(error)) throw error;
    if (!updatedStep) return res.status(404).json({ error: 'Étape introuvable' });
    res.json(updatedStep);
  } catch (error) {
    res.status(500).json({ error: 'Impossible de modifier la roadmap' });
  }
});

// DELETE /api/quests/:id/steps/:stepId  — les étapes suivantes remontent d'un cran.
router.delete('/:id/steps/:stepId', requireAdmin, async (req, res) => {
  try {
    const { error } = await supabase.rpc('delete_quest_step', {
      target_quest_id: req.params.id,
      target_step_id: req.params.stepId,
    });
    if (error) return sendStepFunctionError(res, error);
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ error: 'Impossible de modifier la roadmap' });
  }
});

// ============================================================================
// Validation par le joueur : position GPS, puis photo de preuve
// ============================================================================

// POST /api/quests/:id/verify-location  { latitude, longitude }
// Compare la position du joueur au point de validation de la quête.
router.post('/:id/verify-location', async (req, res) => {
  const { latitude, longitude } = req.body ?? {};
  if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) {
    return res.status(400).json({ error: 'Position GPS invalide' });
  }

  try {
    const { data: quest, error: questError } = await supabase
      .from('quests')
      .select('id, lat, lng, validation_radius_meters')
      .eq('id', req.params.id)
      .maybeSingle();
    if (questError && !isInvalidIdError(questError)) throw questError;
    if (!quest) return res.status(404).json({ error: 'Quête introuvable' });

    const distanceToValidationPoint = Math.round(
      distanceInMeters({ latitude, longitude }, { latitude: quest.lat, longitude: quest.lng }),
    );

    if (distanceToValidationPoint > quest.validation_radius_meters) {
      return res.status(422).json({
        error: 'Tu es trop loin du point de validation',
        code: 'too_far',
        distance_meters: distanceToValidationPoint,
        radius_meters: quest.validation_radius_meters,
      });
    }

    const { data: existingCompletion, error: completionError } = await findUserCompletion(req.user.id, quest.id);
    if (completionError) throw completionError;
    // Une quête déjà terminée n'est jamais rétrogradée.
    if (existingCompletion?.status === 'completed') {
      return res.json({ status: 'completed', distance_meters: distanceToValidationPoint });
    }

    const { error: upsertError } = await supabase.from('quest_completions').upsert(
      {
        user_id: req.user.id,
        quest_id: quest.id,
        status: 'location_verified',
        location_distance_meters: distanceToValidationPoint,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id,quest_id' },
    );
    if (upsertError) throw upsertError;

    res.json({ status: 'location_verified', distance_meters: distanceToValidationPoint });
  } catch (error) {
    res.status(500).json({ error: 'Impossible de vérifier ta position' });
  }
});

const proofPhotoUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: PROOF_PHOTO_MAX_SIZE_IN_BYTES, files: 1 },
});

function receiveProofPhoto(req, res, next) {
  proofPhotoUpload.single('photo')(req, res, (uploadError) => {
    if (!uploadError) return next();
    if (uploadError instanceof multer.MulterError && uploadError.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({ error: 'La photo dépasse 5 Mo' });
    }
    return res.status(400).json({ error: 'Photo invalide' });
  });
}

// POST /api/quests/:id/proof-photo  (multipart/form-data, champ « photo »)
// Exige une position vérifiée. L'envoi de la photo termine la quête ; la
// vérification de la photo par IA viendra se brancher ici plus tard.
router.post('/:id/proof-photo', receiveProofPhoto, async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Photo manquante' });

  const imageType = detectImageType(req.file.buffer);
  if (!imageType) {
    return res.status(400).json({ error: 'Format de photo non accepté (JPEG, PNG, WebP ou HEIC)' });
  }

  try {
    const { data: completion, error: completionError } = await findUserCompletion(req.user.id, req.params.id);
    if (completionError && !isInvalidIdError(completionError)) throw completionError;
    if (!completion) {
      return res.status(409).json({
        error: 'Valide d\'abord ta position au point d\'arrivée',
        code: 'location_not_verified',
      });
    }
    if (completion.status === 'completed') {
      return res.status(409).json({ error: 'Cette quête est déjà terminée', code: 'already_completed' });
    }

    // Le quest_id vient de la ligne de validation existante : c'est un UUID valide.
    const proofPhotoPath = `${req.user.id}/${req.params.id}.${imageType.extension}`;
    const { error: uploadError } = await supabase.storage
      .from(PROOF_PHOTO_BUCKET)
      .upload(proofPhotoPath, req.file.buffer, { contentType: imageType.contentType, upsert: true });
    if (uploadError) throw uploadError;

    const { error: updateError } = await supabase
      .from('quest_completions')
      .update({ status: 'completed', proof_photo_path: proofPhotoPath, updated_at: new Date().toISOString() })
      .eq('id', completion.id);
    if (updateError) throw updateError;

    res.json({ status: 'completed' });
  } catch (error) {
    res.status(500).json({ error: 'Impossible d\'enregistrer ta photo' });
  }
});

module.exports = router;
