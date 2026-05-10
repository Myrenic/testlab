variable "proxmox" {
  sensitive = true
  type = object({
    url              = string
    username         = string
    password         = string
    host_description = string
    host_tags        = list(string)
  })
}

variable "homeassistant_voice" {
  sensitive = true
  type = object({
    host = object({
      name           = string
      template_vmid  = number
      ip_addr        = string
      gateway        = string
      cidr           = optional(string, "/24")
      node_name      = string
      network_bridge = string
      datastore_id   = string
      vmid           = optional(number)
      vlan_id        = optional(number, 0)
      cores          = optional(number, 6)
      memory         = optional(number, 16384)
      disk_size      = optional(number, 64)
      startup_order  = optional(number, 2)
    })
    voice = object({
      whisper_model         = optional(string, "base-int8")
      whisper_language      = optional(string, "en")
      piper_voice           = optional(string, "en_US-lessac-medium")
      wake_word_model       = optional(string, "ok_nabu")
      ollama_model          = optional(string, "llama3.2:3b")
      ollama_keep_alive     = optional(string, "-1")
      ollama_context_length = optional(number, 4096)
      ollama_num_parallel   = optional(number, 1)
    })
  })
}
