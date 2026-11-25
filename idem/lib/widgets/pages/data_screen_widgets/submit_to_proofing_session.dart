/// What the session still waits for once this app sent every step it
/// performs.
enum PendingStep {
  /// Nothing: every step is in.
  none,

  /// The face step, which the browser runs.
  browserFace,

  /// The user's go-ahead: every step is in, the session is submitted when
  /// they tap Share.
  share,
}
