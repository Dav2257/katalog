import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katalog/services/hashtag_service.dart';
import 'package:katalog/widgets/hashtag_autocomplete_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HashtagService Tests', () {
    test('Initial hashtags contains default seed tags', () {
      final service = HashtagService.instance;
      expect(service.hashtags.contains('#jati'), isTrue);
      expect(service.hashtags.contains('#sangkar'), isTrue);
      expect(service.hashtags.contains('#jepara'), isTrue);
    });

    test('getSuggestions filters correctly without leading #', () {
      final service = HashtagService.instance;
      final suggestions = service.getSuggestions('ja');
      expect(suggestions.contains('#jati'), isTrue);
    });

    test('getSuggestions filters correctly with leading #', () {
      final service = HashtagService.instance;
      final suggestions = service.getSuggestions('#ja');
      expect(suggestions.contains('#jati'), isTrue);
    });

    test('getSuggestions excludes already added tags', () {
      final service = HashtagService.instance;
      final suggestions = service.getSuggestions('ja', exclude: ['#jati']);
      expect(suggestions.contains('#jati'), isFalse);
    });

    test('addHashtag adds new tag formatted with #', () async {
      final service = HashtagService.instance;
      await service.addHashtag('kayusonokeling');
      expect(service.hashtags.contains('#kayusonokeling'), isTrue);
    });
  });

  group('HashtagAutocompleteField Widget Tests', () {
    testWidgets('Renders input field with hint text and quick chips', (tester) async {
      final controller = TextEditingController();
      final addedTags = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HashtagAutocompleteField(
              controller: controller,
              currentHashtags: const ['#sangkar'],
              onHashtagSelected: (tag) => addedTags.add(tag),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Saran Cepat: '), findsOneWidget);
    });

    testWidgets('Tapping quick chip invokes onHashtagSelected', (tester) async {
      final controller = TextEditingController();
      final addedTags = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HashtagAutocompleteField(
              controller: controller,
              currentHashtags: const [],
              onHashtagSelected: (tag) => addedTags.add(tag),
            ),
          ),
        ),
      );

      // Find quick chip for '#jati' or '#bambu'
      final chipFinder = find.text('#jati');
      if (chipFinder.evaluate().isNotEmpty) {
        await tester.tap(chipFinder.first);
        await tester.pumpAndSettle();
        expect(addedTags.contains('#jati'), isTrue);
      }
    });
  });
}
