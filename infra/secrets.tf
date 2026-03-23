# Secrets Manager Secret for database credentials
resource "aws_secretsmanager_secret" "glue_db_credentials" {
  name                    = local.secrets_db_credentials_name
  description             = "Database credentials for Glue connections"
  recovery_window_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "Glue Database Credentials"
    }
  )
}

# Secrets Manager Secret Version (update the secret_string with actual credentials)
resource "aws_secretsmanager_secret_version" "glue_db_credentials" {
  secret_id = aws_secretsmanager_secret.glue_db_credentials.id
  secret_string = jsonencode({
    username = "your-db-user"
    password = "your-db-password"
    host     = "your-db-host"
    port     = 5432
    database = "your-db-name"
  })

  depends_on = [aws_secretsmanager_secret.glue_db_credentials]
}

# Secrets Manager Secret for API keys
resource "aws_secretsmanager_secret" "glue_api_keys" {
  name                    = local.secrets_api_keys_name
  description             = "API keys for Glue data sources"
  recovery_window_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "Glue API Keys"
    }
  )
}

resource "aws_secretsmanager_secret_version" "glue_api_keys" {
  secret_id = aws_secretsmanager_secret.glue_api_keys.id
  secret_string = jsonencode({
    api_key_1 = "your-api-key-1"
    api_key_2 = "your-api-key-2"
  })

  depends_on = [aws_secretsmanager_secret.glue_api_keys]
}
