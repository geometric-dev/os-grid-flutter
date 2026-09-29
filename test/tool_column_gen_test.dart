import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/os_column_gen.dart' as gen;

const String _fixtureSource = '''
// A leading comment mentioning @OsGridColumn should be ignored.
library person;

/// Doc comment with @OsColumn(...) inside must not confuse the parser.
@OsGridColumn(colIdPrefix: 'p.', defaultWidth: 100)
class Person {
  @OsColumn(headerName: 'Name', width: 150)
  final String name;

  final int age;

  double score;

  bool active = true;

  var note = '';

  static const int kMax = 5;

  Person(this.name, this.age);

  String get label => 'x';

  void doThing(int n) {}

  Map<String, int> counts = {};
}

class NotAnnotated {
  final String other;
  NotAnnotated(this.other);
}
''';

void main() {
  group('parsing primitives', () {
    test('kindForType maps declared types to schema kinds', () {
      expect(gen.kindForType('String'), 'text');
      expect(gen.kindForType('int'), 'integer');
      expect(gen.kindForType('double'), 'number');
      expect(gen.kindForType('num'), 'number');
      expect(gen.kindForType('bool'), 'boolean');
      expect(gen.kindForType('DateTime'), 'date');
      expect(gen.kindForType('List<int>'), 'custom');
    });

    test('lowerFirst camel-cases class names', () {
      expect(gen.lowerFirst('Person'), 'person');
      expect(gen.lowerFirst('HRRecord'), 'hRRecord');
      expect(gen.lowerFirst(''), '');
    });

    test('baseName handles POSIX and Windows paths', () {
      expect(gen.baseName(r'C:\lib\src\person.dart'), 'person.dart');
      expect(gen.baseName('/lib/person.dart'), 'person.dart');
      expect(gen.baseName('readme.md'), 'readme.md');
    });

    test('stripComments removes comments but keeps strings', () {
      final out = gen.stripComments("// hi\nfinal x = '// kept';/* block */");
      expect(out.contains('// kept'), isTrue);
      expect(out.contains('// hi'), isFalse);
      expect(out.contains('block'), isFalse);
    });

    test('matchingParen honours nesting and strings', () {
      const s = '(a, (b, "c)") )';
      expect(gen.matchingParen(s, 0), s.length - 1);
      expect(gen.matchingParen('(unbalanced', 0), -1);
    });

    test('splitTopLevel keeps nested commas intact', () {
      expect(gen.splitTopLevel("a: {'k1': 1, 'k2': 2}, b: 3"), [
        "a: {'k1': 1, 'k2': 2}",
        'b: 3',
      ]);
    });

    test('parseAnnotationArgs extracts key/value literal pairs', () {
      final args = gen.parseAnnotationArgs(
        "headerName: 'Name', width: 150, pinned: OsColumnPin.left",
      );
      expect(args['headerName'], "'Name'");
      expect(args['width'], '150');
      expect(args['pinned'], 'OsColumnPin.left');
    });
  });

  group('tryParseField', () {
    gen.ParsedField? parse(String stmt) => gen.tryParseField(stmt);

    test('parses annotated final field', () {
      final f = parse("@OsColumn(headerName: 'Name') final String name;");
      expect(f, isNotNull);
      expect(f!.name, 'name');
      expect(f.typeName, 'String');
      expect(f.isFinal, isTrue);
      expect(f.annotation!.args['headerName'], "'Name'");
    });

    test('parses plain typed fields with initializers', () {
      final f = parse('Map<String, int> counts = {};');
      expect(f!.name, 'counts');
      expect(f.typeName, 'Map<String,int>');
      expect(f.isFinal, isFalse);
    });

    test('parses var declarations', () {
      expect(parse('var counter;')!.typeName, 'dynamic');
    });

    test('rejects methods, getters, ctors and consts', () {
      expect(parse('void doThing(int n)'), isNull);
      expect(parse('String get label => \'x\''), isNull);
      expect(parse('Person(this.name, this.age)'), isNull);
      expect(parse('static const int kMax = 5'), isNull);
      expect(parse('@Other final String x;'), isNull);
    });
  });

  group('parseAnnotatedClasses', () {
    test('finds only annotated classes with eligible fields', () {
      final classes = gen.parseAnnotatedClasses(_fixtureSource);
      expect(classes, hasLength(1));
      final person = classes.single;
      expect(person.name, 'Person');
      expect(person.configArgs['colIdPrefix'], "'p.'");
      // name, age, score, active, note, counts — no kMax/getter/method.
      expect(person.fields.map((f) => f.name), [
        'name',
        'age',
        'score',
        'active',
        'note',
        'counts',
      ]);
      final nameField = person.fields.firstWhere((f) => f.name == 'name');
      expect(nameField.isFinal, isTrue);
      expect(nameField.annotation!.args['width'], '150');
    });

    test('returns empty for sources without annotations', () {
      expect(gen.parseAnnotatedClasses('class A { final int x; }'), isEmpty);
    });
  });

  group('generatePartFile', () {
    late List<gen.ParsedClass> classes;

    setUp(() {
      classes = gen.parseAnnotatedClasses(_fixtureSource);
    });

    test('emits part-of directive and generated header', () {
      final out = gen.generatePartFile(
        partOfName: 'person.dart',
        classes: classes,
      );
      expect(out, startsWith('// GENERATED CODE - DO NOT MODIFY BY HAND'));
      expect(out, contains("part of 'person.dart';"));
      expect(out, contains('// ignore_for_file'));
    });

    test('typed value getters replace stringly-typed lookups', () {
      final out = gen.generatePartFile(
        partOfName: 'person.dart',
        classes: classes,
      );
      expect(out, contains("(p) => p.name"));
      expect(out, contains('List<OsColumnDef<Person>> personColumns({'));
      expect(out, contains('OsColumnDefs.fromSchema<Person>('));
      expect(out, contains("type: Person,"));
      expect(
        out,
        contains("config: OsGridColumn(colIdPrefix: 'p.', defaultWidth: 100)"),
      );
    });

    test('mutable fields gain setters; finals do not', () {
      final out = gen.generatePartFile(
        partOfName: 'person.dart',
        classes: classes,
      );
      expect(out, contains('(p, v) => p.score = v as double'));
      expect(out.contains('(p, v) => p.name = v'), isFalse);
      expect(out.contains('(p, v) => p.age = v'), isFalse);
    });

    test('kinded constructors follow declared types', () {
      final out = gen.generatePartFile(
        partOfName: 'person.dart',
        classes: classes,
      );
      expect(out, contains('OsColumnField<Person>.text'));
      expect(out, contains('OsColumnField<Person>.integer'));
      expect(out, contains('OsColumnField<Person>.number'));
      expect(out, contains('OsColumnField<Person>.boolean'));
      expect(out, contains('OsColumnField<Person>.custom')); // var note
    });

    test('emits phantom-typed ColumnRef constants (item 38)', () {
      final out = gen.generatePartFile(
        partOfName: 'person.dart',
        classes: classes,
      );
      expect(out, contains('abstract final class PersonCols'));
      expect(
        out,
        contains("static const name = ColumnRef<Person>.unchecked('name');"),
      );
      expect(
        out,
        contains("static const age = ColumnRef<Person>.unchecked('age');"),
      );
    });

    test('wraps long literals across lines deterministically', () {
      const long = gen.ParsedFieldAnnotation({
        'headerName': "'A very long header name that pushes width'",
        'tooltipField': "'some.really.long.dotted.tooltip.field.path'",
        'headerTooltip': "'Hover text'",
      });
      final literal = gen.emitFieldLiteral(
        'Person',
        const gen.ParsedField(
          name: 'description',
          typeName: 'String',
          isFinal: true,
          annotation: long,
        ),
      );
      expect(literal, contains('\n'));
      expect(literal, contains("'description'"));
      // Deterministic output.
      final again = gen.emitFieldLiteral(
        'Person',
        const gen.ParsedField(
          name: 'description',
          typeName: 'String',
          isFinal: true,
          annotation: long,
        ),
      );
      expect(literal, again);
    });
  });

  group('generateInDirectory (end-to-end)', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('os_col_gen_');
      File(
        '${temp.path}${Platform.pathSeparator}person.dart',
      ).writeAsStringSync(_fixtureSource);
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    File partFile() =>
        File('${temp.path}${Platform.pathSeparator}person.g.part');

    test('writes .g.part beside the source', () {
      final touched = gen.generateInDirectory(temp);
      expect(touched, hasLength(1));
      expect(partFile().existsSync(), isTrue);
      final content = partFile().readAsStringSync();
      expect(content, contains("part of 'person.dart';"));
    });

    test('second run is idempotent', () {
      gen.generateInDirectory(temp);
      expect(gen.generateInDirectory(temp), isEmpty);
    });

    test('--check mode throws on drift and passes when clean', () {
      gen.generateInDirectory(temp);
      // Clean run throws nothing.
      expect(() => gen.generateInDirectory(temp, check: true), returnsNormally);
      // Corrupt the output → drift detected.
      partFile().writeAsStringSync('// stale\n');
      expect(
        () => gen.generateInDirectory(temp, check: true),
        throwsA(isA<gen.GenerationCheckFailure>()),
      );
    });

    test('skips generated artifacts and unannotated sources', () {
      File(
        '${temp.path}${Platform.pathSeparator}plain.dart',
      ).writeAsStringSync('class Plain { final int x; }');
      gen.generateInDirectory(temp);
      expect(
        File('${temp.path}${Platform.pathSeparator}plain.g.part').existsSync(),
        isFalse,
      );
      // Only one part file exists (from person.dart).
      expect(
        temp.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.g.part'),
        ),
        hasLength(1),
      );
    });

    test('skips *_test.dart sources (embedded fixtures)', () {
      File(
        '${temp.path}${Platform.pathSeparator}widget_test.dart',
      ).writeAsStringSync(_fixtureSource);
      final touched = gen.generateInDirectory(temp);
      expect(touched.where((p) => p.endsWith('widget_test.g.part')), isEmpty);
    });
  });
}
