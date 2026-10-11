/// A themed batch of reflection prompts within a [LifeArea]'s Reflections
/// page, e.g. "Stress & Coping". Purely presentational: an answer is stored
/// against the prompt's position in the area's flattened list (see
/// `LifeAreaX.reflectionQuestions`), which is every group's [questions]
/// concatenated in order.
class ReflectionGroup {
  const ReflectionGroup(this.title, this.questions);

  final String title;
  final List<String> questions;
}
