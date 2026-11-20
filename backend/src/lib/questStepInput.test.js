const test = require('node:test');
const assert = require('node:assert/strict');

const { parseQuestStepInput } = require('./questStepInput');

const completeStepInput = {
  title: '  Parvis du Trocadéro ',
  description: ' Repère la Tour Eiffel. ',
  lat: 48.8616,
  lng: 2.2893,
};

test('accepte une étape complète et nettoie les textes', () => {
  assert.deepEqual(parseQuestStepInput(completeStepInput), {
    stepFields: { title: 'Parvis du Trocadéro', description: 'Repère la Tour Eiffel.', lat: 48.8616, lng: 2.2893 },
  });
});

test('le rayon est facultatif mais doit être un entier positif', () => {
  assert.equal(parseQuestStepInput({ ...completeStepInput, validation_radius_meters: 80 }).stepFields.validation_radius_meters, 80);
  assert.ok(parseQuestStepInput({ ...completeStepInput, validation_radius_meters: 0 }).errorMessage);
  assert.ok(parseQuestStepInput({ ...completeStepInput, validation_radius_meters: 12.5 }).errorMessage);
});

test('une étape sans titre, description ou position est refusée', () => {
  assert.ok(parseQuestStepInput({ ...completeStepInput, title: ' ' }).errorMessage);
  assert.ok(parseQuestStepInput({ ...completeStepInput, description: undefined }).errorMessage);
  assert.ok(parseQuestStepInput({ ...completeStepInput, lat: undefined }).errorMessage);
  assert.ok(parseQuestStepInput({ ...completeStepInput, lng: 200 }).errorMessage);
  assert.ok(parseQuestStepInput('pas un objet').errorMessage);
});

test('en modification, seuls les champs envoyés sont vérifiés', () => {
  assert.deepEqual(parseQuestStepInput({ title: 'Nouveau titre' }, { isPartialUpdate: true }), {
    stepFields: { title: 'Nouveau titre' },
  });
  assert.ok(parseQuestStepInput({}, { isPartialUpdate: true }).errorMessage);
});

test('en modification, latitude et longitude vont ensemble', () => {
  assert.ok(parseQuestStepInput({ lat: 48.86 }, { isPartialUpdate: true }).errorMessage);
  assert.deepEqual(parseQuestStepInput({ lat: 48.86, lng: 2.33 }, { isPartialUpdate: true }), {
    stepFields: { lat: 48.86, lng: 2.33 },
  });
});
