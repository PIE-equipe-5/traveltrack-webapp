const test = require('node:test');
const assert = require('node:assert/strict');

const { distanceInMeters, isValidLatitude, isValidLongitude } = require('./distance');

const eiffelTowerPoint = { latitude: 48.8584, longitude: 2.2945 };

test('la distance entre un point et lui-même est nulle', () => {
  assert.equal(distanceInMeters(eiffelTowerPoint, eiffelTowerPoint), 0);
});

test('Tour Eiffel → Louvre fait environ 3,2 km', () => {
  const louvrePoint = { latitude: 48.8606, longitude: 2.3376 };
  const measuredDistance = distanceInMeters(eiffelTowerPoint, louvrePoint);
  assert.ok(measuredDistance > 3100 && measuredDistance < 3250, `distance obtenue : ${measuredDistance}`);
});

test('un décalage de 0,001° de latitude fait environ 111 m', () => {
  const pointSlightlyNorth = { latitude: eiffelTowerPoint.latitude + 0.001, longitude: eiffelTowerPoint.longitude };
  const measuredDistance = distanceInMeters(eiffelTowerPoint, pointSlightlyNorth);
  assert.ok(Math.abs(measuredDistance - 111.2) < 1, `distance obtenue : ${measuredDistance}`);
});

test('la distance est symétrique', () => {
  const montmartrePoint = { latitude: 48.8867, longitude: 2.3431 };
  assert.equal(
    distanceInMeters(eiffelTowerPoint, montmartrePoint),
    distanceInMeters(montmartrePoint, eiffelTowerPoint),
  );
});

test('les coordonnées hors bornes ou non numériques sont refusées', () => {
  assert.equal(isValidLatitude(48.85), true);
  assert.equal(isValidLatitude(91), false);
  assert.equal(isValidLatitude('48.85'), false);
  assert.equal(isValidLatitude(Number.NaN), false);
  assert.equal(isValidLongitude(-180), true);
  assert.equal(isValidLongitude(180.5), false);
  assert.equal(isValidLongitude(undefined), false);
});
