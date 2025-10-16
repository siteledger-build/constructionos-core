# Cognito User Pool
resource "aws_cognito_user_pool" "pool" {
  name = "constructionos-users"

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  mfa_configuration = "ON"
  software_token_mfa_configuration { enabled = true }

  account_recovery_setting {
    recovery_mechanism { name = "verified_email" priority = 1 }
  }

  username_attributes = ["email"]

  schema {
    name                     = "email"
    required                 = true
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = false
    string_attribute_constraints { min_length = 5 max_length = 254 }
  }

  tags = { Name = "constructionos-userpool" }
}

# App client (for your frontend)
resource "aws_cognito_user_pool_client" "web" {
  name                                 = "constructionos-web"
  user_pool_id                         = aws_cognito_user_pool.pool.id
  generate_secret                      = false
  prevent_user_existence_errors        = "ENABLED"
  refresh_token_validity               = 30
  access_token_validity                = 60
  id_token_validity                    = 60
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
  supported_identity_providers = ["COGNITO"]
  callback_urls                = ["https://example.com/callback"]   # replace later
  logout_urls                  = ["https://example.com/logout"]     # replace later
}

output "cognito_user_pool_id" { value = aws_cognito_user_pool.pool.id }
output "cognito_user_pool_client_id" { value = aws_cognito_user_pool_client.web.id }
