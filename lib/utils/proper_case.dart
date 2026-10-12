/// Title-cases [text] for popup headings whose wording comes from Flutter's
/// own localizations (date and time pickers), which arrive in the wrong case
/// (often fully upper-case). Short connecting words stay lower-case, as in
/// the app's own Proper Case strings.
String toProperCase(String text, String languageCode) {
  final minors = _minorWords[languageCode] ?? const <String>{};
  final words = text.toLowerCase().split(' ');
  return [
    for (var i = 0; i < words.length; i++)
      if (words[i].isEmpty)
        words[i]
      else if (i > 0 && minors.contains(words[i]))
        words[i]
      else
        words[i][0].toUpperCase() + words[i].substring(1),
  ].join(' ');
}

const _minorWords = <String, Set<String>>{
  'en': {'a', 'an', 'the', 'and', 'or', 'of', 'to', 'in', 'on', 'for', 'at'},
  'it': {
    'il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'una', 'di', 'del', 'della', //
    'a', 'al', 'alla', 'da', 'in', 'con', 'per', 'e', 'o',
  },
  'ro': {'și', 'sau', 'de', 'în', 'la', 'pe', 'cu', 'din', 'al', 'a'},
};
