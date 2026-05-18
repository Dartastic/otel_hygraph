// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_hygraph_suppression.dart';

const _tracerName = 'dartastic_otel_libs_hygraph';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class HygraphResult {
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

class HygraphCallResult<T> {
  const HygraphCallResult({required this.value, this.result});
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
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'hygraph.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.recordsRead != null) {
        extras.add(OTel.attributeInt(
          'hygraph.records_read',
          r.result!.recordsRead!,
        ));
      }
      if (r.result!.stage != null) {
        extras.add(OTel.attributeString(
          'hygraph.stage',
          r.result!.stage!,
        ));
      }
      if (r.result!.locales != null) {
        extras.add(OTel.attributeString(
          'hygraph.locales',
          r.result!.locales!,
        ));
      }
      if (r.result!.operationKind != null) {
        extras.add(OTel.attributeString(
          'graphql.operation.type',
          r.result!.operationKind!,
        ));
      }
      if (r.result!.endpointKind != null) {
        extras.add(OTel.attributeString(
          'hygraph.endpoint.kind',
          r.result!.endpointKind!,
        ));
      }
      if (r.result!.cacheHit != null) {
        extras.add(OTel.attributeBool(
          'hygraph.cache.hit',
          r.result!.cacheHit!,
        ));
      }
      if (r.result!.complexity != null) {
        extras.add(OTel.attributeInt(
          'hygraph.complexity',
          r.result!.complexity!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'hygraph.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
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
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
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
