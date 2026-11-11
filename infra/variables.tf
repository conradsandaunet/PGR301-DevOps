variable "region" {
  type        = string
  description = "AWS_region ressursene opprettes"
  default     =  "eu-west-1"
}

variable "candidate" {
  type        = string
  description = "Kandidatnummer, brukes som suffiks i ressursnavn"
}

variable "image_tag" {
  type = string
  description = "Tag (commit-SHA) på imaget i ECR som skal deployes"
}

variable "bedrock_model_id" {
  type = string
  description = "Bedrock inference profile / modell-ID"
  default = "eu.anthropic.claude-sonnet-4-5-20250929-v1:0"
}


