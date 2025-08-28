package k8s.security

#############################################
# Helpers (Rego 1.0: requieren "if")
#############################################

is_deployment if {
  input.kind == "Deployment"
}

# Recorre contenedores del Deployment
containers[c] if {
  is_deployment
  c := input.spec.template.spec.containers[_]
}

has_field(obj, key) if {
  obj[key]
}

#############################################
# Reglas de denegación (partial set rules)
# Rego 1.0: "deny contains msg if { ... }"
#############################################

# 1) Prohibir imágenes con :latest
deny contains msg if {
  containers[c]
  endswith(c.image, ":latest")
  msg := sprintf("container %q must not use the 'latest' tag (image: %s)", [c.name, c.image])
}

# 2) Exigir resources.requests y resources.limits
deny contains msg if {
  containers[c]
  not has_field(c, "resources")
  msg := sprintf("container %q must set resources.requests and resources.limits", [c.name])
}

deny contains msg if {
  containers[c]
  has_field(c, "resources")
  not has_field(c.resources, "requests")
  msg := sprintf("container %q must set resources.requests (cpu/memory)", [c.name])
}

deny contains msg if {
  containers[c]
  has_field(c, "resources")
  not has_field(c.resources, "limits")
  msg := sprintf("container %q must set resources.limits (cpu/memory)", [c.name])
}

# 3) Exigir runAsNonRoot a nivel Pod
deny contains msg if {
  is_deployment
  not has_field(input.spec.template.spec, "securityContext")
  msg := "pod.spec.securityContext.runAsNonRoot must be true"
}

deny contains msg if {
  is_deployment
  has_field(input.spec.template.spec, "securityContext")
  input.spec.template.spec.securityContext.runAsNonRoot != true
  msg := "pod.spec.securityContext.runAsNonRoot must be true"
}

# 4) Bloquear privilege escalation a nivel contenedor
deny contains msg if {
  containers[c]
  has_field(c, "securityContext")
  c.securityContext.allowPrivilegeEscalation == true
  msg := sprintf("container %q must not allow privilege escalation", [c.name])
}

# 5) Exigir seccomp RuntimeDefault a nivel Pod
deny contains msg if {
  is_deployment
  not has_field(input.spec.template.spec, "seccompProfile")
  msg := "pod.spec.securityContext.seccompProfile.type must be RuntimeDefault"
}

deny contains msg if {
  is_deployment
  has_field(input.spec.template.spec, "seccompProfile")
  input.spec.template.spec.securityContext.seccompProfile.type != "RuntimeDefault"
  msg := "pod.spec.securityContext.seccompProfile.type must be RuntimeDefault"
}
