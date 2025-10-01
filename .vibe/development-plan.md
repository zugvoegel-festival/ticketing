# Development Plan: ticketing (main branch)

*Generated on 2025-10-01 by Vibe Feature MCP*
*Workflow: [epcc](https://mrsimpson.github.io/responsible-vibe-mcp/workflows/epcc)*

## Goal
Add configuration for monitoring stack using the existing monitoring folder (monitorin/) to integrate Loki, Grafana, Prometheus, and Promtail into the NixOS configuration system.

## Explore
### Tasks
- [x] Document requirements for monitoring stack integration

### Completed
- [x] Created development plan file
- [x] Analyzed existing monitoring folder structure and Docker Compose configuration
- [x] Examined current NixOS module structure and patterns
- [x] Researched NixOS monitoring service options for Loki, Grafana, Prometheus
- [x] Understood how services are currently configured in the zugvoegel namespace

## Plan

### Phase Entrance Criteria:
- [x] The existing monitoring setup has been thoroughly analyzed
- [x] Current NixOS patterns and module structure are understood  
- [x] Monitoring service requirements are documented
- [x] Integration approach is clear

### Tasks
- [x] Design module structure and options interface
- [x] Plan configuration file generation strategy
- [x] Design data directory and permissions structure
- [x] Plan Grafana provisioning integration
- [x] Design service dependencies and networking
- [x] Plan firewall and security configuration
- [x] Create implementation task breakdown

### Completed
- [x] Complete implementation strategy documented
- [x] All configuration conversion plans created
- [x] Service dependency mapping completed
- [x] Code task breakdown created

### Implementation Strategy

**1. Module Architecture:**
```nix
config.zugvoegel.services.monitoring = {
  enable = mkEnableOption "monitoring stack";
  
  loki = {
    enable = mkEnableOption "Loki log aggregation";
    port = mkOption { default = 3100; };
    dataDir = mkOption { default = "/var/lib/loki"; };
  };
  
  grafana = {
    enable = mkEnableOption "Grafana dashboard";
    port = mkOption { default = 3000; };
    adminPassword = mkOption { type = types.str; };
    provisionDashboards = mkOption { default = true; };
  };
  
  prometheus = {
    enable = mkEnableOption "Prometheus metrics";  
    port = mkOption { default = 9090; };
    scrapeConfigs = mkOption { default = []; };
  };
  
  promtail = {
    enable = mkEnableOption "Promtail log collection";
    port = mkOption { default = 9080; };
  };
};
```

**2. Configuration Generation Strategy:**
- Convert existing YAML configs to Nix attribute sets
- Use NixOS native service configuration options where possible
- Generate config files dynamically based on options
- Preserve existing scrape targets and log parsing rules

**3. Service Integration Plan:**
- Replace Docker Compose with native systemd services
- Maintain existing port assignments (3100, 3000, 9090, 9080)
- Configure proper service dependencies (loki before grafana/promtail)
- Set up data directories with correct permissions

**4. Migration Considerations:**
- Preserve existing data directories during transition
- Maintain existing Grafana dashboards and datasources
- Keep prometheus scrape configurations for audio-transcriber
- Ensure log collection continues without interruption

**5. Detailed Configuration Plans:**

**Loki Configuration:**
- Convert `monitorin/loki/loki.yml` to nix configuration
- Use filesystem storage with retention policies
- Configure HTTP and gRPC ports
- Set up proper data directory permissions

**Grafana Configuration:**
- Use services.grafana with declarative provisioning
- Convert existing datasources.yml to nix provisioning config
- Import existing dashboard JSON files
- Configure admin credentials and security

**Prometheus Configuration:**
- Convert prometheus.yml scrape configs to nix
- Maintain existing scrape targets (audio-transcriber, loki, grafana)
- Configure data retention and storage
- Set up proper networking for service discovery

**Promtail Configuration:**
- Convert promtail.yml pipeline configs to nix
- Maintain Docker container log collection
- Configure system log scraping
- Set up proper Loki client configuration

**6. Service Dependencies & Networking:**
- Loki must start before Grafana and Promtail
- Prometheus can start independently
- All services bind to localhost by default
- Firewall rules for configured ports
- Proper systemd service ordering

**7. Data Directory Structure:**
```
/var/lib/
├── loki/
│   ├── chunks/
│   └── rules/
├── grafana/
├── prometheus/
└── promtail/
    └── positions.yaml
```

**8. Firewall & Security:**
- Open ports: 3000 (Grafana), 3100 (Loki), 9090 (Prometheus)
- Promtail port 9080 internal only
- Configure trusted interfaces for container access
- Secure admin credentials for Grafana

## Code

### Phase Entrance Criteria:
- [x] Implementation plan has been created and approved
- [x] NixOS module structure is designed
- [x] Configuration approach is documented
- [x] Dependencies and service interactions are planned

### Tasks
- [ ] Test service startup and basic functionality
- [ ] Update main configuration.nix to enable monitoring

### Completed
- [x] Create `modules/monitoring/default.nix` with module structure
- [x] Implement Loki service configuration and options
- [x] Implement Grafana service with provisioning support
- [x] Implement Prometheus service with scrape configs
- [x] Implement Promtail service with log collection
- [x] Configure service dependencies and systemd ordering
- [x] Set up firewall rules for monitoring ports
- [x] Create Grafana provisioning configuration
- [x] Convert existing dashboard JSON to provisioning
- [x] Integrate with existing services (audio-transcriber, etc.)

## Commit

### Phase Entrance Criteria:
- [ ] Monitoring stack is successfully integrated into NixOS configuration
- [ ] Services are properly configured and working
- [ ] Configuration follows established patterns
- [ ] Testing confirms functionality

### Tasks
- [ ] *To be added when this phase becomes active*

### Completed
*None yet*

## Key Decisions

**1. Native NixOS Services Over Docker Compose**
- Decision: Use native NixOS services (services.loki, services.grafana, etc.) instead of maintaining Docker Compose
- Rationale: Better integration with NixOS ecosystem, proper systemd service management, easier configuration management
- Impact: Requires conversion of existing YAML configs but provides better long-term maintainability

**2. Preserve Existing Configuration Structure**
- Decision: Convert existing configs 1:1 rather than redesigning from scratch
- Rationale: Minimize disruption, maintain existing monitoring functionality
- Impact: Faster implementation, proven configuration patterns

**3. Single Monitoring Module**
- Decision: Create one comprehensive monitoring module instead of separate modules per service
- Rationale: These services work together as a stack, simpler configuration, matches existing Docker Compose pattern
- Impact: Single enable option can configure entire monitoring stack

## Notes

### Exploration Findings

**Current Setup Analysis:**
- Monitoring stack already configured via Docker Compose in `monitorin/` folder
- Components: Loki (log aggregation), Grafana (visualization), Prometheus (metrics), Promtail (log collection)
- Current configuration uses Docker containers with mapped volumes and configs

**NixOS Module Patterns:**
- Modules follow pattern: `config.zugvoegel.services.<servicename>`
- All modules expose enable option and service-specific configuration
- Services are imported via flake.nix automatically from modules/ directory
- Examples: pretix, audiotranscriber, vikunja, schwarmplaner, minio, backup

**NixOS Native Services Available:**
- `services.loki.*` - Full native Loki service support
- `services.grafana.*` - Comprehensive Grafana configuration options  
- `services.prometheus.*` - Native Prometheus with alertmanager
- `services.promtail.*` - Native Promtail log collector

**Integration Requirements:**
- Need to create a `modules/monitoring/default.nix` module following existing patterns
- Should expose configuration for all 4 services under `zugvoegel.services.monitoring`
- Must handle networking, data directories, and configuration files
- Should support provisioning of Grafana datasources and dashboards
- Need to integrate with existing service logs (audio-transcriber, pretix, etc.)

**Detailed Requirements:**

1. **Module Structure:**
   - Create `modules/monitoring/default.nix` with zugvoegel.services.monitoring namespace
   - Enable options for loki, grafana, prometheus, promtail services
   - Configuration options for ports, data directories, and hosts

2. **Service Configuration:**
   - Loki: Port 3100, filesystem storage, /var/lib/loki data directory
   - Grafana: Port 3000, admin credentials, plugin support, provisioning
   - Prometheus: Port 9090, retention config, scrape configs for services
   - Promtail: Integration with Docker and system logs, Loki client config

3. **Data Management:**
   - Proper data directories under /var/lib/ for each service
   - Configuration file generation from existing YAML configs
   - Grafana provisioning for datasources and dashboards

4. **Integration Points:**
   - Prometheus scraping of audio-transcriber metrics endpoint
   - Promtail collection of container and system logs
   - Grafana dashboard provisioning from existing JSON
   - Firewall rules for service ports

5. **Migration Path:**
   - Replace Docker Compose setup with native NixOS services
   - Preserve existing configurations and data
   - Maintain compatibility with current monitoring setup

---
*This plan is maintained by the LLM. Tool responses provide guidance on which section to focus on and what tasks to work on.*
