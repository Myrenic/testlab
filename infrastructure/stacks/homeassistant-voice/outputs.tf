output "container_id" {
  value       = module.lxc.container_id
  description = "VMID of the Home Assistant voice LXC container"
  sensitive   = true
}

output "hostname" {
  value       = module.lxc.hostname
  description = "Hostname of the Home Assistant voice LXC container"
  sensitive   = true
}

output "ip_address" {
  value       = module.lxc.ip_address
  description = "Static IPv4 address assigned to the Home Assistant voice container"
  sensitive   = true
}

output "whisper_endpoint" {
  value       = "${var.homeassistant_voice.host.ip_addr}:10300"
  description = "Wyoming Whisper STT endpoint"
  sensitive   = true
}

output "piper_endpoint" {
  value       = "${var.homeassistant_voice.host.ip_addr}:10200"
  description = "Wyoming Piper TTS endpoint"
  sensitive   = true
}

output "wake_word_endpoint" {
  value       = "${var.homeassistant_voice.host.ip_addr}:10400"
  description = "Wyoming openWakeWord endpoint"
  sensitive   = true
}

output "ollama_url" {
  value       = "http://${var.homeassistant_voice.host.ip_addr}:11434"
  description = "Ollama API base URL"
  sensitive   = true
}
