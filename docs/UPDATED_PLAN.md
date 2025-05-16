# Arboretum Dynamic Agent Architecture - Updated Plan

## 1. Current State

Arboretum has evolved into a dynamic agent architecture focused on both individual agents and large-scale batch operations. The system enables the creation, management, and monitoring of GenServer-based agents that interact with Large Language Models (LLMs), with special emphasis on concurrent batch operations.

### Core Components Implemented

1. **Database Schema and Context**
   - `agents` table with schema for agent configuration
   - `batch_results` table for storing batch operation results
   - Context modules for CRUD operations and PubSub communication

2. **Agent Infrastructure**
   - Dynamic supervision tree with Registry and DynamicSupervisor
   - AgentServerManager for agent lifecycle orchestration
   - AgentServer implementation with ability execution
   - PubSub-based communication for real-time updates

3. **Batch Processing Capabilities**
   - BatchManager for creating and managing batches of agents
   - Rate limiting with provider-specific limits and backoff
   - Batch results storage and retrieval
   - Support for large-scale concurrent LLM operations

4. **LLM Integration**
   - Modular LLMClient with support for multiple providers
   - Implementations for OpenAI and simulated providers
   - Environment-based API key management
   - Error handling and retry logic

5. **Abilities System**
   - Ability behavior definition
   - Echo ability for testing
   - QueryLLM ability for basic LLM interaction
   - BatchQuery ability for parallel LLM querying

6. **Web Interface**
   - LiveView UI for individual agent management
   - LiveView UI for batch operations and result viewing
   - Form components for creating and editing agents
   - Navigation and integration with Phoenix

## 2. Gaps and Opportunities

### Features to Complete

1. **Monitoring Dashboard**
   - System-wide metrics visualization
   - Agent status overview
   - Batch operation progress tracking
   - Resource utilization metrics

2. **API Key Management**
   - User interface for managing API keys
   - Secure storage of credentials
   - Key rotation and validation capabilities
   - Multi-provider credential management

3. **Streaming Support**
   - Streaming LLM responses from providers
   - Server-Sent Events (SSE) for real-time updates
   - Client-side streaming visualization
   - Efficient token processing for streaming

4. **Testing Infrastructure**
   - Comprehensive unit tests for core components
   - Integration tests for agent lifecycle
   - LiveView component tests
   - Batch processing tests with simulated LLMs

### Technical Improvements

1. **Observability Enhancements**
   - Telemetry integration for metrics collection
   - LiveDashboard customizations
   - Structured logging improvements
   - Performance monitoring

2. **Resilience Features**
   - Flap detection for agent crashes
   - Circuit breakers for external services
   - Better error recovery strategies
   - Graceful degradation under load

3. **Documentation**
   - README updates with installation and usage
   - Architecture documentation
   - API documentation for all modules
   - Example workflows and use cases

## 3. Revised Roadmap

### Phase 1: Monitoring and Observability (Current Priority)
- Create system-wide monitoring dashboard
- Implement batch operation status visualizations
- Add Telemetry metrics for key components
- Enhance logging for better troubleshooting

### Phase 2: Streaming and Real-time Updates
- Implement streaming support in LLMClient
- Add SSE endpoints for real-time updates
- Create streaming UI components
- Optimize for efficient token handling

### Phase 3: API Key Management and Security
- Develop settings page for API key management
- Implement secure storage for credentials
- Add key rotation and validation features
- Support multiple providers and environments

### Phase 4: Testing and Quality Assurance
- Write unit tests for Agent context
- Create integration tests for batch processing
- Add LiveView component tests
- Establish CI pipeline for testing

### Phase 5: Documentation and Refinement
- Update README with comprehensive instructions
- Create detailed architecture documentation
- Document all public APIs and interfaces
- Provide example workflows and configurations

### Phase 6: Advanced Features (Future Possibilities)
- Implement agent-to-agent communication
- Add support for more LLM providers
- Create chain-of-thought and reasoning capabilities
- Develop fine-tuning and model management features

## 4. Implementation Details

### Monitoring Dashboard
- Create `lib/arboretum_web/live/dashboard/index.ex`
- Implement real-time metrics collection using PubSub
- Display agent counts, statuses, and batch operations
- Show system resource utilization

### Streaming Support
- Update `lib/arboretum/llm_client.ex` with streaming mode
- Create new `stream_query` function for LLM streaming
- Implement SSE controller at `lib/arboretum_web/controllers/sse_controller.ex`
- Add streaming UI components in LiveView

### API Key Management
- Create `lib/arboretum/credentials` context
- Implement `lib/arboretum_web/live/settings/index.ex`
- Add secure storage mechanism for API keys
- Create UI for managing provider credentials

### Testing Strategy
- Unit tests for all context modules
- Integration tests for agent lifecycle
- LiveView tests for UI interactions
- Property-based tests for complex logic
- Mocks for external services

## 5. Success Metrics
- All agents can be created, managed, and monitored effectively
- Batch operations can scale to 100+ agents with proper rate limiting
- LLM interactions maintain high throughput with controlled resource usage
- Users can easily configure and monitor the system
- Documentation enables new developers to understand and extend the system

This updated plan aligns with the current state of the project and provides a clear path forward while acknowledging the shift in priorities toward batch processing and large-scale LLM operations.