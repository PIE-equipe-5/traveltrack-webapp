const { Router } = require('express');
const multer = require('multer');

const supabase = require('../lib/supabase');
const requireAdmin = require('../middleware/requireAdmin');
const { distanceInMeters, isValidLatitude, isValidLongitude } = require('../lib/distance');
const { detectImageType } = require('../lib/imageType');
const { parseQuestStepInput } = require('../lib/questStepInput');

const router = Router();

const STEP_FIELDS = 'id, step_number, title, description, lat, lng, validation_radius_meters';
const QUEST_SELECT_WITH_STEPS = `*, steps:quest_steps(${STEP_FIELDS})`;
const PROOF_PHOTO_BUCKET = 'quest-proofs';
const PROOF_PHOTO_MAX_SIZE_IN_BYTES = 5 * 1024 * 1024;

// Codes d'erreur Postgres renvoyés par Supabase.
const POSTGRES_INVALID_TEXT_REPRESENTATION = '22P02'; // id qui n'est pas un UUID
const POSTGRES_NO_DATA_FOUND = 'P0002'; // levé par insert_quest_step / delete_quest_step
const POSTGRES_INVALID_PARAMETER_VALUE = '22023'; // numéro d'étape hors bornes

const EDITABLE_QUEST_FIELDS = [
  'title',
  'category',
  'description',
  'start_address',
  'image_url',
  'lat',
  'lng',
  'validation_radius_meters',
  'xp',
];

function isInvalidIdError(supabaseError) {
  return supabaseError?.code === POSTGRES_INVALID_TEXT_REPRESENTATION;
}

function sortStepsByStepNumber(steps) {
  return [...(steps ?? [])].sort((firstStep, secondStep) => firstStep.step_number - secondStep.step_number);
}

function pickEditableQuestFields(requestBody) {
  return Object.fromEntries(
    EDITABLE_QUEST_FIELDS.filter((fieldName) => requestBody?.[fieldName] !== undefined)
      .map((fieldName) => [fieldName, requestBody[fieldName]]),
  );
}

function sendInvalidCoordinates(res) {
  return res.status(400).json({ error: 'Position GPS invalide' });
}

// ============================================================================
// Progression du joueur
// ============================================================================

// Statut d'une quête pour le joueur :
//   available          rien de validé
//   in_progress        une partie des étapes validée
//   location_verified  arrivée validée (dernière étape) : il reste la photo
//   completed          photo envoyée
async function withUserProgress(quests, userId) {
  const [questCompletionsResult, stepCompletionsResult] = await Promise.all([
    supabase.from('quest_completions').select('quest_id, status').eq('user_id', userId),
    supabase.from('quest_step_completions').select('step_id').eq('user_id', userId),
  ]);
  if (questCompletionsResult.error) throw questCompletionsResult.error;
  if (stepCompletionsResult.error) throw stepCompletionsResult.error;

  const questStatusByQuestId = new Map(
    questCompletionsResult.data.map((completion) => [completion.quest_id, completion.status]),
  );
  const completedStepIds = new Set(stepCompletionsResult.data.map((completion) => completion.step_id));

  return quests.map((quest) => {
    const steps = sortStepsByStepNumber(quest.steps).map((step) => ({
      ...step,
      is_completed: completedStepIds.has(step.id),
    }));
    const completedStepCount = steps.filter((step) => step.is_completed).length;
    const storedStatus = questStatusByQuestId.get(quest.id);

    return {
      ...quest,
      steps,
      completed_step_count: completedStepCount,
      status: storedStatus ?? (completedStepCount > 0 ? 'in_progress' : 'available'),
    };
  });
}

async function findUserCompletion(userId, questId) {
  return supabase
    .from('quest_completions')
    .select('id, status')
    .eq('user_id', userId)
    .eq('quest_id', questId)
    .maybeSingle();
}

// Arrivée validée : la photo de preuve est débloquée.
async function markQuestLocationVerified(userId, questId, distanceToValidationPoint) {
  const { error } = await supabase.from('quest_completions').upsert(
    {
      user_id: userId,
      quest_id: questId,
      status: 'location_verified',
      location_distance_meters: distanceToValidationPoint,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id,quest_id' },
  );
  if (error) throw error;
}

function measureDistanceToPoint(playerPosition, targetPoint) {
  return Math.round(distanceInMeters(playerPosition, { latitude: targetPoint.lat, longitude: targetPoint.lng }));
}

function sendTooFar(res, distanceToValidationPoint, radiusInMeters) {
  return res.status(422).json({
    error: 'Tu es trop loin du point de validation',
    code: 'too_far',
    distance_meters: distanceToValidationPoint,
    radius_meters: radiusInMeters,
  });
}

// ============================================================================
// Lecture et gestion des quêtes
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

// POST /api/quests  { title, category, start_address, lat, lng, ..., steps?: [étape, ...] }
// Chaque étape : { title, description, lat, lng, validation_radius_meters? }, dans
// l'ordre de la roadmap. Si les étapes ne peuvent pas être enregistrées, la quête
// est supprimée pour ne pas la laisser sans roadmap.
router.post('/', requireAdmin, async (req, res) => {
  const stepInputs = req.body?.steps ?? [];
  if (!Array.isArray(stepInputs)) {
    return res.status(400).json({ error: 'Les étapes doivent être une liste' });
  }

  const parsedSteps = [];
  for (const [stepIndex, stepInput] of stepInputs.entries()) {
    const { stepFields, errorMessage } = parseQuestStepInput(stepInput);
    if (errorMessage) return res.status(400).json({ error: `Étape ${stepIndex + 1} : ${errorMessage}` });
    parsedSteps.push(stepFields);
  }

  try {
    const { data: createdQuest, error: questError } = await supabase
      .from('quests')
      .insert(pickEditableQuestFields(req.body))
      .select()
      .single();
    if (questError) return res.status(400).json({ error: questError.message });

    let createdSteps = [];
    if (parsedSteps.length > 0) {
      const { data: insertedSteps, error: stepsError } = await supabase
        .from('quest_steps')
        .insert(parsedSteps.map((stepFields, stepIndex) => ({
          ...stepFields,
          quest_id: createdQuest.id,
          step_number: stepIndex + 1,
        })))
        .select(STEP_FIELDS);
      if (stepsError) {
        await supabase.from('quests').delete().eq('id', createdQuest.id);
        return res.status(400).json({ error: 'Impossible d\'enregistrer les étapes de la quête' });
      }
      createdSteps = sortStepsByStepNumber(insertedSteps).map((step) => ({ ...step, is_completed: false }));
    }

    res.status(201).json({ ...createdQuest, steps: createdSteps, completed_step_count: 0, status: 'available' });
  } catch (error) {
    res.status(500).json({ error: 'Impossible de créer la quête' });
  }
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
  const { data, error } = await supabase
    .from('quests')
    .update(pickEditableQuestFields(req.body))
    .eq('id', req.params.id)
    .select()
    .single();
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

function sendStepFunctionError(res, error) {
  if (error.code === POSTGRES_NO_DATA_FOUND || isInvalidIdError(error)) {
    return res.status(404).json({ error: 'Quête ou étape introuvable' });
  }
  if (error.code === POSTGRES_INVALID_PARAMETER_VALUE) {
    return res.status(400).json({ error: 'Numéro d\'étape invalide' });
  }
  return res.status(500).json({ error: 'Impossible de modifier la roadmap' });
}

// POST /api/quests/:id/steps
// { title, description, lat, lng, validation_radius_meters?, step_number? }
// Sans step_number, l'étape est ajoutée à la fin ; sinon les étapes suivantes
// sont décalées d'un cran.
router.post('/:id/steps', requireAdmin, async (req, res) => {
  const { stepFields, errorMessage } = parseQuestStepInput(req.body);
  if (errorMessage) return res.status(400).json({ error: errorMessage });

  const requestedStepNumber = req.body.step_number;
  if (requestedStepNumber !== undefined && !Number.isInteger(requestedStepNumber)) {
    return res.status(400).json({ error: 'Le numéro d\'étape doit être un nombre entier' });
  }

  try {
    const { data: insertedStep, error } = await supabase.rpc('insert_quest_step', {
      target_quest_id: req.params.id,
      step_title: stepFields.title,
      step_description: stepFields.description,
      step_lat: stepFields.lat,
      step_lng: stepFields.lng,
      step_validation_radius_meters: stepFields.validation_radius_meters ?? null,
      requested_step_number: requestedStepNumber ?? null,
    });
    if (error) return sendStepFunctionError(res, error);
    res.status(201).json(insertedStep);
  } catch (error) {
    res.status(500).json({ error: 'Impossible de modifier la roadmap' });
  }
});

// PATCH /api/quests/:id/steps/:stepId
// { title?, description?, lat? + lng?, validation_radius_meters? }
// Pour changer l'ordre d'une étape : la supprimer puis la recréer au bon numéro.
router.patch('/:id/steps/:stepId', requireAdmin, async (req, res) => {
  const { stepFields, errorMessage } = parseQuestStepInput(req.body, { isPartialUpdate: true });
  if (errorMessage) return res.status(400).json({ error: errorMessage });

  try {
    const { data: updatedStep, error } = await supabase
      .from('quest_steps')
      .update(stepFields)
      .eq('id', req.params.stepId)
      .eq('quest_id', req.params.id)
      .select(STEP_FIELDS)
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
// Validation par le joueur : étapes au GPS dans l'ordre, puis photo de preuve
// ============================================================================

// POST /api/quests/:id/steps/:stepId/verify-location  { latitude, longitude }
// Valide une étape si le joueur est à son point et que les étapes précédentes
// sont validées. La dernière étape valide l'arrivée et débloque la photo.
router.post('/:id/steps/:stepId/verify-location', async (req, res) => {
  const { latitude, longitude } = req.body ?? {};
  if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) return sendInvalidCoordinates(res);

  try {
    const { data: quest, error: questError } = await supabase
      .from('quests')
      .select(`id, steps:quest_steps(${STEP_FIELDS})`)
      .eq('id', req.params.id)
      .maybeSingle();
    if (questError && !isInvalidIdError(questError)) throw questError;
    if (!quest) return res.status(404).json({ error: 'Quête introuvable' });

    const steps = sortStepsByStepNumber(quest.steps);
    const targetStep = steps.find((step) => step.id === req.params.stepId);
    if (!targetStep) return res.status(404).json({ error: 'Étape introuvable' });

    const [questCompletionResult, stepCompletionsResult] = await Promise.all([
      findUserCompletion(req.user.id, quest.id),
      supabase.from('quest_step_completions').select('step_id').eq('user_id', req.user.id).eq('quest_id', quest.id),
    ]);
    if (questCompletionResult.error) throw questCompletionResult.error;
    if (stepCompletionsResult.error) throw stepCompletionsResult.error;

    const completedStepIds = new Set(stepCompletionsResult.data.map((completion) => completion.step_id));
    const buildProgressResponse = (questStatus) => ({
      step_id: targetStep.id,
      completed_step_count: completedStepIds.size,
      total_step_count: steps.length,
      status: questStatus,
    });

    if (questCompletionResult.data?.status === 'completed') {
      return res.json(buildProgressResponse('completed'));
    }
    if (completedStepIds.has(targetStep.id)) {
      const isEveryStepCompleted = steps.every((step) => completedStepIds.has(step.id));
      return res.json(buildProgressResponse(isEveryStepCompleted ? 'location_verified' : 'in_progress'));
    }

    const firstStepNotCompleted = steps.find((step) => !completedStepIds.has(step.id));
    if (firstStepNotCompleted.id !== targetStep.id) {
      return res.status(409).json({
        error: `Valide d'abord l'étape ${firstStepNotCompleted.step_number}`,
        code: 'previous_step_not_completed',
        next_step_id: firstStepNotCompleted.id,
        next_step_number: firstStepNotCompleted.step_number,
      });
    }

    const distanceToStepPoint = measureDistanceToPoint({ latitude, longitude }, targetStep);
    if (distanceToStepPoint > targetStep.validation_radius_meters) {
      return sendTooFar(res, distanceToStepPoint, targetStep.validation_radius_meters);
    }

    const { error: insertError } = await supabase.from('quest_step_completions').upsert(
      {
        user_id: req.user.id,
        quest_id: quest.id,
        step_id: targetStep.id,
        location_distance_meters: distanceToStepPoint,
      },
      { onConflict: 'user_id,step_id', ignoreDuplicates: true },
    );
    if (insertError) throw insertError;
    completedStepIds.add(targetStep.id);

    const isLastStep = steps.every((step) => completedStepIds.has(step.id));
    if (isLastStep) await markQuestLocationVerified(req.user.id, quest.id, distanceToStepPoint);

    res.json(buildProgressResponse(isLastStep ? 'location_verified' : 'in_progress'));
  } catch (error) {
    res.status(500).json({ error: 'Impossible de vérifier ta position' });
  }
});

// POST /api/quests/:id/verify-location  { latitude, longitude }
// Pour une quête sans étape : compare la position au point d'arrivée de la quête.
// Une quête avec étapes se valide étape par étape (route ci-dessus).
router.post('/:id/verify-location', async (req, res) => {
  const { latitude, longitude } = req.body ?? {};
  if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) return sendInvalidCoordinates(res);

  try {
    const { data: quest, error: questError } = await supabase
      .from('quests')
      .select('id, lat, lng, validation_radius_meters, steps:quest_steps(id)')
      .eq('id', req.params.id)
      .maybeSingle();
    if (questError && !isInvalidIdError(questError)) throw questError;
    if (!quest) return res.status(404).json({ error: 'Quête introuvable' });

    if ((quest.steps ?? []).length > 0) {
      return res.status(409).json({
        error: 'Cette quête se valide étape par étape',
        code: 'step_validation_required',
      });
    }

    const distanceToValidationPoint = measureDistanceToPoint({ latitude, longitude }, quest);
    if (distanceToValidationPoint > quest.validation_radius_meters) {
      return sendTooFar(res, distanceToValidationPoint, quest.validation_radius_meters);
    }

    const { data: existingCompletion, error: completionError } = await findUserCompletion(req.user.id, quest.id);
    if (completionError) throw completionError;
    // Une quête déjà terminée n'est jamais rétrogradée.
    if (existingCompletion?.status === 'completed') {
      return res.json({ status: 'completed', distance_meters: distanceToValidationPoint });
    }

    await markQuestLocationVerified(req.user.id, quest.id, distanceToValidationPoint);
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
// Exige l'arrivée validée. L'envoi de la photo termine la quête ; la
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
