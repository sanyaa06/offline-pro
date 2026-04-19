class ConfidenceService {
  /// Calculates real-time system certainty against estimated offline steps
  String getConfidence(bool isOffline, int offlineSteps) {
    if (!isOffline) return "High"; // Actual Location GPS lock
    
    // Decay curve mapping offline steps
    if (offlineSteps < 3) return "High";
    if (offlineSteps < 6) return "Medium";
    return "Low";
  }
}
