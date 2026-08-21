package main

# INFRA-008 / §9.8 policy-as-code gate: every helm_release must pin an exact
# chart version. An unpinned release (defaults to "latest") is exactly the
# kind of unreviewed drift R-006 and R-010 call out — a chart bump nobody
# reviewed can change cluster state on the next apply with no diff to read.
deny[msg] {
	release := input.resource.helm_release[name]
	not release.version
	msg := sprintf("helm_release %q has no pinned version", [name])
}

deny[msg] {
	release := input.resource.helm_release[name]
	release.version == "latest"
	msg := sprintf("helm_release %q pins version to \"latest\", which is not a pin", [name])
}
