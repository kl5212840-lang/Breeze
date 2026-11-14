import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Inventories actual input constructors and entry points, not just imports.
/// Raw candidates still require review: an author form or page number isn't
/// automatically a search field. This does not verify rendered materials.
void main() {
  var wrapped = 0;
  final missing = <String>[];
  final candidates = <String>[];
  final entries = <String>[];
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.dart') &&
                !file.path.endsWith('.g.dart') &&
                !file.path.endsWith('.freezed.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final source = file.readAsStringSync();
    if (!source.contains('TextField(') &&
        !source.contains('TextFormField(') &&
        !source.contains('InputDecorator(') &&
        !source.contains('SearchQueryField(') &&
        !source.contains('VideoSearchEntry(')) {
      continue;
    }
    final parsed = parseString(content: source, path: file.path);
    parsed.unit.accept(
      _Inputs((node, arguments, kind) {
        final location =
            '${file.path}:${parsed.lineInfo.getLocation(node.offset).lineNumber}';
        if (kind == 'SearchQueryField' || kind == 'VideoSearchEntry') {
          entries.add('$location | $kind');
          return;
        }
        final decoration = arguments.arguments
            .whereType<NamedArgument>()
            .where((arg) => arg.name.lexeme == 'decoration')
            .firstOrNull;
        if (decoration == null) return;
        final expression = decoration.argumentExpression;
        if (expression is MethodInvocation &&
            expression.methodName.name == 'searchFieldDecoration') {
          AstNode? ancestor = node.parent;
          var hasSurface = false;
          while (ancestor != null && ancestor is! FunctionBody) {
            if (ancestor is InstanceCreationExpression &&
                    ancestor.constructorName.type.toSource() ==
                        'SearchFieldSurface' ||
                ancestor is MethodInvocation &&
                    ancestor.methodName.name == 'SearchFieldSurface') {
              hasSurface = true;
              break;
            }
            ancestor = ancestor.parent;
          }
          if (hasSurface) {
            wrapped++;
          } else {
            missing.add(location);
          }
        } else if (RegExp(
          r'search|查找|搜索',
          caseSensitive: false,
        ).hasMatch(expression.toSource())) {
          candidates.add(
            '$location | ${expression.toSource().replaceAll(RegExp(r'\s+'), ' ')}',
          );
        }
      }),
    );
  }
  stdout.writeln('Common inputs with matching surfaces: $wrapped');
  stdout.writeln('Missing surfaces: ${missing.length}');
  for (final line in missing) {
    stdout.writeln('MISSING $line');
  }
  stdout.writeln('\nSearch entry call sites (${entries.length}):');
  for (final line in entries) {
    stdout.writeln(line);
  }
  stdout.writeln(
    '\nRaw input candidates requiring semantic review (${candidates.length}):',
  );
  for (final line in candidates) {
    stdout.writeln(line);
  }
  if (missing.isNotEmpty || wrapped == 0 || entries.isEmpty) exitCode = 1;
}

class _Inputs extends RecursiveAstVisitor<void> {
  _Inputs(this.record);
  final void Function(AstNode node, ArgumentList arguments, String kind) record;

  static const _kinds = {
    'TextField',
    'TextFormField',
    'InputDecorator',
    'SearchQueryField',
    'VideoSearchEntry',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final kind = node.constructorName.type.toSource();
    if (_kinds.contains(kind)) {
      record(node, node.argumentList, kind);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final kind = node.methodName.name;
    if (_kinds.contains(kind)) record(node, node.argumentList, kind);
    super.visitMethodInvocation(node);
  }
}
