// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_hygraph_suppression.dart';

const _tracerName = 'dartastic_otel_libs_hygraph';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class HygraphResult {
  /// Creates a result.
  const HygraphResult({
    this.itemCount,
    this.recordsRead,
    this.stage,
    this.locales,
    this.operationKind,
    this.endpointKind,
    this.cacheHit,
    this.complexity,
    this.requestId,
    this.statusCode,
  });

  /// Top-level result rows.
  final int? itemCount;

  /// Records read across the whole query — Hygraph's per-call billing
  /// unit (deep relations multiply).
  final int? recordsRead;

  /// `DRAFT` / `PUBLISHED` — drafts bypass the read replica.
  final String? stage;

  /// Comma-joined locales requested.
  final String? locales;

  /// `query` / `mutation` / `subscription`.
  final String? operationKind;

  /// `content_api` (high-perf) / `management_api`. The content API is
  /// billed on reads; management is per-request.
  final String? endpointKind;

  /// Whether the response came from Hygraph's CDN.
  final bool? cacheHit;

  /// Query complexity score (Hygraph caps complexity per request).
  final int? complexity;

  /// `x-hygraph-trace-id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class HygraphCallResult<T> {
  /// Creates a call result.
  const HygraphCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final HygraphResult? result;
}

/// Wraps a Hygraph GraphQL call in a CLIENT span. [operationName] is
/// the GraphQL operationName (or rpc.method when not declared).
Future<T> tracedHygraph<T>({
  required String operationName,
  required Future<HygraphCallResult<T>> Function() invoke,
  String? project,
  String? endpoint,
}) async {
  if (hygraphInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'hygraph',
    'rpc.method': operationName,
    'graphql.operation.name': operationName,
    'hygraph.operation': operationName,
  };
  if (project != null) m['hygraph.project'] = project;
  if (endpoint != null) m['hygraph.endpoint'] = endpoint;

  final span = _tracer().startSpan(
    'hygraph $operationName',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTelAPI.attributeInt(
          'hygraph.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.recordsRead != null) {
        extras.add(OTelAPI.attributeInt(
          'hygraph.records_read',
          r.result!.recordsRead!,
        ));
      }
      if (r.result!.stage != null) {
        extras.add(OTelAPI.attributeString(
          'hygraph.stage',
          r.result!.stage!,
        ));
      }
      if (r.result!.locales != null) {
        extras.add(OTelAPI.attributeString(
          'hygraph.locales',
          r.result!.locales!,
        ));
      }
      if (r.result!.operationKind != null) {
        extras.add(OTelAPI.attributeString(
          'graphql.operation.type',
          r.result!.operationKind!,
        ));
      }
      if (r.result!.endpointKind != null) {
        extras.add(OTelAPI.attributeString(
          'hygraph.endpoint.kind',
          r.result!.endpointKind!,
        ));
      }
      if (r.result!.cacheHit != null) {
        extras.add(OTelAPI.attributeBool(
          'hygraph.cache.hit',
          r.result!.cacheHit!,
        ));
      }
      if (r.result!.complexity != null) {
        extras.add(OTelAPI.attributeInt(
          'hygraph.complexity',
          r.result!.complexity!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'hygraph.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Hygraph HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
