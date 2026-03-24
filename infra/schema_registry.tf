# =============================================================================
# GLUE SCHEMA REGISTRY
# Groundwork for schema enforcement on MSK topics.
# No schemas are defined here — add them when you decide on topic/data shapes.
#
# Usage pattern when ready:
#   1. Add aws_glue_schema resources here for each Kafka topic
#   2. In producers: use AWS Glue Schema Registry SDK to serialize messages
#   3. In Glue streaming job: Glue auto-deserializes using registry if configured
#
# Supported formats: AVRO, JSON, PROTOBUF
# Recommended for Iceberg: AVRO (best schema evolution support)
# =============================================================================

resource "aws_glue_registry" "msk_schemas" {
  registry_name = local.schema_registry_name
  description   = "Schema registry for MSK Kafka topic schemas"

  tags = merge(local.common_tags, {
    Name = local.schema_registry_name
  })
}

# =============================================================================
# EXAMPLE — uncomment and fill in when you have a topic + schema defined:
#
# resource "aws_glue_schema" "orders" {
#   schema_name       = "orders"
#   registry_arn      = aws_glue_registry.msk_schemas.arn
#   data_format       = "AVRO"
#   compatibility     = "BACKWARD"   # new schema can read old data
#   description       = "Schema for the orders Kafka topic"
#   schema_definition = file("${path.module}/../schemas/orders.avsc")
# }
#
# Compatibility options:
#   NONE       — no checks, anything goes (dev only)
#   BACKWARD   — new schema reads old messages (recommended default)
#   FORWARD    — old schema reads new messages
#   FULL       — both BACKWARD + FORWARD
#   DISABLED   — schema validation off
# =============================================================================
