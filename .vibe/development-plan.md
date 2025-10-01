# Development Plan: ticketing (main branch)

*Generated on 2025-10-01 by Vibe Feature MCP*
*Workflow: [minor](https://mrsimpson.github.io/responsible-vibe-mcp/workflows/minor)*

## Goal
Check all modules for port configuration and expose them as configurable options in the main configuration to provide centralized port management.

## Explore
### Tasks
- [x] Design port configuration approach
- [x] Plan implementation strategy

### Completed
- [x] Created development plan file
- [x] Analyze all modules for port configurations
- [x] Identify which ports should be configurable

### Analysis Findings

**Current Port Configuration Status:**

1. **MinIO Module** ✅ Already has port options
   - `port = 9000` (API)
   - `consolePort = 9001` (Console)
   - **Status**: Well implemented

2. **Monitoring Module** ❌ Hardcoded ports  
   - Grafana: `3000`
   - Loki: `3100` 
   - Prometheus: `9090`
   - Promtail: `9080`
   - **Status**: Needs port options

3. **Pretix Module** ❌ Hardcoded port
   - Docker container: `"12345:80"`
   - **Status**: Needs port option

4. **Schwarmplaner Module** ❌ Hardcoded ports
   - Nginx: `"90:80"`
   - MySQL: `"3306:3306"`
   - API: `"3000:3000"`
   - Frontend: `"8000:8000"`
   - **Status**: Needs multiple port options

5. **Audio Transcriber Module** ❌ Hardcoded port
   - App: `"8001:3000"`
   - **Status**: Needs port option

6. **Vikunja Module** ❌ Hardcoded port
   - SMTP: `port = 587`
   - **Status**: Needs port option

7. **Bank Automation Module** ✅ No exposed ports
   - **Status**: No changes needed

8. **Backup Module** ✅ No exposed ports
   - **Status**: No changes needed

**Summary:**
- **5 modules** need port configuration options added
- **2 modules** already handle ports correctly  
- **2 modules** don't expose ports

### Port Configuration Design

**Approach**: Add `port` (and additional port options where needed) to each module following the MinIO pattern.

**Design Pattern:**
```nix
# For single port services
port = mkOption {
  type = types.port;
  default = [service-default];
  description = "Port for [service-name]";
};

# For multi-port services  
someServicePort = mkOption {
  type = types.port;
  default = [default];
  description = "Port for [specific-service]";
};
```

**Implementation Plan:**

1. **Monitoring Module**: Add 4 port options
   - `grafanaPort = 3000`
   - `lokiPort = 3100` 
   - `prometheusPort = 9090`
   - `promtailPort = 9080`

2. **Pretix Module**: Add 1 port option
   - `port = 12345`

3. **Schwarmplaner Module**: Add 4 port options
   - `nginxPort = 90`
   - `mysqlPort = 3306`
   - `apiPort = 3000`
   - `frontendPort = 8000`

4. **Audio Transcriber Module**: Add 1 port option
   - `port = 8001`

5. **Vikunja Module**: Add 1 port option
   - `smtpPort = 587`

**Benefits:**
- Centralized port management in configuration.nix
- Avoid port conflicts between services
- Enable custom port assignments for different environments
- Maintain backward compatibility with sensible defaults

### Analysis Findings

**Current Complexity Issues:**
- **Module Size**: 440 lines of complex configuration
- **Over-engineered Options**: Too many granular configuration options (individual ports, data dirs, etc.)
- **Complex Promtail Pipeline**: 3 different scrape configs with detailed JSON parsing pipelines
- **Verbose Grafana Provisioning**: Detailed datasource and dashboard configuration  
- **Detailed Service Configuration**: Full replication of YAML configs in Nix

**Simplification Opportunities:**
1. **Reduce Configuration Options**: Most users want basic monitoring, not fine-tuned control
2. **Simplify Promtail**: Use basic log collection instead of complex JSON parsing
3. **Use Default Configurations**: Leverage NixOS service defaults instead of explicit config
4. **Minimal Grafana Setup**: Basic datasources without complex provisioning
5. **Single Enable Option**: Enable entire stack with minimal configuration

**Proposed Simplified Approach:**
- Single `enable` option to turn on all monitoring services
- Remove individual service enable/disable options
- Use NixOS service defaults for most configuration
- Simplified Promtail with basic log collection
- Basic Grafana with essential datasources only
- Target: Reduce from 440 lines to ~100-150 lines

## Key Decisions

**1. Single Enable Option**
- Decision: Replace granular service options with single `enable` toggle
- Rationale: Most users want basic monitoring, not fine-grained control
- Impact: Much simpler configuration, reduced cognitive load

**2. Remove Complex JSON Parsing**
- Decision: Replace complex Promtail pipelines with basic journal collection
- Rationale: Over-engineered for typical monitoring needs
- Impact: Reduced 200+ lines of pipeline configuration to simple journal scraping

**3. Use NixOS Service Defaults**
- Decision: Leverage built-in NixOS service defaults instead of explicit configuration
- Rationale: Reduces maintenance burden and configuration complexity
- Impact: Eliminates need for custom port/directory options

## Final Results

**Complexity Reduction Achieved:**
- **Lines of Code**: 440 → 131 lines (70% reduction)
- **Configuration Options**: Reduced from 12 options to 2 options
- **Service Dependencies**: Simplified systemd ordering
- **Firewall Configuration**: Reduced to simple port list
- **Promtail Configuration**: Eliminated complex JSON parsing pipelines

**Maintained Functionality:**
- All 4 monitoring services (Loki, Grafana, Prometheus, Promtail) still enabled
- Basic log collection via systemd journal
- Grafana datasource auto-provisioning
- Service dependency management
- Firewall port management

The monitoring stack is now much simpler to configure and maintain while preserving essential monitoring capabilities.

### Simplified Design

**New Module Structure:**
```nix
options.zugvoegel.services.monitoring = {
  enable = mkEnableOption "monitoring stack";
  openFirewall = mkOption { 
    type = types.bool; 
    default = true; 
    description = "Open firewall for monitoring services";
  };
};
```

**Services Configuration:**
- **Loki**: Use NixOS defaults, minimal filesystem config
- **Grafana**: Basic setup with admin/admin credentials, auto-provision Loki datasource
- **Prometheus**: Default config + basic scraping of local services  
- **Promtail**: Simple syslog and Docker log collection, no complex JSON parsing

**What Gets Removed:**
- Individual service enable/disable options
- Port configuration options (use defaults: 3000, 3100, 9090)
- Data directory options (use NixOS defaults)
- Complex Promtail pipeline stages
- Detailed Grafana provisioning configuration
- Dashboard file copying complexity

## Implement

### Phase Entrance Criteria:
- [x] All modules have been analyzed for port usage
- [x] Port configuration approach has been designed
- [x] Implementation strategy is clear
- [x] Scope and impact are understood

### Tasks
- [ ] Add port options to monitoring module
- [ ] Add port option to pretix module  
- [ ] Add port options to schwarmplaner module
- [ ] Add port option to audiotranscriber module
- [ ] Add port option to vikunja module
- [ ] Update configuration references to use new port variables
- [ ] Test all modules for syntax correctness
- [ ] Update documentation with port configuration examples

### Completed
*None yet*

## Finalize

### Phase Entrance Criteria:
- [ ] Port configuration options have been implemented
- [ ] All modules support configurable ports
- [ ] Configuration validation passes
- [ ] Documentation is updated

### Tasks

### Completed
- [x] Review code for debug statements or TODO comments
- [x] Final validation of simplified configuration
- [x] Remove unused dashboard files if any
- [x] Clean up development artifacts
- [x] Final documentation review
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
- [x] Test service startup and basic functionality
- [x] Update main configuration.nix to enable monitoring

## Commit

### Phase Entrance Criteria:
- [x] Monitoring stack is successfully integrated into NixOS configuration
- [x] Services are properly configured and working
- [x] Configuration follows established patterns
- [x] Testing confirms functionality

### Tasks

### Completed
- [x] Review and clean up monitoring module code
- [x] Check for TODO/FIXME comments and address them  
- [x] Remove any debugging or temporary code
- [x] Final validation of configuration syntax
- [x] Update README or documentation if needed
- [x] Prepare final commit message

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

## Implementation Summary

The monitoring stack has been successfully integrated into the NixOS configuration:

**Created Files:**
- `modules/monitoring/default.nix` - Main monitoring module with all 4 services
- `modules/monitoring/dashboards/audio-transcriber-dashboard.json` - Existing dashboard
- Updated `configuration.nix` to enable monitoring services
- Updated `README.md` with monitoring information

**Services Configured:**
- **Loki** (port 3100): Log aggregation with filesystem storage
- **Grafana** (port 3000): Dashboards with automatic provisioning 
- **Prometheus** (port 9090): Metrics collection with service scraping
- **Promtail** (port 9080): Log collection from Docker and system

**Key Features:**
- Native NixOS services replace Docker Compose
- Automatic dashboard and datasource provisioning
- Service dependency management with systemd
- Firewall configuration for external access
- Integration with existing services (audio-transcriber metrics)
- Data directory management with proper permissions

The monitoring stack is ready for deployment and will provide comprehensive observability for all services in the environment.

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
