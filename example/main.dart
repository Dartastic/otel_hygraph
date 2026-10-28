// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_hygraph/otel_hygraph.dart';

/// Traces Hygraph GraphQL calls with OpenTelemetry.
///
/// `otel_hygraph` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Hygraph GraphQL call in
/// [tracedHygraph]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'hygraph-example');

  // Wraps a Hygraph GraphQL call in a CLIENT span.
  final hygraphId = await tracedHygraph<String>(
    operationName: 'example',
    project: 'example',
    endpoint: 'example',
    invoke: () async {
      // Make the Hygraph GraphQL call here, then report what it returned.
      const id = 'hygraph_8f3a2c';
      return const HygraphCallResult(
          value: id,
          result: HygraphResult(
              itemCount: 3,
              recordsRead: 1,
              stage: 'DRAFT',
              locales: 'en-US',
              operationKind: 'query',
              endpointKind: 'content_api',
              cacheHit: true,
              complexity: 1,
              requestId: 'request_8f3a2c',
              statusCode: 200));
    },
  );
  OTelLog.info('tracedHygraph returned $hygraphId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutHygraphInstrumentationAsync.
  await runWithoutHygraphInstrumentationAsync(
    () => tracedHygraph<String>(
      operationName: 'example',
      project: 'example',
      endpoint: 'example',
      invoke: () async {
        const id = 'hygraph_8f3a2c';
        return const HygraphCallResult(
            value: id,
            result: HygraphResult(
                itemCount: 3,
                recordsRead: 1,
                stage: 'DRAFT',
                locales: 'en-US',
                operationKind: 'query',
                endpointKind: 'content_api',
                cacheHit: true,
                complexity: 1,
                requestId: 'request_8f3a2c',
                statusCode: 200));
      },
    ),
  );

  await OTel.shutdown();
}
