// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_hygraph/otel_hygraph.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_hygraph-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('query records stage + records_read + complexity', () async {
    await tracedHygraph<String>(
      operationName: 'ListArticles',
      endpoint: 'content_api',
      invoke: () async => const HygraphCallResult(
        value: 'ok',
        result: HygraphResult(
          itemCount: 15,
          recordsRead: 240,
          stage: 'PUBLISHED',
          locales: 'en,de',
          operationKind: 'query',
          endpointKind: 'content_api',
          cacheHit: false,
          complexity: 72,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('hygraph ListArticles')!);
    expect(a['graphql.operation.name'], 'ListArticles');
    expect(a['hygraph.stage'], 'PUBLISHED');
    expect(a['hygraph.records_read'], 240);
    expect(a['hygraph.complexity'], 72);
    expect(a['graphql.operation.type'], 'query');
  });

  test('suppression skips spans', () async {
    await runWithoutHygraphInstrumentationAsync(() async {
      await tracedHygraph<String>(
        operationName: 'Q',
        invoke: () async => const HygraphCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('hygraph '), isEmpty);
  });
}
