/// Rotation (en degrés) à atteindre pour remettre le nord en haut de la carte
/// en tournant le moins possible depuis [currentRotationInDegrees].
///
/// La rotation de la carte peut s'accumuler au-delà de 360° ou en négatif :
/// on vise donc le multiple de 360° le plus proche plutôt que 0, pour ne
/// jamais faire presque un tour complet (350° revient à 360°, pas à 0°).
double northUpRotationTarget(double currentRotationInDegrees) {
  const fullTurnInDegrees = 360.0;
  final rotationWithinOneTurn = currentRotationInDegrees % fullTurnInDegrees;
  final isCloserToNextFullTurn = rotationWithinOneTurn > fullTurnInDegrees / 2;
  return isCloserToNextFullTurn
      ? currentRotationInDegrees + (fullTurnInDegrees - rotationWithinOneTurn)
      : currentRotationInDegrees - rotationWithinOneTurn;
}
