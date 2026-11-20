// Rayon moyen de la Terre (IUGG), en mètres.
const EARTH_MEAN_RADIUS_IN_METERS = 6371008.8;

function toRadians(angleInDegrees) {
  return (angleInDegrees * Math.PI) / 180;
}

// Distance à vol d'oiseau entre deux points GPS (formule de haversine).
// Chaque point est un objet { latitude, longitude } en degrés décimaux.
function distanceInMeters(fromPoint, toPoint) {
  const latitudeDelta = toRadians(toPoint.latitude - fromPoint.latitude);
  const longitudeDelta = toRadians(toPoint.longitude - fromPoint.longitude);
  const fromLatitude = toRadians(fromPoint.latitude);
  const toLatitude = toRadians(toPoint.latitude);

  const haversineOfCentralAngle =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(fromLatitude) * Math.cos(toLatitude) * Math.sin(longitudeDelta / 2) ** 2;

  const centralAngle = 2 * Math.atan2(
    Math.sqrt(haversineOfCentralAngle),
    Math.sqrt(1 - haversineOfCentralAngle),
  );

  return EARTH_MEAN_RADIUS_IN_METERS * centralAngle;
}

function isValidLatitude(latitude) {
  return typeof latitude === 'number' && Number.isFinite(latitude) && latitude >= -90 && latitude <= 90;
}

function isValidLongitude(longitude) {
  return typeof longitude === 'number' && Number.isFinite(longitude) && longitude >= -180 && longitude <= 180;
}

module.exports = { distanceInMeters, isValidLatitude, isValidLongitude };
