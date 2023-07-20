#local
locals {
  envs = { for tuple in regexall("(.*)=(.*)", file(".env")) : tuple[0] => sensitive(tuple[1]) }
}

variable "default_location" {
    type    = string
    default = "canadacentral"
}

variable "personal_token" {
    type        = string
    sensitive   = true
}

variable "project_name" {
    type = string
    default = "OpenAI-Chatbot-Pilot"
}

variable "project_name_lowercase" {
    type = string
    default = "openaichatbotpilot"
}

variable "project_name_short_lowercase" {
    type = string
    default = "oaichat"
}

variable "name_prefix" {
    type = string
    default = "ScDc-CIO"
}

variable "name_prefix_lowercase" {
    type = string
    default = "scdccio"
}

variable "api_version" {
    type = string
    default = "3.0.4"
}

variable "api_version_sha" {
    type = string
    default = "e05f961f49eba1b8c785adf9481e2a7348aae8ca"
}