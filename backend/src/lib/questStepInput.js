const { isValidLatitude, isValidLongitude } = require('./distance');

function isNonEmptyText(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

function isPositiveInteger(value) {
  return Number.isInteger(value) && value > 0;
}

// Vérifie les champs d'une étape envoyés par un admin et les renvoie prêts à
// être enregistrés : { stepFields } ou { errorMessage }.
// Avec isPartialUpdate, seuls les champs présents sont vérifiés (PATCH).
function parseQuestStepInput(stepInput, { isPartialUpdate = false } = {}) {
  if (stepInput === null || typeof stepInput !== 'object' || Array.isArray(stepInput)) {
    return { errorMessage: 'Étape invalide' };
  }

  const { title, description, lat, lng, validation_radius_meters: validationRadiusMeters } = stepInput;
  const isRequired = (value) => !isPartialUpdate || value !== undefined;
  const stepFields = {};

  if (isRequired(title)) {
    if (!isNonEmptyText(title)) return { errorMessage: 'Le titre de l\'étape est obligatoire' };
    stepFields.title = title.trim();
  }
  if (isRequired(description)) {
    if (!isNonEmptyText(description)) return { errorMessage: 'La description de l\'étape est obligatoire' };
    stepFields.description = description.trim();
  }
  if (isRequired(lat) || isRequired(lng)) {
    if (!isValidLatitude(lat) || !isValidLongitude(lng)) {
      return { errorMessage: 'La position de l\'étape (lat et lng) est invalide' };
    }
    stepFields.lat = lat;
    stepFields.lng = lng;
  }
  if (validationRadiusMeters !== undefined) {
    if (!isPositiveInteger(validationRadiusMeters)) {
      return { errorMessage: 'Le rayon de validation doit être un nombre entier de mètres supérieur à 0' };
    }
    stepFields.validation_radius_meters = validationRadiusMeters;
  }

  if (isPartialUpdate && Object.keys(stepFields).length === 0) {
    return { errorMessage: 'Aucun champ à modifier' };
  }
  return { stepFields };
}

module.exports = { parseQuestStepInput, isNonEmptyText };
