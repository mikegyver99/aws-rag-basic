variable "prefix" {
  type = string
}

variable "collection_name" {
  type = string
}

variable "network_allowed_cidrs" {
  description = "List of CIDR ranges allowed to access the collection via network policy."
  type        = list(string)
  default     = ["172.31.0.0/16"]
}

variable "source_vpce_ids" {
  description = "List of VPC endpoint IDs (vpce-...) allowed to access the collection. If provided, network policy will use SourceVPCEs and set AllowFromPublic = false."
  type        = list(string)
  default     = []
}
